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
struct AXIS {
    int axMin;
    int axMax;
    uint    axUnits;
    FIX32   axResolution;
}

enum WTI_DEVICES = 100;
enum DVC_NAME = 1;
enum DVC_HARDWARE = 2;
enum DVC_NCSRTYPES = 3;
enum DVC_FIRSTCSR = 4;
enum DVC_PKTRATE = 5;
enum DVC_PKTDATA = 6;
enum DVC_PKTMODE = 7;
enum DVC_CSRDATA = 8;
enum DVC_XMARGIN = 9;
enum DVC_YMARGIN = 10;
enum DVC_ZMARGIN = 11;
enum DVC_X = 12;
enum DVC_Y = 13;
enum DVC_Z = 14;
enum DVC_NPRESSURE = 15;
enum DVC_TPRESSURE = 16;
enum DVC_ORIENTATION = 17;
enum DVC_ROTATION = 18; /* 1.1 */
enum DVC_PNPID = 19; /* 1.1 */
enum DVC_MAX = 19;


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
