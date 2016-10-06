module soundtab.ui.noterangewidget;

import dlangui.widgets.widget;
import soundtab.ui.noteutil;

class PitchWidget : Widget {

    double _currentPitch = 478;

    this() {
        super("pitch");
        styleId = "EDIT_LINE";
        layoutWidth = FILL_PARENT;
    }

    /** 
    Measure widget according to desired width and height constraints. (Step 1 of two phase layout). 
    */
    override void measure(int parentWidth, int parentHeight) {
        int w = parentWidth;
        Rect m = margins;
        Rect p = padding;
        w -= m.left + m.right + p.left + p.right;

        int h = font.height * 2;
        measuredContent(parentWidth, parentHeight, parentWidth, h);
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

        buf.fillRect(Rect(rc.middlex, rc.top, rc.middlex + 1, rc.top + rc.height / 3), 0x00C000);
        buf.fillRect(Rect(rc.middlex, rc.bottom - rc.height / 3, rc.middlex + 1, rc.bottom), 0x00C000);

        if (_currentPitch < 8 || _currentPitch > 20000)
            return; // no note
        double currentNote = toLogScale(_currentPitch);
        int intNote = getNearestNote(currentNote);
        double noteDiff = currentNote - intNote;
        dstring noteName = noteToFullName(currentNote);
        FontRef fnt = font;
        Point sz = fnt.textSize(noteName);
        fnt.drawText(buf, rc.middlex - sz.x / 2, rc.middley - sz.y/2, noteName, 0xA0A0A0);

        int x = cast(int)(rc.left + rc.width * (noteDiff + 0.5));
        buf.fillRect(Rect(x, rc.top, x+1, rc.bottom), 0x40FF0000);

    }

    void setPitch(double freq) {
        _currentPitch = freq;
        invalidate();
    }


}

