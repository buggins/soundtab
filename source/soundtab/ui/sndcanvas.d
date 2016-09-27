module soundtab.ui.sndcanvas;

import dlangui.widgets.widget;
import soundtab.ui.noteutil;
import std.string : format;
import std.math : exp, log, exp2, log2, floor;


class SoundCanvas : Widget {

    double _minPitch = 440.0 / 2;
    double _maxPitch = 440.0 * 2;
    double _minNote;
    double _maxNote;

    double _currentPitch = 478;

    @property double minPitch() { return _minPitch; }
    @property double maxPitch() { return _maxPitch; }
    @property double minNote() { return _minNote; }
    @property double maxNote() { return _maxNote; }

    void setPitchRange(double minfreq, double maxfreq) {
        _minPitch = minfreq;
        _maxPitch = maxfreq;
        _minNote = toLogScale(_minPitch);
        _maxNote = toLogScale(_maxPitch);
    }

    void setNoteRange(double minnote, double maxnote) {
        _minNote = minnote;
        _maxNote = maxnote;
        _minPitch = fromLogScale(_minNote);
        _maxPitch = fromLogScale(_maxNote);
    }

    void setPosition(double x, double y, double pressure) {
        _currentPitch = _minPitch + (_maxPitch - _minPitch) * x;
        invalidate();
    }


    this() {
        super("soundCanvas");
        layoutWidth = FILL_PARENT;
        layoutHeight = FILL_PARENT;
        backgroundColor = 0x808080;
        ///*
        double _halfTone = 1.05946309435929530980;
        _halfTone = exp2(log2(2.0) / 12);
        Log.d("halfTone = ", "%1.20f".format(_halfTone));
        double _quarterTone = 1.05946309435929530980;
        _quarterTone = exp2(log2(2.0) / 24);
        Log.d("quarterTone = ", "%1.20f".format(_quarterTone));
        double testOctave = _halfTone * _halfTone * _halfTone * _halfTone * _halfTone * 
            _halfTone * _halfTone * _halfTone * _halfTone * _halfTone * _halfTone * _halfTone;
        Log.d("octave = ", "%1.20f".format(testOctave));

        Log.d("toLogScale(440)=", toLogScale(440));
        Log.d("toLogScale(220)=", toLogScale(220));
        Log.d("toLogScale(880)=", toLogScale(880));
        Log.d("toLogScale(440 + half tone)=", toLogScale(440 * HALF_TONE));
        Log.d("fromLogScale(12)=", fromLogScale(12));
        
        //*/
        setNoteRange(-12, 12);
    }

    /** 
       Measure widget according to desired width and height constraints. (Step 1 of two phase layout). 
    */
    override void measure(int parentWidth, int parentHeight) { 
        measuredContent(parentWidth, parentHeight, parentWidth, parentHeight);
    }

    int getPitchX(Rect clientRect, double note) {
        int w = clientRect.width;
        return clientRect.left + cast(int)((note - _minNote) / (_maxNote - _minNote) * w);
    }

    Rect getNoteRect(Rect clientRect, double note) {
        double nn = floor(note + 0.5);
        double nmin = nn - 0.5;
        double nmax = nn + 0.5;
        int xmin = getPitchX(clientRect, nmin);
        int xmax = getPitchX(clientRect, nmax);
        return Rect(xmin, clientRect.top, xmax, clientRect.bottom);
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
        int pixelsPerNote = cast(int)(rc.width / (_maxNote - _minNote));
        int fsize = pixelsPerNote;
        if (fsize < 8)
            fsize = 8;
        if (fsize > 32)
            fsize = 32;
        FontRef myfont = font;
        FontRef fnt = FontManager.instance.getFont(fsize, 400, false, myfont.family, myfont.face);

        //================================
        for (double n = _minNote; n <= _maxNote; n += 1) {
            Rect noteRect = getNoteRect(rc, n);
            bool black = isBlackNote(n);
            uint cl = black ? 0xB0B0B0 : 0xE0E0E0;
            buf.fillRect(noteRect, cl);
            if (!black) {
                dstring noteName = getNoteName(n);
                Point sz = fnt.textSize(noteName);
                fnt.drawText(buf, noteRect.middlex - sz.x / 2, noteRect.top + fsize/2, noteName, 0xA0A0A0);
                dstring octaveName = getNoteOctaveName(n);
                sz = fnt.textSize(octaveName);
                fnt.drawText(buf, noteRect.middlex - sz.x / 2, noteRect.top + fsize/2 + fsize, octaveName, 0x80A0A0A0);
            }
            noteRect.right = noteRect.left + 1;
            buf.fillRect(noteRect, 0x808080);
        }
        double currentNote = toLogScale(_currentPitch);
        if (currentNote >= _minNote && currentNote <= _maxNote) {
            int x = getPitchX(rc, currentNote);
            buf.fillRect(Rect(x, rc.top, x+1, rc.bottom), 0xFF0000);
        }
    }

}
