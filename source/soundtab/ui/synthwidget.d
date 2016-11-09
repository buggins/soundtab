module soundtab.ui.synthwidget;

import dlangui.widgets.widget;
import dlangui.widgets.layouts;
import dlangui.widgets.controls;
import dlangui.widgets.combobox;
import dlangui.widgets.groupbox;
import dlangui.widgets.scrollbar;
import soundtab.ui.sndcanvas;
import soundtab.ui.actions;
import derelict.wintab.tablet;
import soundtab.ui.noteutil;
import soundtab.ui.pitchwidget;
import soundtab.ui.pressurewidget;
import soundtab.ui.noterangewidget;
import soundtab.ui.slidercontroller;
import soundtab.audio.playback;
import soundtab.audio.audiosource;
import soundtab.audio.instruments;
import soundtab.audio.mp3player;

class PlayerPanel : GroupBox {
    import soundtab.ui.frame;
    private SoundFrame _frame;
    private Mp3Player _player;
    private TextWidget _playFileName;
    private TextWidget _playPositionText;
    private SliderWidget _playSlider;
    private SliderController _volumeControl;
    this(SoundFrame frame) {
        super("playerControls", "Accompaniment"d, Orientation.Horizontal);
        _frame = frame;
        layoutWidth = FILL_PARENT;
        Widget openButton = new Button(ACTION_FILE_OPEN_ACCOMPANIMENT);
        Widget playButton = new Button(ACTION_FILE_PLAY_PAUSE_ACCOMPANIMENT);

        _volumeControl = new SliderController(ControllerId.AccompanimentVolume, "Volume"d, 0, 1000, _frame.settings.accompanimentVolume);

        VerticalLayout sliderLayout = new VerticalLayout();
        HorizontalLayout textLayout = new HorizontalLayout();
        sliderLayout.layoutWidth = FILL_PARENT;
        textLayout.layoutWidth = FILL_PARENT;
        _playSlider = new SliderWidget("playPosition");
        _playSlider.layoutWidth = FILL_PARENT;
        _playSlider.setRange(0, 10000);
        _playSlider.position = 0;
        _playSlider.scrollEvent = &onScrollEvent;
        _playFileName = new TextWidget("playFileName", ""d);
        _playFileName.alignment = Align.Center;
        _playPositionText = new TextWidget("playPositionText", ""d);
        _playPositionText.alignment = Align.Center;
        textLayout.addChild(_playFileName);
        textLayout.addChild(new HSpacer());
        textLayout.addChild(_playPositionText);
        sliderLayout.addChild(textLayout);
        sliderLayout.addChild(_playSlider);
        sliderLayout.margins = Rect(5, 0, 5, 0).pointsToPixels;
        sliderLayout.padding = Rect(5, 0, 5, 0).pointsToPixels;

        addChild(_volumeControl);
        addChild(openButton);
        addChild(sliderLayout);
        addChild(playButton);
        _player = new Mp3Player();
        updatePlayPosition();
        _volumeControl.onChange = &onVolume;
    }

    protected void onVolume(SliderController source, int value) {
        _frame.settings.accompanimentVolume = value;
        _player.volume = value / 1000.0f;
    }

    PlayPosition _position;
    string _filename;

    static dstring secondsToString(float v) {
        import std.math : round;
        import std.format;
        import std.utf : toUTF32;
        int seconds = cast(int)round(v);

        // utf conversion is to bypass dmd 2.072.0 bug
        return ("%d:%02d".format(seconds / 60, (seconds % 60))).toUTF32;
    }

    void playPauseAccomp() {
        _player.paused = !_player.paused;
    }

    void openAccompanimentFile(string filename) {
        if (!_player.loadFromFile(filename)) {
            if (window)
                window.showMessageBox("MP3 file opening error"d, "Cannot load MP3 file "d);
        }
    }

    void updatePlayPosition() {
        import std.path : baseName;
        import std.utf : toUTF32;
        _filename = _player.filename;
        _position = _player.position;
        dstring fn = _filename ? _filename.baseName.toUTF32 : null;
        if (!fn.length)
            fn = "[no MP3 file opened]"d;
        if (_playFileName.text != fn)
            _playFileName.text = fn;
        dchar[] positionText;
        positionText ~= secondsToString(_position.currentPosition);
        positionText ~= " / "d;
        positionText ~= secondsToString(_position.length);
        if (_playPositionText.text != positionText)
            _playPositionText.text = cast(dstring)positionText;
        int percent = _position.positionPercent;
        if (_playSlider.position != percent)
            _playSlider.position = percent;
    }

