module soundtab.ui.pressurewidget;

import dlangui.widgets.widget;
import soundtab.ui.noteutil;

class PressureWidget : Widget {

    double _currentPressure = 0;
    bool _currentProximity = false;

    uint _inactiveFrameColor = 0x808080;
    uint _activeFrameColor = 0x00C000;
    uint _gaugeColor = 0x00C000;

    this() {
        super("pressure");
        margins = Rect(5,5,5,5).pointsToPixels;
        //styleId = "EDIT_LINE";
    }

    /** 
    Measure widget according to desired width and height constraints. (Step 1 of two phase layout). 
    */
    override void measure(int parentWidth, int parentHeight) {
        int h = font.height * 150 / 100;
        dstring label = "Pressure";
        FontRef fnt = font;
        Point sz = fnt.textSize(label);
        measuredContent(parentWidth, parentHeight, sz.x + h / 2, h);
    }

    /// Draw widget at its position to buffer
    override void onDraw(DrawBuf buf) {
        if (visibility != Visibility.Visible)
            return;
        Rect rc = _pos;
        applyMargins(rc);
        auto saver = ClipRectSaver(buf, rc, alpha);
        DrawableRef bg = backgroundDrawable;
        if (!bg.isNull) {
            bg.drawTo(buf, rc, state);
        }
        applyPadding(rc);
        _needDraw = false;

        dstring label = "Pressure";
        FontRef fnt = font;
        Point sz = fnt.textSize(label);
        fnt.drawText(buf, rc.middlex - sz.x / 2, rc.middley - sz.y, label, 0x808080);

        rc.top = rc.middley + 2;

        buf.drawFrame(rc, _currentProximity ? (_currentPressure > 0 ? _activeFrameColor : _activeFrameColor) : _inactiveFrameColor, Rect(1,1,1,1), 
                      0xE0202020);
        rc.shrink(2, 2);

        if (_currentProximity && _currentPressure > 0) {
            int x = cast(int)(rc.left + _currentPressure * rc.width);
            buf.fillRect(Rect(rc.left, rc.top, x, rc.bottom), _gaugeColor);
        }

    }

    void setPressure(double press, bool proximity) {
        _currentPressure = press;
        _currentProximity = proximity;
        invalidate();
    }


}

