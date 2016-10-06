module soundtab.ui.noterangewidget;

import dlangui.widgets.widget;
import soundtab.ui.noteutil;

class NoteRangeWidget : Widget {

    double _currentPitch = 440;

    int _minNote;
    int _maxNote;
    int _keyWidth;
    int _keys;

    int _rangeStart;
    int _rangeEnd;

    this() {
        super("pitch");
        styleId = "EDIT_LINE";
        layoutWidth = FILL_PARENT;
        _minNote = fullNameToNote("C0");
        _maxNote = fullNameToNote("B8");
        _rangeStart = fullNameToNote("C2");
        _rangeEnd = fullNameToNote("C6");
    }

    void setPitch(double freq) {
        _currentPitch = freq;
        invalidate();
    }

    /** 
    Measure widget according to desired width and height constraints. (Step 1 of two phase layout). 
    */
    override void measure(int parentWidth, int parentHeight) {
        int w = parentWidth;
        Rect m = margins;
        Rect p = padding;
        w -= m.left + m.right + p.left + p.right;
        _keys = whiteNotesInRange(_minNote, _maxNote);
        _keyWidth = w / _keys;
        if (_keyWidth < 4)
            _keyWidth = 4;

        int h = _keyWidth * 5;
        measuredContent(parentWidth, parentHeight, _keyWidth * _keys, h);
    }

    /// Set widget rectangle to specified value and layout widget contents. (Step 2 of two phase layout).
    override void layout(Rect rc) {
        if (visibility == Visibility.Gone) {
            return;
        }
        super.layout(rc);
        int w = rc.width;
        Rect m = margins;
        Rect p = padding;
        w -= m.left + m.right + p.left + p.right;
        _keys = whiteNotesInRange(_minNote, _maxNote);
        _keyWidth = w / _keys;
        if (_keyWidth < 4)
            _keyWidth = 4;
    }


    /// Draw widget at its position to buffer
    override void onDraw(DrawBuf buf) {
        if (visibility != Visibility.Visible)
            return;
        Rect rc = _pos;
        applyMargins(rc);
        auto saver = ClipRectSaver(buf, rc, alpha);
        //buf.fillRect(rc, 0x000000);
        applyPadding(rc);
        _needDraw = false;
        int delta = (rc.width  - 2) - (_keyWidth * _keys);
        rc.left += delta / 2;
        rc.right = rc.left + _keyWidth * _keys + 1;
        buf.fillRect(rc, 0x000000);
        rc.shrink(1, 1);
        Rect keyRect = rc;

        int currentNote = getNearestNote(toLogScale(_currentPitch));
        int index = 0;
        for (int i = _minNote; i <= _maxNote; i++) {
            bool inRange = (i >= _rangeStart) && (i <= _rangeEnd);
            if (!isBlackNote(i)) {
                uint color = inRange ? 0xFFFFFF : 0xC0C0C0;
                //if (i == currentNote)
                //    color = 0xFFC0C0;
                keyRect.left = rc.left + _keyWidth * index;
                keyRect.right = keyRect.left + _keyWidth - 1;
                buf.fillRect(keyRect, color);
                if (i == currentNote) {
                    Rect hrc = keyRect;
                    hrc.left += 1;
                    hrc.right -= 1;
                    hrc.bottom -= 1;
                    buf.fillRect(hrc, 0xFFC0C0);
                }
                index++;
            }
            if (isBlackNote(i - 1)) {
                uint color = 0x000000;
                if (i - 1 == currentNote)
                    color = 0xFFC0C0;

                Rect blackRect = keyRect;
                blackRect.bottom = blackRect.bottom - blackRect.height * 40 / 100;
                blackRect.left -= _keyWidth / 2;
                blackRect.right -= _keyWidth / 2;
                blackRect.left += _keyWidth / 6;
                blackRect.right -= _keyWidth / 6;
                buf.fillRect(blackRect, 0x000000);
                if (color != 0x000000) {
                    blackRect.left += 2;
                    blackRect.right -= 2;
                    blackRect.bottom -= 2;
                    //blackRect.top += 1;
                    buf.fillRect(blackRect, color);
                }
            }
        }
    }

}

