module app;

import dlangui;

mixin APP_ENTRY_POINT;


import derelict.wintab.wintab;
import derelict.wintab.tablet;
import core.sys.windows.windows;
import soundtab.ui.sndcanvas;

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
            id: main
            layoutWidth: fill
            layoutHeight: fill
            VerticalLayout {
                layoutWidth: fill
                layoutHeight: wrap
                HorizontalLayout {
                    layoutWidth: fill
                    layoutHeight: wrap
                    RadioButton { id: rb2; text: "Item 2" }
                    RadioButton { id: rb3; text: "Item 3" }
                }
            }
            TextWidget { text: "Test" }
        }
    });

    VerticalLayout mainLayout = window.mainWidget.childById!VerticalLayout("main");
    mainLayout.addChild(new SoundCanvas());


    // show window
    window.show();

    // run message loop
    int res = Platform.instance.enterMessageLoop();

    tablet.uninit();

    return res;
}
