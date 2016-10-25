module soundtab.ui.frame;

import dlangui.widgets.widget;
import dlangui.widgets.appframe;
import dlangui.widgets.menu;
import dlangui.core.events;

import soundtab.ui.actions;

import derelict.wintab.wintab;
import derelict.wintab.tablet;
import soundtab.ui.synthwidget;
import soundtab.audio.playback;

class SoundFrame : AppFrame {

    SynthWidget _synth;
    Tablet _tablet;
    AudioPlayback _playback;

    this(Tablet tablet) {
        _tablet = tablet;
        _playback = new AudioPlayback();
        super();
        _appName = "SoundTab";
    }

    ~this() {
        _tablet.uninit();
        if (_playback) {
            destroy(_playback);
        }
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
        _synth = new SynthWidget(this, _tablet, _playback);
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
