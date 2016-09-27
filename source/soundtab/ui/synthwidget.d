module soundtab.ui.synthwidget;

import dlangui.widgets.widget;
import dlangui.widgets.layouts;
import dlangui.widgets.controls;
import soundtab.ui.sndcanvas;
import derelict.wintab.tablet;
import soundtab.ui.pitchwidget;

class SynthWidget : VerticalLayout {
    SoundCanvas _soundCanvas;
    VerticalLayout _controlsLayout;
    Tablet _tablet;
    PitchWidget _pitchWidget;
    this(Tablet tablet) {
        super("synth");
        _tablet = tablet;
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
}
