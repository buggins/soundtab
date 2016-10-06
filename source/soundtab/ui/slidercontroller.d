module soundtab.ui.slidercontroller;

import dlangui.widgets.widget;
import dlangui.widgets.layouts;
import dlangui.widgets.controls;
import dlangui.core.signals;

interface SliderControllerHandler {
    void onController(SliderController source, int value);
}

class SliderController : VerticalLayout {
    Signal!SliderControllerHandler onChange;
    private TextWidget _label;
    private SliderWidget _slider;

    this(string ID, dstring label, int minValue, int maxValue, int value) {
        super(ID);
        styleId = STYLE_EDIT_LINE;
        _label = new TextWidget(null, label);
        _slider = new SliderWidget(null, Orientation.Horizontal);
        _slider.setRange(minValue, maxValue);
        _slider.position = minValue;
        _slider.scrollEvent = &onScrollEvent;
        addChild(_label);
        addChild(_slider);
    }

    protected bool onScrollEvent(AbstractSlider source, ScrollEvent event) {
        if (onChange.assigned)
            onChange(this, event.position);
        return true;
    }
}
