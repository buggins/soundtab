module soundtab.ui.slidercontroller;

import dlangui.widgets.widget;
import dlangui.widgets.layouts;
import dlangui.widgets.controls;
import dlangui.widgets.scrollbar;
import dlangui.widgets.groupbox;
import dlangui.core.signals;
import std.conv : to;

import soundtab.audio.instruments;

interface SliderControllerHandler {
    void onController(SliderController source, int value);
}

class SliderController : GroupBox {
    Signal!SliderControllerHandler onChange;
    private SliderWidget _slider;
    private ControllerId _controllerId;

    @property ControllerId controllerId() { return _controllerId; }

    this(ControllerId ID, dstring label, int minValue, int maxValue, int value) {
        super(to!string(ID), label);
        _controllerId = ID;
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
