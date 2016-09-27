module soundtab.ui.synthwidget;

import dlangui.widgets.widget;
import dlangui.widgets.layouts;
import dlangui.widgets.controls;
import soundtab.ui.sndcanvas;
import derelict.wintab.tablet;
import soundtab.ui.pitchwidget;

class SynthWidget : VerticalLayout, TabletPositionHandler, TabletProximityHandler {
    SoundCanvas _soundCanvas;
    VerticalLayout _controlsLayout;
    Tablet _tablet;
    PitchWidget _pitchWidget;

    ~this() {
        _tablet.uninit();
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

        _pitchWidget = new PitchWidget();
        _controlsh.addChild(_pitchWidget);

        _soundCanvas = new SoundCanvas();
        addChild(_soundCanvas);
    }

    bool _proximity = false;
    void onPositionChange(double x, double y, double pressure, uint buttons) {
        _soundCanvas.setPosition(x, y, pressure);
        _pitchWidget.setPitch(_soundCanvas._currentPitch);
        invalidate();
        window.update();
    }

    void onProximity(bool enter) {
        _proximity = enter;
    }

}
