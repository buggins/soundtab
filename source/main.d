module app;

import dlangui;

mixin APP_ENTRY_POINT;


import derelict.wintab.wintab;
import derelict.wintab.tablet;
import core.sys.windows.windows;
import soundtab.ui.sndcanvas;
import soundtab.ui.synthwidget;

import wasapi.coreaudio;
import soundtab.audio.playback;

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
    Win32Window window = cast(Win32Window)Platform.instance.createWindow("DlangUI example - HelloWorld", null, WindowFlag.Resizable, 1000, 700);

    Tablet tablet = new Tablet();
    window.onUnknownWindowMessage = &tablet.onUnknownWindowMessage;
    tablet.init(window.windowHandle);
    Log.d("Window created");

    // create some widget to show in window
    //window.mainWidget = (new Button()).text("Hello, world!"d).margins(Rect(20,20,20,20));
    window.mainWidget = new SoundFrame(tablet);


    // show window
    window.show();

    // run message loop
    return Platform.instance.enterMessageLoop();
}
