module soundtab.ui.synthwidget;

import dlangui.widgets.widget;
import dlangui.widgets.layouts;
import dlangui.widgets.controls;
import soundtab.ui.sndcanvas;

class SynthWidget : VerticalLayout {
    SoundCanvas _soundCanvas;
    VerticalLayout _controlsLayout;
    this() {
        super("synth");
        layoutWidth = FILL_PARENT;
        layoutHeight = FILL_PARENT;
        _controlsLayout = new VerticalLayout();
        _controlsLayout.layoutWidth = FILL_PARENT;
        _controlsLayout.layoutHeight = WRAP_CONTENT;
        addChild(_controlsLayout);

        _controlsLayout.addChild(new CheckBox("pitchCorrection", "Pitch correction"d));

        _soundCanvas = new SoundCanvas();
        addChild(_soundCanvas);
    }
}