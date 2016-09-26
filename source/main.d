module app;

import dlangui;

mixin APP_ENTRY_POINT;


import derelict.wintab.wintab;
import core.sys.windows.windows;

class Tablet {
    HCTX _hCtx;
    bool init(HWND hWnd) {
        uint res;

        if (!WTInfo(0, 0, null)) {
            Log.e("WinTab services not available");
            //return 1;
            return false;
        }

        ushort thisVersion;
        res = WTInfo(WTI_INTERFACE, IFC_SPECVERSION, &thisVersion);

        LOGCONTEXT	glogContext;
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

        immutable uint PACKETDATA = (PK_X | PK_Y | PK_BUTTONS | PK_NORMAL_PRESSURE);
        immutable uint PACKETMODE = PK_BUTTONS | PK_X | PK_Y | PK_Z;

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

        glogContext.lcInOrgX = 0;
        glogContext.lcInOrgY = 0;
        glogContext.lcInExtX = TabletX.axMax;
        glogContext.lcInExtY = TabletY.axMax;

        // Guarantee the output coordinate space to be in screen coordinates.  
        glogContext.lcOutOrgX = GetSystemMetrics( SM_XVIRTUALSCREEN );
        glogContext.lcOutOrgY = GetSystemMetrics( SM_YVIRTUALSCREEN );
        glogContext.lcOutExtX = GetSystemMetrics( SM_CXVIRTUALSCREEN ); //SM_CXSCREEN );

        // In Wintab, the tablet origin is lower left.  Move origin to upper left
        // so that it coincides with screen origin.
        glogContext.lcOutExtY = -GetSystemMetrics( SM_CYVIRTUALSCREEN );	//SM_CYSCREEN );

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
    bool onUnknownWindowMessage(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam, ref LRESULT result) {
        import std.string : format;
        PACKET pkt;
        switch(message) {
            case WM_CREATE:
                Log.d("WM_CREATE");
                if (!init(hwnd)) {
                    Log.e("Tablet init failed");
                }
                break;
            case WM_DESTROY:
                Log.d("WM_DESTROY");
                uninit();
                break;
            case WM_ACTIVATE:
                Log.d("WM_ACTIVATE");
                if (wParam)
                {
                    //InvalidateRect(hwnd, NULL, TRUE);
                }

                /* if switching in the middle, disable the region */
                if (_hCtx) 
                {
                    WTEnable(_hCtx, wParam ? TRUE : FALSE);
                    if (_hCtx && wParam)
                    {
                        WTOverlap(_hCtx, TRUE);
                    }
                }
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
                Log.d("WT_PROXIMITY");
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
                Log.d("WT_PACKET");
                if (WTPacket(cast(HCTX)lParam, wParam, &pkt)) 
                {
                    if (HIWORD(pkt.pkButtons)==TBN_DOWN) 
                    {
                        //MessageBeep(0);
                    }
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
                Log.d("UNKNOWN: ", "%x".format(message));
                break;
        }
        return false; // to call DefWindowProc
    }
}

/// entry point for dlangui based application
extern (C) int UIAppMain(string[] args) {

    DerelictWintab.load();


    // create window
    Log.d("Creating window");
    import dlangui.platforms.windows.winapp;
    Win32Window window = cast(Win32Window)Platform.instance.createWindow("DlangUI example - HelloWorld", null);

    Tablet tablet = new Tablet();
    window.onUnknownWindowMessage = &tablet.onUnknownWindowMessage;
    tablet.init(window.windowHandle);
    Log.d("Window created");

    // create some widget to show in window
    //window.mainWidget = (new Button()).text("Hello, world!"d).margins(Rect(20,20,20,20));
    window.mainWidget = parseML(q{
        VerticalLayout {
        margins: 10pt
                padding: 10pt
                layoutWidth: fill
                // red bold text with size = 150% of base style size and font face Arial
                TextWidget { text: "Hello World example for DlangUI"; textColor: "red"; fontSize: 150%; fontWeight: 800; fontFace: "Arial" }
            // arrange controls as form - table with two columns
            TableLayout {
            colCount: 2
                    layoutWidth: fill
                    TextWidget { text: "param 1" }
                EditLine { id: edit1; text: "some text"; layoutWidth: fill }
                TextWidget { text: "param 2" }
                EditLine { id: edit2; text: "some text for param2"; layoutWidth: fill }
                TextWidget { text: "some radio buttons" }
                // arrange some radio buttons vertically
                VerticalLayout {
                layoutWidth: fill
                        RadioButton { id: rb1; text: "Item 1" }
                    RadioButton { id: rb2; text: "Item 2" }
                    RadioButton { id: rb3; text: "Item 3" }
                }
                TextWidget { text: "and checkboxes" }
                // arrange some checkboxes horizontally
                HorizontalLayout {
                layoutWidth: fill
                        CheckBox { id: cb1; text: "checkbox 1" }
                    CheckBox { id: cb2; text: "checkbox 2" }
                    ComboEdit { id: ce1; text: "some text"; minWidth: 20pt; items: ["Item 1", "Item 2", "Additional item"] }
                }
            }
            EditBox { layoutWidth: 20pt; layoutHeight: 10pt }
            HorizontalLayout {
                Button { id: btnOk; text: "Ok" }
                Button { id: btnCancel; text: "Cancel" }
            }
        }
    });
    // you can access loaded items by id - e.g. to assign signal listeners
    auto edit1 = window.mainWidget.childById!EditLine("edit1");
    auto edit2 = window.mainWidget.childById!EditLine("edit2");
    // close window on Cancel button click
    window.mainWidget.childById!Button("btnCancel").click = delegate(Widget w) {
        window.close();
        return true;
    };
    // show message box with content of editors
    window.mainWidget.childById!Button("btnOk").click = delegate(Widget w) {
        window.showMessageBox(UIString("Ok button pressed"d), 
                              UIString("Editors content\nEdit1: "d ~ edit1.text ~ "\nEdit2: "d ~ edit2.text));
        return true;
    };

    // show window
    window.show();

    // run message loop
    return Platform.instance.enterMessageLoop();
}
