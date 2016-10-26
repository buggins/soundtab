module soundtab.ui.synthwidget;

import dlangui.widgets.widget;
import dlangui.widgets.layouts;
import dlangui.widgets.controls;
import dlangui.widgets.combobox;
import dlangui.widgets.groupbox;
import soundtab.ui.sndcanvas;
import derelict.wintab.tablet;
import soundtab.ui.noteutil;
import soundtab.ui.pitchwidget;
import soundtab.ui.pressurewidget;
import soundtab.ui.noterangewidget;
import soundtab.ui.slidercontroller;
import soundtab.audio.playback;
import soundtab.audio.instruments;

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
    Instrument _instrument;
    HorizontalLayout _controllers;

    ComboBox _instrSelection;
    SliderController _chorus;
    SliderController _reverb;
    SliderController _vibrato;
    SliderController _vibratoFreq;
    SliderController _pitchCorrection;

    PitchCorrector _corrector;

    this(SoundFrame frame, Tablet tablet, AudioPlayback playback) {
        super("synth");
        _frame = frame;
        _playback = playback;
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
        HorizontalLayout _controlsh = new HorizontalLayout();
        _controlsh.layoutWidth = FILL_PARENT;
        _controlsh.layoutHeight = WRAP_CONTENT;
        _controlsh.margins = Rect(3,3,3,3);
        _controlsLayout.addChild(_controlsh);

        int corrValue = _frame.settings.getControllerValue("pitchCorrection", 0);
        _pitchCorrection = new SliderController("pitchCorrection", "Pitch correction", 0, 1000, corrValue);
        _pitchCorrection.onChange = &onController;

        Instrument[] instr = getInstrumentList();
        StringListValue[] instrList;
        foreach(i; instr) {
            instrList ~= StringListValue(i.id, i.name);
        }
        GroupBox gb = new GroupBox("instrgb", "Instrument"d);
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
            if (_frame.settings.instrumentId != id) {
                _frame.settings.instrumentId = id;
                _frame.settings.save();
            }
            return true;
        };
        gb.addChild(_instrSelection);
        _controlsh.addChild(gb);
        _controlsh.addChild(_controllers);



        _controlsh.addChild(new HSpacer());

        _controlsh.addChild(_pitchCorrection);

        _pitchWidget = new PitchWidget();
        _controlsh.addChild(_pitchWidget);
    
        _pressureWidget = new PressureWidget();
        _controlsh.addChild(_pressureWidget);

        _soundCanvas = new SoundCanvas(this);
        addChild(_soundCanvas);

        _noteRangeWidget = new NoteRangeWidget();
        addChild(_noteRangeWidget);

        _soundCanvas.setNoteRange(_noteRangeWidget.rangeStart, _noteRangeWidget.rangeEnd);
        _noteRangeWidget.onNoteRangeChange = &onNoteRangeChange;


        import derelict.mpg123;
        try {
            DerelictMPG123.load();
            Log.d("libmpg123 shared library is loaded ok");
        } catch (Exception e) {
            Log.e("Cannot load libmpg123 shared library", e);
        }

    }

    void setInstrument(string id) {
        if (_instrument && _instrument.id == id)
            return;
        Instrument[] instr = getInstrumentList();
        Instrument found = instr[0];
        int foundIndex = 0;
        foreach(index, i; instr) {
            if (id == i.id) {
                found = i;
                foundIndex = index;
            }
        }
        _instrSelection.selectedItemIndex = foundIndex;
        _instrument = found;

        createControllers();

        _playback.setSynth(_instrument);
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
        }
        int corrValue = _frame.settings.getControllerValue("pitchCorrection", 0);
        _corrector.amount = corrValue;
        _pitchCorrection.value = corrValue;
    }

    void onController(SliderController source, int value) {
        switch (source.id) {
            case "pitchCorrection":
                _corrector.amount = value;
                break;
            default:
                break;
        }
        _frame.settings.setControllerValue(source.id, value);
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

}
