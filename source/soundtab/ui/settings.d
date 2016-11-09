module soundtab.ui.settings;

import dlangui.core.settings;
import dlangui.dialogs.settingsdialog;
import dlangui.core.i18n;
import dlangui.widgets.lists;
import soundtab.audio.instruments;

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

    @property int accompanimentVolume() {
        Setting accomp = accompSettings();
        return cast(int)accomp.getInteger("volume", 1000);
    }

    @property AudioSettings accompanimentVolume(int v) {
        Setting accomp = accompSettings();
        accomp.setInteger("volume", v);
        return this;
    }

    @property string accompanimentFile() {
        Setting accomp = accompSettings();
        return accomp.getString("file", null);
    }

    @property AudioSettings accompanimentFile(string fn) {
        Setting accomp = accompSettings();
        accomp.setString("file", fn);
        return this;
    }

    @property Setting audioSettings() {
        Setting res = _setting.objectByPath("audio/playback", true);
        return res;
    }

    @property Setting accompSettings() {
        Setting res = _setting.objectByPath("accompaniment", true);
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
        return instrumentSettings.getString("instrumentId", "sinewave");
    }

    @property AudioSettings instrumentId(string instrId) {
        instrumentSettings.setString("instrumentId", instrId);
        return this;
    }

    AudioSettings setControllerValue(ControllerId controllerId, int value) {
        import std.conv : to;
        Setting s = controllerSettings();
        s.setInteger(to!string(controllerId), value);
        return this;
    }

    int getControllerValue(ControllerId controllerId, int defValue) {
        import std.conv : to;
        Setting s = controllerSettings();
        int res = cast(int)s.getInteger(to!string(controllerId), defValue);
        return res;
    }

    @property int[2] noteRange() {
        int start = cast(int)controllerSettings.getInteger("noteRangeStart", -25);
        int end = cast(int)controllerSettings.getInteger("noteRangeEnd", 28);
        return [start, end];
    }

    @property AudioSettings noteRange(int[2] range) {
        controllerSettings.setInteger("noteRangeStart", range[0]);
        controllerSettings.setInteger("noteRangeEnd", range[1]);
        return this;
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
