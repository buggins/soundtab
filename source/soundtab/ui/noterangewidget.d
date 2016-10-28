module soundtab.ui.noterangewidget;

import dlangui.widgets.widget;
import soundtab.ui.noteutil;
import dlangui.core.signals;

interface NoteRangeChangeHandler {
    void onNoteRangeChange(int minNote, int maxNote);
}

class NoteRangeWidget : Widget {

    Signal!NoteRangeChangeHandler onNoteRangeChange;

    double _currentPitch = 440;

    int _minNote;
    int _maxNote;
    int _keyWidth;
    int _keys;

    int _rangeStart;
    int _rangeEnd;

    @property int rangeStart() { return _rangeStart; }
    @property int rangeEnd() { return _rangeEnd; }

    this() {
        super("pitch");
        styleId = "EDIT_LINE";
        layoutWidth = FILL_PARENT;
        _minNote = fullNameToNote("C0");
        _maxNote = fullNameToNote("B8");
        _rangeStart = fullNameToNote("C2");
        _rangeEnd = fullNameToNote("C6");
        tooltipText = "Left mouse button - set range start; Right mous button - set range end";
    }

    void setPitch(double freq) {
        _currentPitch = freq;
        invalidate();
    }

    void handleRangeChange(int start, int end) {
        if (_rangeStart == start && _rangeEnd == end)
            return;
        if (_rangeStart == start) {
            _rangeEnd = end;
            // end is moved
            if (_rangeEnd - _rangeStart < 12)
                _rangeStart = _rangeEnd - 12;
        } else {
            // start is moved
            _rangeStart = start;
            if (_rangeEnd - _rangeStart < 12)
                _rangeEnd = _rangeStart + 12;
        }
        if (isBlackNote(_rangeStart))
            _rangeStart--;
        if (isBlackNote(_rangeEnd))
            _rangeEnd++;
        if (_rangeEnd - _rangeStart < 12)
            _rangeEnd = _rangeStart + 12;
        if (_rangeStart < _minNote) {
            _rangeStart = _minNote;
            if (_rangeEnd - _rangeStart < 12)
                _rangeEnd = _rangeStart + 12;
        }
        if (_rangeEnd > _maxNote) {
            _rangeEnd = _maxNote;
            if (_rangeEnd - _rangeStart < 12)
                _rangeStart = _rangeEnd - 12;
        }
        //Log.d("NoteRangeWidget: new note range = ", noteToFullName(_rangeStart), " .. ", noteToFullName(_rangeEnd));
        if (onNoteRangeChange.assigned)
            onNoteRangeChange(_rangeStart, _rangeEnd);
    }

    /// process mouse event; return true if event is processed by widget.
    override bool onMouseEvent(MouseEvent event) {
        if (event.action == MouseAction.ButtonDown || (event.action == MouseAction.Move && event.buttonFlags)) {
            int note = noteByPoint(event.x);
            int side = 0;
            if (event.action == MouseAction.ButtonDown && event.button == MouseButton.Left)
                side = -1;
            if (event.action == MouseAction.Move && event.buttonFlags & MouseFlag.LButton)
                side = -1;
            if (event.action == MouseAction.ButtonDown && event.button == MouseButton.Right)
                side = 1;
            if (event.action == MouseAction.Move && event.buttonFlags & MouseFlag.RButton)
                side = 1;
            if (side < 0) {
                handleRangeChange(note, _rangeEnd);
                invalidate();
                return true;
            }
            if (side > 0) {
                handleRangeChange(_rangeStart, note);
                invalidate();
                return true;
            }
        }
        return super.onMouseEvent(event);
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

    int noteByPoint(int x) {
        Rect rc = _pos;
        applyMargins(rc);
        applyPadding(rc);
        int delta = (rc.width  - 2) - (_keyWidth * _keys);
        rc.left += delta / 2;
        rc.right = rc.left + _keyWidth * _keys + 1;
        rc.shrink(1, 1);
        if (x < rc.left)
            return _minNote;
        if (x >= rc.right)
            return _maxNote;
        Rect keyRect = rc;
        int index = 0;
        for (int i = _minNote; i <= _maxNote; i++) {
            if (!isBlackNote(i)) {
                keyRect.left = rc.left + _keyWidth * index;
                keyRect.right = keyRect.left + _keyWidth - 1;
                if (x < keyRect.right)
                    return i;
                index++;
            }
        }
        return _maxNote;
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

        double note = toLogScale(_currentPitch);
        int currentNote = getNearestNote(note);
        int index = 0;
        int noteDelta = cast(int)((note - currentNote) * 1000);
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
                    int x = hrc.middlex + hrc.width * noteDelta / 1000;
                    buf.fillRect(Rect(x, hrc.top, x + 1, hrc.bottom), 0xFF0000);
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
                    int x = blackRect.middlex + blackRect.width * noteDelta / 1000;
                    buf.fillRect(Rect(x, blackRect.top, x + 1, blackRect.bottom), 0xFF0000);
                }
            }
        }
    }

}

