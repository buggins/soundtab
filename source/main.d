module app;

import dlangui;

mixin APP_ENTRY_POINT;


import core.sys.windows.windows;

import soundtab.ui.frame;

//version = DumpPulse;

version(DumpPulse)
void convertRaw(string filename) {
    import std.file;
    import std.conv : to;
    short[] data = cast(short[])read(filename);
    char[] buf;
    char[] buf2;
    buf ~= "    ";
    for (int i = 0; i < data.length; i++) {
        buf ~= to!string((cast(int)data[i]));
        buf2 ~= to!string((cast(int)data[i]));
        buf ~= ", ";
        if (i % 16 == 15)
            buf ~= "\n    ";
        buf2 ~= "\n";
    }
    buf ~= "\n";
    write(filename ~ ".d", buf);
    write(filename ~ ".csv", buf2);
}

/// entry point for dlangui based application
extern (C) int UIAppMain(string[] args) {

    auto hr = CoInitialize(null);
    if (hr)
        Log.e("CoInitialize failed");

    //initAudio();
    version(DumpPulse) {
        convertRaw("impuls20.raw");
    }

    Platform.instance.uiTheme = "theme_dark";
    // create window
    Log.d("Creating window");
    import dlangui.platforms.windows.winapp;
    Win32Window window = cast(Win32Window)Platform.instance.createWindow("SoundTab - Wacom Tablet Theremin", null, WindowFlag.Resizable, 800, 600);
    Log.d("Window created");


    // create some widget to show in window
    //window.mainWidget = (new Button()).text("Hello, world!"d).margins(Rect(20,20,20,20));
    new SoundFrame(window);


    // show window
    window.show();

    // run message loop
    return Platform.instance.enterMessageLoop();
}