    protected bool onScrollEvent(AbstractSlider source, ScrollEvent event) {
        if (event.action == ScrollAction.SliderMoved) {
            //int percent = _position.positionPercent;
            _player.position = _position.percentToSeconds(event.position);
            //if (event.position != percent)
            //    updatePlayPosition();

        }
        return true;
    }
}

class SynthWidget : VerticalLayout, TabletPositionHandler, TabletProximityHandler {
    import soundtab.ui.frame;

    SoundFrame _frame;
    SoundCanvas _soundCanvas;
    VerticalLayout _controlsLayout;
    Tablet _tablet;
    PitchWidget _pitchWidget;
    NoteRangeWidget _noteRangeWidget;
    PressureWidget _pressureWidget;
    AudioPlayback _playback;
    Mixer _mixer;
    Instrument _instrument;
    HorizontalLayout _controllers;
    PlayerPanel _playerPanel;

    ComboBox _instrSelection;
    SliderController _chorus;
    SliderController _reverb;
    SliderController _vibrato;
    SliderController _vibratoFreq;
    SliderController _pitchCorrection;
    SliderController _volumeControl;

    PitchCorrector _corrector;

    this(SoundFrame frame, Tablet tablet, AudioPlayback playback) {
        super("synth");
        _frame = frame;
        _playback = playback;
        _mixer = new Mixer();
        _playback.setSynth(_mixer);
        _tablet = tablet;
        _tablet.onProximity = this;
        _tablet.onPosition = this;


        layoutWidth = FILL_PARENT;
        layoutHeight = FILL_PARENT;
        backgroundColor = 0xE0E8F0;

        _controlsLayout = new VerticalLayout();
        _controlsLayout.layoutWidth = FILL_PARENT;
        _controlsLayout.layoutHeight = WRAP_CONTENT;
        addChild(_controlsLayout);

        _playerPanel = new PlayerPanel(_frame);
        _mixer.addSource(_playerPanel._player);
        _controlsLayout.addChild(_playerPanel);

        GroupBox _controlsh = new GroupBox(null, "Instrument"d, Orientation.Vertical);
        _controlsh.layoutWidth = FILL_PARENT;
        _controlsh.layoutHeight = WRAP_CONTENT;
        //_controlsh.margins = Rect(3,3,3,3);
        _controlsLayout.addChild(_controlsh);
        HorizontalLayout instrLine1 = new HorizontalLayout();
        HorizontalLayout instrLine2 = new HorizontalLayout();
        instrLine1.layoutWidth = FILL_PARENT;
        instrLine2.layoutWidth = FILL_PARENT;
        _controlsh.addChild(instrLine1);
        _controlsh.addChild(instrLine2);

        int corrValue = _frame.settings.getControllerValue(ControllerId.PitchCorrection, 0);
        _pitchCorrection = new SliderController(ControllerId.PitchCorrection, "Pitch correction", 0, 1000, corrValue);
        _pitchCorrection.onChange = &onController;

        _volumeControl = new SliderController(ControllerId.InstrumentVolume, "Volume"d, 0, 1000, 1000);
        _volumeControl.value = 1000;
        _volumeControl.onChange = &onVolume;

        Instrument[] instr = getInstrumentList();
        StringListValue[] instrList;
        foreach(i; instr) {
            instrList ~= StringListValue(i.id, i.name);
        }
        VerticalLayout gb = new VerticalLayout("instrgb");
        gb.addChild(new TextWidget(null, "Selected instrument:"d));
        gb.margins = Rect(5, 0, 5, 0).pointsToPixels;
        gb.padding = Rect(5, 0, 5, 0).pointsToPixels;
        string instrId = _frame.settings.instrumentId;
        _instrSelection = new ComboBox("instrument", instrList);
        int instrIndex = 0;
        for (int i = 0; i < instr.length; i++) {
            if (instr[i].id == instrId)
                instrIndex = i;
        }
        _controllers = new HorizontalLayout();
        setInstrument(instrId);
        _instrSelection.itemClick = delegate(Widget source, int itemIndex) {
            Instrument ins = instr[itemIndex];
            setInstrument(ins.id);
            if (_frame.settings.instrumentId != ins.id) {
                _frame.settings.instrumentId = ins.id;
                _frame.settings.save();
            }
            createControllers();
            return true;
        };
        gb.addChild(_instrSelection);
        instrLine1.addChild(_volumeControl);
        instrLine1.addChild(gb);
        instrLine1.addChild(new HSpacer());
        instrLine1.addChild(_controllers);



        instrLine2.addChild(_pitchCorrection);

        _pitchWidget = new PitchWidget();
        instrLine2.addChild(_pitchWidget);
    
        _pressureWidget = new PressureWidget();
        instrLine2.addChild(_pressureWidget);
        instrLine2.addChild(new HSpacer());

        _soundCanvas = new SoundCanvas(this);
        addChild(_soundCanvas);

        _noteRangeWidget = new NoteRangeWidget();
        addChild(_noteRangeWidget);

        _soundCanvas.setNoteRange(_noteRangeWidget.rangeStart, _noteRangeWidget.rangeEnd);
        _noteRangeWidget.onNoteRangeChange = &onNoteRangeChange;

        string accompFile = _frame.settings.accompanimentFile;
        if (accompFile)
            _playerPanel.openAccompanimentFile(accompFile);
    }

