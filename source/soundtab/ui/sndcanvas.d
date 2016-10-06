module soundtab.ui.sndcanvas;

import dlangui.widgets.widget;
import soundtab.ui.noteutil;
import soundtab.ui.synthwidget;
import std.string : format;
import std.math : exp, log, exp2, log2, floor;
import dlangui.core.events;

class SoundCanvas : Widget {

    double _minPitch = 440.0 / 8;
    double _maxPitch = 440.0 * 8;
    double _minNote;
    double _maxNote;

    double _currentPitch = 478;
    double _currentY = 0.5;

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

    @property double pitch() { return _currentPitch; }
    @property double controller1() { return _currentY; }
    void setPosition(double x, double y, double pressure) {
        double note = _minNote + (_maxNote - _minNote) * x;
        _currentPitch = fromLogScale(note);
        _currentY = y;
        invalidate();
    }


    SynthWidget _synth;
    this(SynthWidget synth) {
        super("soundCanvas");
        _synth = synth;
        layoutWidth = FILL_PARENT;
        layoutHeight = FILL_PARENT;
        backgroundColor = 0xFFFFFF;
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
        
        Log.d("noteNameToNote(A4)=", fullNameToNote("A4"));
        Log.d("noteNameToNote(C5)=", fullNameToNote("C5"));

        import std.math : round;
        for (int i = -25; i < 25; i++) {
            Log.d("note=", i, " name=", noteToFullName(i), " fullNameToNote=", fullNameToNote(noteToFullName(i)), " freq=", fromLogScale(i), " noteIndex=", round(toLogScale(fromLogScale(i))));
        }

        //*/
        setNoteRange(-36, 36);
        trackHover = true;
        clickable = true;

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
            //noteRect.left ++;
            bool black = isBlackNote(n);
            uint cl = black ? 0xC0C0C0 : 0xE0E0E0;
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
            buf.fillRect(noteRect, black ? 0xD0D0D0 : 0xD0D0D0);
        }
        double currentNote = toLogScale(_currentPitch);
        if (currentNote >= _minNote && currentNote <= _maxNote) {
            int x = getPitchX(rc, currentNote);
            int y = cast(int)(rc.top + (rc.height * _currentY));
            buf.fillRect(Rect(x, rc.top, x+1, rc.bottom), 0xFF0000);
            buf.fillRect(Rect(x - pixelsPerNote / 2, y, x + pixelsPerNote / 2, y + 1), 0xFF0000);
        }
    }

    bool _lastProximity = false;
    override bool onMouseEvent(MouseEvent event) {
        if (_synth.tabletInitialized)
            return false;
        if (event.action == MouseAction.ButtonDown || event.action == MouseAction.ButtonUp || event.action == MouseAction.Move) {
            double x = (event.x - _pos.left) / cast(double)_pos.width;
            double y = (event.y - _pos.top) / cast(double)_pos.height;
            double pressure = (event.buttonFlags & MouseFlag.LButton) ? 0.5 : 0;
            uint buttons = 0;
            if (event.buttonFlags & MouseFlag.LButton)
                buttons |= 1;
            if (event.buttonFlags & MouseFlag.RButton)
                buttons |= 2;
            if (!_lastProximity) {
                _synth.onProximity(true);
                _lastProximity = false;
            }
            _synth.onPositionChange(x, y, pressure, buttons);
        } else if (event.action == MouseAction.Cancel || event.action == MouseAction.Leave || event.action == MouseAction.FocusOut) {
            if (_lastProximity) {
                _synth.onProximity(false);
                _lastProximity = false;
            }
        }
        return super.onMouseEvent(event);
    }
    
}
