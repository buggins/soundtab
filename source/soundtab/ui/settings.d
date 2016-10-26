module soundtab.ui.settings;

import dlangui.core.settings;
import dlangui.dialogs.settingsdialog;
import dlangui.core.i18n;
import dlangui.widgets.lists;

/// local settings for project (not supposed to put under source control)
class AudioSettings : SettingsFile {
    this(string filename) {
        super(filename);
    }

    /// override to do something after loading - e.g. set defaults
    override void afterLoad() {
    }

    override void updateDefaults() {
        Setting audio = audioSettings();
        audio.setStringDef("device", "default");
        audio.setBooleanDef("exclusiveMode", false);
        audio.setIntegerDef("minFrameMillis", 3);
    }

    @property Setting audioSettings() {
        Setting res = _setting.objectByPath("audio/playback", true);
        return res;
    }

    @property Setting instrumentSettings() {
        Setting res = _setting.objectByPath("instrument", true);
        return res;
    }

    @property Setting controllerSettings() {
        string instr = instrumentId;
        Setting res = _setting.objectByPath("controllerSettings", true);
        res = res.objectByPath(instr, true);
        return res;
    }

    @property string playbackDevice() {
        return audioSettings.getString("device", "default");
    }

    @property AudioSettings playbackDevice(string dev) {
        audioSettings.setString("device", dev);
        return this;
    }

    @property bool exclusiveMode() {
        return audioSettings.getBoolean("exclusiveMode", true);
    }

    @property int minFrameMillis() {
        return cast(int)audioSettings.getInteger("minFrameMillis", 3);
    }

    @property string instrumentId() {
        return instrumentSettings.getString("instrumentId", "ethereal");
    }

    @property AudioSettings instrumentId(string instrId) {
        instrumentSettings.setString("instrumentId", instrId);
        return this;
    }

    AudioSettings setControllerValue(string controllerId, int value) {
        Setting s = controllerSettings();
        s.setInteger(controllerId, value);
        return this;
    }

    int getControllerValue(string controllerId, int defValue) {
        Setting s = controllerSettings();
        int res = cast(int)s.getInteger(controllerId, defValue);
        return res;
    }
}

SettingsPage createSettingsPages(StringListValue[] deviceList) {
    SettingsPage res = new SettingsPage("", UIString(""d));
    SettingsPage audio = res.addChild("audio", UIString("Audio"d));
    audio.addStringComboBox("audio/playback/device", UIString("Audio Playback Device"d), deviceList);
    audio.addCheckbox("audio/playback/exclusiveMode", UIString("Exclusive mode"d));
    StringListValue[] minFrameList = [
        StringListValue(1, "1 ms"d),
        StringListValue(2, "2 ms"d),
        StringListValue(3, "3 ms"d),
        StringListValue(4, "4 ms"d),
        StringListValue(5, "5 ms"d),
        StringListValue(6, "6 ms"d),
        StringListValue(10, "10 ms"d),
    ];
    audio.addIntComboBox("audio/playback/minFrameMillis", UIString("Minimal frame (milliseconds)"d), minFrameList);
    return res;
}
