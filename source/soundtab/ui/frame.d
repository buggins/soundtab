module soundtab.ui.frame;

import dlangui.core.events;
import dlangui.core.stdaction;
import dlangui.widgets.widget;
import dlangui.widgets.appframe;
import dlangui.widgets.menu;
import dlangui.dialogs.dialog;
import dlangui.dialogs.settingsdialog;


import soundtab.ui.actions;
import soundtab.ui.settings;

import derelict.wintab.wintab;
import derelict.wintab.tablet;
import soundtab.ui.synthwidget;
import soundtab.audio.playback;

class SoundFrame : AppFrame {
    import dlangui.platforms.windows.winapp;

    SynthWidget _synth;
    Tablet _tablet;
    AudioPlayback _playback;
    AudioSettings _settings;
    long _statusTimer;

    this(Win32Window window) {
        _tablet = new Tablet();
        window.onUnknownWindowMessage = &_tablet.onUnknownWindowMessage;
        _tablet.init(window.windowHandle);
        super();
        applySettings(_settings);
        window.mainWidget = this;
        _statusTimer = setTimer(100);
        _playback.start();
    }

    private string _lastStatusText;
    override bool onTimer(ulong id) {
        if (id == _statusTimer) {
            import std.utf : toUTF32;
            string status = _playback.stateString;
            if (status != _lastStatusText) {
                statusLine.setStatusText(status.toUTF32);
                _lastStatusText = status;
            }
            _synth.updatePlayPosition();
            return true;
        } else {
            return super.onTimer(id);
        }
    }

    ~this() {
        _settings.save();
        _tablet.uninit();
        if (_playback) {
            destroy(_playback);
        }
    }

    override protected void initialize() {
        import std.path;
        _playback = new AudioPlayback();
        _appName = "SoundTab";
        //_editorTool = new DEditorTool(this);
        _settings = new AudioSettings(buildNormalizedPath(settingsDir, "settings.json"));
        _settings.load();
        _settings.updateDefaults();
        _settings.save();
        super.initialize();
    }

    /// returns global IDE settings
    @property AudioSettings settings() { return _settings; }

    /// apply changed settings
    void applySettings(AudioSettings settings) {
        // apply audio playback device settings
        string dev = settings.playbackDevice;
        bool exclusive = settings.exclusiveMode;
        int minFrame = settings.minFrameMillis;
        import wasapi.comutils : MMDevice;
        import wasapi.comutils : MMDevice;
        import std.utf : toUTF32;
        MMDevice[] devices = _playback.getDevices();
        MMDevice device = devices.length > 0 ? devices[0] : null;
        foreach(d; devices) {
            if (d.id == dev)
                device = d;
        }
        _playback.setDevice(device, exclusive, minFrame);
    }

    void showPreferences() {
        StringListValue[] deviceList;
        deviceList ~= StringListValue("default", "Default"d);
        import wasapi.comutils : MMDevice;
        import std.utf : toUTF32;
        MMDevice[] devices = _playback.getDevices();
        string dev = _settings.playbackDevice;
        bool deviceFound = false;
        foreach(d; devices) {
            deviceList ~= StringListValue(d.id, d.friendlyName.toUTF32);
            if (d.id == dev)
                deviceFound = true;
        }
        if (!deviceFound)
            _settings.playbackDevice = "default";
        //Log.d("settings before copy:\n", _settings.setting.toJSON(true));
        Setting s = _settings.copySettings();
        //Log.d("settings after copy:\n", s.toJSON(true));
        SettingsDialog dlg = new SettingsDialog(UIString("SoundTab settings"d), window, s, createSettingsPages(deviceList));
        dlg.dialogResult = delegate(Dialog dlg, const Action result) {
            if (result.id == ACTION_APPLY.id) {
                //Log.d("settings after edit:\n", s.toJSON(true));
                _settings.applySettings(s);
                applySettings(_settings);
                _settings.save();
            }
        };
        dlg.show();
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
                case Actions.FileOptions:
                    showPreferences();
                    return true;
                default:
                    break;
            }
        }
        return false;
    }
}
