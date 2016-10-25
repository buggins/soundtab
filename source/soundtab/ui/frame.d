module soundtab.ui.frame;

import dlangui.widgets.widget;
import dlangui.widgets.appframe;
import dlangui.widgets.menu;
import dlangui.core.events;

import soundtab.ui.actions;

import derelict.wintab.wintab;
import derelict.wintab.tablet;
import soundtab.ui.synthwidget;

class SoundFrame : AppFrame {

    SynthWidget _synth;
    Tablet _tablet;

    this(Tablet tablet) {
        _tablet = tablet;
        super();
        _appName = "SoundTab";
    }

    /// create main menu
    override protected MainMenu createMainMenu() {
        MenuItem mainMenuItems = new MenuItem();
        MenuItem fileItem = new MenuItem(new Action(1, "File"d));
        fileItem.add(ACTION_FILE_OPTIONS, ACTION_FILE_EXIT);
        mainMenuItems.add(fileItem);
        MainMenu mainMenu = new MainMenu(mainMenuItems);
        return mainMenu;
    }

    /// create app body widget
    override protected Widget createBody() {
        _synth = new SynthWidget(_tablet);
        return _synth;
    }

    /// override to handle specific actions
    override bool handleAction(const Action a) {
        if (a) {
            switch (a.id) {
                case Actions.FileExit:
                    //if (onCanClose())
                    window.close();
                    return true;
                default:
                    break;
            }
        }
        return false;
    }
}
