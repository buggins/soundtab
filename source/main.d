module app;

import dlangui;

mixin APP_ENTRY_POINT;

/// entry point for dlangui based application
extern (C) int UIAppMain(string[] args) {

    import derelict.wintab.wintab;
    //import core.sys.windows.windows;
    DerelictWintab.load();

    if (!WTInfo(0, 0, null)) {
        Log.e("WinTab services not available");
        //return 1;
    }
    char[50] wname;
    if (!WTInfo(WTI_DEVICES, DVC_NAME, cast(void*)wname.ptr)) {
        Log.e("WinTab cannot get device name");
        return 1;
    }
    if (wname[0 .. 5] != "WACOM") {
        Log.e("Not a wacom device");
        return 2;
    }

    AXIS[3] tpOri;
	uint tilt_support = WTInfo(WTI_DEVICES, DVC_ORIENTATION, cast(void*)&tpOri);
    // load theme from file "theme_default.xml"
    //Platform.instance.uiTheme = "theme_default";

    // create window
    Log.d("Creating window");
    Window window = Platform.instance.createWindow("DlangUI example - HelloWorld", null);
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
