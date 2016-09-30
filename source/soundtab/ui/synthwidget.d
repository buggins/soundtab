module soundtab.ui.synthwidget;

import dlangui.widgets.widget;
import dlangui.widgets.layouts;
import dlangui.widgets.controls;
import soundtab.ui.sndcanvas;
import derelict.wintab.tablet;
import soundtab.ui.pitchwidget;
import soundtab.ui.pressurewidget;
import soundtab.audio.utils;
import soundtab.audio.instruments;

class SynthWidget : VerticalLayout, TabletPositionHandler, TabletProximityHandler {
    SoundCanvas _soundCanvas;
    VerticalLayout _controlsLayout;
    Tablet _tablet;
    PitchWidget _pitchWidget;
    PressureWidget _pressureWidget;
    AudioPlayback _playback;
    MyAudioSource _instrument;

    ~this() {
        _tablet.uninit();
        if (_playback) {
            destroy(_playback);
        }
    }

    this(Tablet tablet) {
        super("synth");
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


        _controlsh.addChild(new CheckBox("pitchCorrection", "Pitch correction"d));


        _controlsh.addChild(new HSpacer());

        _pressureWidget = new PressureWidget();
        _controlsh.addChild(_pressureWidget);

        _pitchWidget = new PitchWidget();
        _controlsh.addChild(_pitchWidget);

        _soundCanvas = new SoundCanvas(this);
        addChild(_soundCanvas);

        _playback = new AudioPlayback();
        _instrument = new MyAudioSource();
        _playback.setSynth(_instrument);
        _playback.start();
    }

    @property bool tabletInitialized() { return _tablet.isInitialized; }

    bool _proximity = false;
    void onPositionChange(double x, double y, double pressure, uint buttons) {
        _soundCanvas.setPosition(x, y, pressure);
        _pitchWidget.setPitch(_soundCanvas.pitch);
        _pressureWidget.setPressure(pressure, _proximity);
        _instrument.setSynthParams(_soundCanvas.pitch, pressure, y);
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