    void setInstrument(string id) {
        if (_instrument && _instrument.id == id)
            return;
        if (_instrument) {
            _mixer.removeSource(_instrument);
        }
        Instrument[] instr = getInstrumentList();
        Instrument found = instr[0];
        int foundIndex = 0;
        foreach(index, i; instr) {
            if (id == i.id) {
                found = i;
                foundIndex = cast(int)index;
            }
        }
        _instrSelection.selectedItemIndex = foundIndex;
        _instrument = found;

        createControllers();

        if (_instrument)
            _mixer.addSource(_instrument);
    }

    /// create controllers for current instrument; set current values from settings
    void createControllers() {
        _controllers.removeAllChildren();
        immutable(Controller[]) controllers = _instrument.getControllers();
        foreach(controller; controllers) {
            int value = controller.value;
            value = _frame.settings.getControllerValue(controller.id, value);
            if (value < controller.minValue)
                value = controller.minValue;
            else if (value > controller.maxValue)
                value = controller.maxValue;
            SliderController w = new SliderController(controller.id, controller.name, controller.minValue, controller.maxValue, value);
            w.onChange = &onController;
            _controllers.addChild(w);
            _instrument.updateController(controller.id, value);
        }
        int corrValue = _frame.settings.getControllerValue(ControllerId.PitchCorrection, 0);
        _corrector.amount = corrValue;
        _pitchCorrection.value = corrValue;
        int volume = _frame.settings.getControllerValue(ControllerId.InstrumentVolume, 1000);
        _instrument.volume = volume / 1000.0f;
        _volumeControl.value = volume;
    }

    protected void onVolume(SliderController source, int value) {
        //_player.volume = value / 1000.0f;
        if (_instrument)
            _instrument.volume = value / 1000.0f;
        _frame.settings.setControllerValue(ControllerId.InstrumentVolume, value);
    }

    void onController(SliderController source, int value) {
        switch (source.id) {
            case "pitchCorrection":
                _corrector.amount = value;
                break;
            default:
                break;
        }
        _frame.settings.setControllerValue(source.controllerId, value);
        _instrument.updateController(source.controllerId, value);
    }

    void onNoteRangeChange(int minNote, int maxNote) {
        _soundCanvas.setNoteRange(minNote, maxNote);
    }

    @property bool tabletInitialized() { return _tablet.isInitialized; }

    bool _proximity = false;
    void onPositionChange(double x, double y, double pressure, uint buttons) {
        _soundCanvas.setPosition(x, y, pressure);
        double pitch = _corrector.correctPitch(_soundCanvas.pitch);
        _instrument.setSynthParams(pitch, pressure, y);
        _pitchWidget.setPitch(pitch);
        _noteRangeWidget.setPitch(pitch);
        _pressureWidget.setPressure(pressure, _proximity);
        invalidate();
        window.update();
    }

    void onProximity(bool enter) {
        if (_proximity != enter) {
            _proximity = enter;
            _pressureWidget.setPressure(0, _proximity);
            _playback.paused = !enter;
            invalidate();
            window.update();
        }
    }

    void updatePlayPosition() {
        _playerPanel.updatePlayPosition();
    }

    void playPauseAccomp() {
        _playerPanel.playPauseAccomp();
    }

    void openAccompanimentFile(string filename) {
        _playerPanel.openAccompanimentFile(filename);
    }
}
