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

//version = SLIDER_CONTROLLER_GROUPBOX;
version = SLIDER_CONTROLLER_VERTICAL_LAYOUT;
version (SLIDER_CONTROLLER_GROUPBOX) {
    alias SliderControllerBase = GroupBox;
} else {
    alias SliderControllerBase = VerticalLayout;
}

class SliderController : SliderControllerBase {
    Signal!SliderControllerHandler onChange;
    private SliderWidget _slider;
    private ControllerId _controllerId;
    version(SLIDER_CONTROLLER_VERTICAL_LAYOUT) {
        TextWidget _label;
    }

    @property ControllerId controllerId() { return _controllerId; }

    this(ControllerId ID, dstring label, int minValue, int maxValue, int value) {
        version(SLIDER_CONTROLLER_VERTICAL_LAYOUT) {
            super(to!string(ID));
            _label = new TextWidget(null, label);
            addChild(_label);
            margins = Rect(5, 0, 5, 0).pointsToPixels;
            padding = Rect(5, 0, 5, 0).pointsToPixels;
        } else {
            super(to!string(ID), label);
        }
        minWidth = 100.pointsToPixels;
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
