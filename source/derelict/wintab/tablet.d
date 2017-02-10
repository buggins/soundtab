module derelict.wintab.tablet;

import core.sys.windows.windows;
import derelict.wintab.wintab;
import dlangui.core.logger;
import dlangui.core.signals;

interface TabletPositionHandler {
    void onPositionChange(double x, double y, double pressure, uint buttons);
}

interface TabletProximityHandler {
    void onProximity(bool enter);
}

class Tablet {
    Signal!TabletPositionHandler onPosition;
    Signal!TabletProximityHandler onProximity;

    private HCTX _hCtx;
    private LOGCONTEXT glogContext;
    private HWND _hWnd;
    /// returns true if initialized
    @property bool isInitialized() {
        if (_hCtx is null)
            return false;
        uint numDevices;
        if (!WTInfo(WTI_INTERFACE, IFC_NDEVICES, cast(void*)&numDevices))
            return false;
        if (!numDevices)
            return false;
        return _proximity;
    }
    /// initialize tablet API for window
    bool init(HWND hWnd) {

        try {
            DerelictWintab.load();
        } catch (Exception e) {
            Log.e("Cannot load wintab32.dll");
            return false;
        }

        uint res;

        _hWnd = hWnd;

        try {
            if (!WTInfo(0, 0, null)) {
                Log.e("WinTab services not available");
                //return 1;
                return false;
            }
        } catch (Exception e) {
            Log.e("Exception in WTInfo", e);
            return false;
        }

        ushort thisVersion;
        res = WTInfo(WTI_INTERFACE, IFC_SPECVERSION, &thisVersion);

        glogContext.lcOptions |= CXO_SYSTEM;
        uint wWTInfoRetVal = WTInfo(WTI_DEFSYSCTX, 0, &glogContext);
        assert(glogContext.lcOptions & CXO_SYSTEM);
        assert(wWTInfoRetVal == glogContext.sizeof);

        wchar[50] wname;
        if (!WTInfo(WTI_DEVICES, DVC_NAME, cast(void*)wname.ptr)) {
            Log.e("WinTab cannot get device name");
            return false;
        }
        if (wname[0 .. 5] != "WACOM") {
            Log.e("Not a wacom device");
            return false;
        }

        AXIS[3] tpOri;
        uint tilt_support = WTInfo(WTI_DEVICES, DVC_ORIENTATION, cast(void*)&tpOri);
        // load theme from file "theme_default.xml"
        //Platform.instance.uiTheme = "theme_default";

        immutable uint PACKETDATA = PK_ALL; // (PK_X | PK_Y | PK_BUTTONS | PK_NORMAL_PRESSURE);
        immutable uint PACKETMODE = 0; //PK_BUTTONS; // | PK_X | PK_Y | PK_Z;

        // What data items we want to be included in the tablet packets
        glogContext.lcPktData = PACKETDATA;

        // Which packet items should show change in value since the last
        // packet (referred to as 'relative' data) and which items
        // should be 'absolute'.
        glogContext.lcPktMode = PACKETMODE;

        // This bitfield determines whether or not this context will receive
        // a packet when a value for each packet field changes.  This is not
        // supported by the Intuos Wintab.  Your context will always receive
        // packets, even if there has been no change in the data.
        glogContext.lcMoveMask = PACKETDATA;

        glogContext.lcOptions = CXO_MESSAGES; // | CXO_PEN;

        // Which buttons events will be handled by this context.  lcBtnMask
        // is a bitfield with one bit per button.
        glogContext.lcBtnUpMask = glogContext.lcBtnDnMask;

        AXIS TabletX;
        AXIS TabletY;
        // Set the entire tablet as active
        wWTInfoRetVal = WTInfo( WTI_DEVICES + 0, DVC_X, &TabletX );
        assert(wWTInfoRetVal == AXIS.sizeof);
        wWTInfoRetVal = WTInfo( WTI_DEVICES, DVC_Y, &TabletY );
        assert(wWTInfoRetVal == AXIS.sizeof);

        glogContext.lcInOrgX = 0;
        glogContext.lcInOrgY = 0;
        glogContext.lcInExtX = TabletX.axMax;
        glogContext.lcInExtY = TabletY.axMax;

        // Guarantee the output coordinate space to be in screen coordinates.  
        glogContext.lcOutOrgX = 0; //GetSystemMetrics( SM_XVIRTUALSCREEN );
        glogContext.lcOutOrgY = 0; //GetSystemMetrics( SM_YVIRTUALSCREEN );
        glogContext.lcOutExtX = 100000; //GetSystemMetrics( SM_CXVIRTUALSCREEN ); //SM_CXSCREEN );

        // In Wintab, the tablet origin is lower left.  Move origin to upper left
        // so that it coincides with screen origin.
        glogContext.lcOutExtY = -100000; //-GetSystemMetrics( SM_CYVIRTUALSCREEN );	//SM_CYSCREEN );

        // Leave the system origin and extents as received:
        // lcSysOrgX, lcSysOrgY, lcSysExtX, lcSysExtY

        // open the region
        // The Wintab spec says we must open the context disabled if we are 
        // using cursor masks.  
        _hCtx = WTOpen(hWnd, &glogContext, FALSE );
        return _hCtx !is null;
    }
    void uninit() {
        if (_hCtx) {
            WTClose(_hCtx);
            _hCtx = null;
        }
    }

