module soundtab.ui.pressurewidget;

import dlangui.widgets.widget;
import soundtab.ui.noteutil;

class PressureWidget : Widget {

    double _currentPressure = 0;
    bool _currentProximity = false;

    this() {
        super("pitch");
        margins = Rect(3,3,3,3);
        //styleId = "EDIT_LINE";
    }

    /** 
    Measure widget according to desired width and height constraints. (Step 1 of two phase layout). 
    */
    override void measure(int parentWidth, int parentHeight) {
        int h = font.height * 2;
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

        buf.drawFrame(rc, _currentProximity ? (_currentPressure > 0 ? 0x40C040 : 0x40FF40) : 0x808080, Rect(1,1,1,1), 0xFFFFFF);
        rc.shrink(2, 2);

        if (_currentProximity && _currentPressure > 0) {
            int x = cast(int)(rc.left + _currentPressure * rc.width);
            buf.fillRect(Rect(rc.left, rc.top, x, rc.bottom), 0x008000);
        }

    }

    void setPressure(double press, bool proximity) {
        _currentPressure = press;
        _currentProximity = proximity;
        invalidate();
    }


}

