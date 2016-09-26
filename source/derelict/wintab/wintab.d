module derelict.wintab.wintab;

private {
    import derelict.util.loader;
    import derelict.util.system;
    import derelict.util.exception;

    static if(Derelict_OS_Windows)
        enum libNames = "wintab32.dll";
//    else static if(Derelict_OS_Mac)
//        enum libNames = "libpq.dylib";
//    else static if(Derelict_OS_Posix)
//        enum libNames = "libpq.so";
    else
        static assert(0, "Wintab is supported only on Windows platform.");
}

alias FIX32 = uint;
alias WTPKT = uint;

struct AXIS {
    int axMin;
    int axMax;
    uint    axUnits;
    FIX32   axResolution;
}

enum WTI_INTERFACE		= 1;

enum {
    IFC_WINTABID			=1,
    IFC_SPECVERSION		=2,
    IFC_IMPLVERSION		=3,
    IFC_NDEVICES			=4,
    IFC_NCURSORS			=5,
    IFC_NCONTEXTS		=6,
    IFC_CTXOPTIONS		=7,
    IFC_CTXSAVESIZE		=8,
    IFC_NEXTENSIONS		=9,
    IFC_NMANAGERS		=10,
    IFC_MAX				=10,
}

enum WTI_DEVICES = 100;
enum {
    DVC_NAME = 1,
    DVC_HARDWARE = 2,
    DVC_NCSRTYPES = 3,
    DVC_FIRSTCSR = 4,
    DVC_PKTRATE = 5,
    DVC_PKTDATA = 6,
    DVC_PKTMODE = 7,
    DVC_CSRDATA = 8,
    DVC_XMARGIN = 9,
    DVC_YMARGIN = 10,
    DVC_ZMARGIN = 11,
    DVC_X = 12,
    DVC_Y = 13,
    DVC_Z = 14,
    DVC_NPRESSURE = 15,
    DVC_TPRESSURE = 16,
    DVC_ORIENTATION = 17,
    DVC_ROTATION = 18, /* 1.1 */
    DVC_PNPID = 19, /* 1.1 */
    DVC_MAX = 19,
}

enum WTI_DEFCONTEXT	= 3;
enum WTI_DEFSYSCTX	= 4;
enum WTI_DDCTXS		=400; /* 1.1 */
enum WTI_DSCTXS		=500; /* 1.1 */
enum {
    CTX_NAME			=1,
    CTX_OPTIONS		=2,
    CTX_STATUS		=3,
    CTX_LOCKS			=4,
    CTX_MSGBASE		=5,
    CTX_DEVICE		=6,
    CTX_PKTRATE		=7,
    CTX_PKTDATA		=8,
    CTX_PKTMODE		=9,
    CTX_MOVEMASK		=10,
    CTX_BTNDNMASK	=11,
    CTX_BTNUPMASK	=12,
    CTX_INORGX		=13,
    CTX_INORGY		=14,
    CTX_INORGZ		=15,
    CTX_INEXTX		=16,
    CTX_INEXTY		=17,
    CTX_INEXTZ		=18,
    CTX_OUTORGX		=19,
    CTX_OUTORGY		=20,
    CTX_OUTORGZ		=21,
    CTX_OUTEXTX		=22,
    CTX_OUTEXTY		=23,
    CTX_OUTEXTZ		=24,
    CTX_SENSX			=25,
    CTX_SENSY			=26,
    CTX_SENSZ			=27,
    CTX_SYSMODE		=28,
    CTX_SYSORGX		=29,
    CTX_SYSORGY		=30,
    CTX_SYSEXTX		=31,
    CTX_SYSEXTY		=32,
    CTX_SYSSENSX		=33,
    CTX_SYSSENSY		=34,
    CTX_MAX			=34,
}

enum LCNAMELEN = 40;
struct LOGCONTEXT {
	wchar[LCNAMELEN] lcName;
	uint	lcOptions;
	uint	lcStatus;
	uint	lcLocks;
	uint	lcMsgBase;
	uint	lcDevice;
	uint	lcPktRate;
	WTPKT	lcPktData;
	WTPKT	lcPktMode;
	WTPKT	lcMoveMask;
	uint	lcBtnDnMask;
	uint	lcBtnUpMask;
	int	lcInOrgX;
	int	lcInOrgY;
	int	lcInOrgZ;
	int	lcInExtX;
	int	lcInExtY;
	int	lcInExtZ;
	int	lcOutOrgX;
	int	lcOutOrgY;
	int	lcOutOrgZ;
	int	lcOutExtX;
	int	lcOutExtY;
	int	lcOutExtZ;
	FIX32	lcSensX;
	FIX32	lcSensY;
	FIX32	lcSensZ;
	int	lcSysMode; // BOOL
	int	lcSysOrgX;
	int	lcSysOrgY;
	int	lcSysExtX;
	int	lcSysExtY;
	FIX32	lcSysSensX;
	FIX32	lcSysSensY;
}

extern(Windows) @nogc nothrow {
    //UINT API WTInfoW(UINT, UINT, LPVOID)
    alias da_WTInfo = uint function(uint, uint, void*);
}

__gshared {
    da_WTInfo WTInfo;
}

class DerelictWintabLoader : SharedLibLoader {
    public this() {
        super(libNames);
    }

    protected override void loadSymbols()
    {
        bindFunc(cast(void**)&WTInfo, "WTInfoA");
    }
}


__gshared DerelictWintabLoader DerelictWintab;

shared static this() {
    DerelictWintab = new DerelictWintabLoader();
}
