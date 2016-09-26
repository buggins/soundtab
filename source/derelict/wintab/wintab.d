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

extern(C) @nogc nothrow {
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
        bindFunc(cast(void**)&WTInfo, "WTInfoW");
    }
}


__gshared DerelictWintabLoader DerelictWintab;

shared static this() {
    DerelictWintab = new DerelictWintabLoader();
}
