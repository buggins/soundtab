module app;

import dlangui;

mixin APP_ENTRY_POINT;


import core.sys.windows.windows;

import soundtab.ui.frame;

/// entry point for dlangui based application
extern (C) int UIAppMain(string[] args) {

    auto hr = CoInitialize(null);
    if (hr)
        Log.e("CoInitialize failed");

    //initAudio();

    // create window
    Log.d("Creating window");
    import dlangui.platforms.windows.winapp;
    Win32Window window = cast(Win32Window)Platform.instance.createWindow("SoundTab - Wacom Tablet Theremin", null, WindowFlag.Resizable, 1000, 600);
    Log.d("Window created");


    // create some widget to show in window
    //window.mainWidget = (new Button()).text("Hello, world!"d).margins(Rect(20,20,20,20));
    new SoundFrame(window);


    // show window
    window.show();

    // run message loop
    return Platform.instance.enterMessageLoop();
}
