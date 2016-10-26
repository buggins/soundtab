module soundtab.ui.slidercontroller;

import dlangui.widgets.widget;
import dlangui.widgets.layouts;
import dlangui.widgets.controls;
import dlangui.widgets.scrollbar;
import dlangui.widgets.groupbox;
import dlangui.core.signals;

interface SliderControllerHandler {
    void onController(SliderController source, int value);
}

class SliderController : GroupBox {
    Signal!SliderControllerHandler onChange;
    private SliderWidget _slider;

    this(string ID, dstring label, int minValue, int maxValue, int value) {
        super(ID, label);
        _slider = new SliderWidget(null, Orientation.Horizontal);
        _slider.setRange(minValue, maxValue);
        _slider.position = value;
        _slider.scrollEvent = &onScrollEvent;
        addChild(_slider);
    }

    @property int value() { return _slider.position; }
    @property SliderController value(int newValue) { _slider.position = newValue; return this; }

    protected bool onScrollEvent(AbstractSlider source, ScrollEvent event) {
        if (onChange.assigned)
            onChange(this, event.position);
        return true;
    }
}