    void onActivate(bool activated) {
        if (_hCtx) 
        {
            WTEnable(_hCtx, activated ? TRUE : FALSE);
            if (_hCtx && activated)
            {
                WTOverlap(_hCtx, TRUE);
            }
        }
    }

    bool _proximity;
    void handleProximity(bool enter) {
        _proximity = enter;
        if (onProximity.assigned)
            onProximity(enter);
    }

    private double _lastx = -1;
    private double _lasty = -1;
    private double _lastpressure = -1;
    private uint _lastbuttons = 0;
    void onPacket(int x, int y, int press, uint buttons) {
        double xx = x / 100000.0;
        double yy = y / 100000.0;
        double pressure = press / 1000.0;
        if (xx != _lastx || yy != _lasty || pressure != _lastpressure || buttons != _lastbuttons) {
            if (onPosition.assigned)
                onPosition(xx, yy, pressure, buttons);
            _lastx = xx;
            _lasty = yy;
            _lastpressure = pressure;
            _lastbuttons = buttons;
        }
    }

    bool onUnknownWindowMessage(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam, ref LRESULT result) {
        import std.string : format;
        PACKET!PK_ALL pkt;
        switch(message) {
            case WM_ACTIVATE:
                Log.d("WM_ACTIVATE ", wParam);
                onActivate(wParam != 0);
                break;
            case WT_CTXOPEN:
                Log.d("WT_CTXOPEN");
                break;
            case WT_CTXCLOSE:
                Log.d("WT_CTXCLOSE");
                break;
            case WT_CTXUPDATE:
                Log.d("WT_CTXUPDATE");
                break;
            case WT_CTXOVERLAP:
                Log.d("WT_CTXOVERLAP");
                break;
            case WT_PROXIMITY:
                Log.d("WT_PROXIMITY ", lParam);
                handleProximity((lParam & 0xFFFF) != 0);
                break;
            case WT_INFOCHANGE:
                Log.d("WT_INFOCHANGE");
                break;
            case WT_CSRCHANGE:
                Log.d("WT_CSRCHANGE");
                break;
            case WT_PACKETEXT:
                Log.d("WT_PACKETEXT");
                break;
            case WT_PACKET:
                //Log.d("WT_PACKET");
                if (WTPacket(cast(HCTX)lParam, cast(uint)wParam, cast(void*)&pkt)) 
                {
                    if (HIWORD(pkt.pkButtons)==TBN_DOWN) 
                    {
                        //MessageBeep(0);
                    }
                    //Log.d("WT_PACKET x=", pkt.pkX, " y=", pkt.pkY, " z=", pkt.pkZ, " np=", pkt.pkNormalPressure, " tp=", pkt.pkTangentPressure, " buttons=", "%08x".format(pkt.pkButtons));
                    onPacket(pkt.pkX, pkt.pkY, pkt.pkNormalPressure, pkt.pkButtons);
                    //ptOld = ptNew;
                    //prsOld = prsNew;
                    //
                    //ptNew.x = pkt.pkX;
                    //ptNew.y = pkt.pkY;
                    //
                    //prsNew = pkt.pkNormalPressure;
                    //
                    //if (ptNew.x != ptOld.x ||
                    //    ptNew.y != ptOld.y ||
                    //    prsNew != prsOld) 
                    //{
                    //    InvalidateRect(hWnd, NULL, TRUE);
                    //}
                }
                break;
            default:
                //Log.d("UNKNOWN: ", "%x".format(message));
                break;
        }
        return false; // to call DefWindowProc
    }
}

