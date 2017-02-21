module soundtab.ui.instredit;

import dlangui.platforms.common.platform;
import dlangui.core.logger;
import dlangui.core.i18n;
import dlangui.core.stdaction;
import dlangui.widgets.widget;
import dlangui.widgets.layouts;
import dlangui.widgets.controls;
import dlangui.widgets.toolbars;
import dlangui.widgets.scrollbar;
import dlangui.dialogs.dialog;
import dlangui.dialogs.filedlg;
import soundtab.ui.actions;
import soundtab.audio.audiosource;
import soundtab.audio.loader;
import soundtab.audio.mp3player;

class HRuler : Widget {
    float _startPos = 0;
    float _totalDuration = 0;
    float _visibleDuration = 0;

    this() {
        super("hruler");
        layoutWidth = FILL_PARENT;
        backgroundColor(0x202020);
        textColor(0xC0C0C0);
        fontSize = 10;
    }
    /** 
        Measure widget according to desired width and height constraints. (Step 1 of two phase layout). 
    */
    override void measure(int parentWidth, int parentHeight) {
        int fh = font.height;
        measuredContent(parentWidth, parentHeight, 0, fh + 8);
    }

    void setPosition(float startPos, float totalDuration, float visibleDuration) {
        _startPos = startPos;
        _totalDuration = totalDuration;
        _visibleDuration = visibleDuration;
        invalidate();
    }

    /// Draw widget at its position to buffer
    override void onDraw(DrawBuf buf) {
        import std.format;
        import std.math : round;
        import std.utf : toUTF32;
        if (visibility != Visibility.Visible)
            return;
        super.onDraw(buf);
        _needDraw = false;
        auto saver = ClipRectSaver(buf, _pos, alpha);
        int longDy = _pos.height - font.height - 2;
        int shortDy = longDy * 40 / 100;
        int ytext = _pos.bottom - font.height - 2;
        if (_visibleDuration > 0.00001 && _totalDuration > 0.00001 && _pos.width > 10) {
            double secondsPerPixel = _visibleDuration / _pos.width;
            double scale = 0.00001;
            for (; scale < 10000; scale = scale * 10) {
                if (scale / secondsPerPixel >= 50)
                    break;
            }
            double t = (cast(int)round(_startPos / scale)) * scale - scale;
            for(; t < _startPos + _visibleDuration + scale; t += scale) {
                if (t < 0)
                    continue;
                int x = cast(int)(_pos.left + (t - _startPos) / secondsPerPixel);
                buf.fillRect(Rect(x, _pos.top, x + 1, _pos.top + longDy), 0xB0B0A0);
                for (int xx = 1; xx < 10; xx++) {
                    double tt = t + xx * scale / 10;
                    int xxx = cast(int)(_pos.left + (tt - _startPos) / secondsPerPixel);
                    buf.fillRect(Rect(xxx, _pos.top, xxx + 1, _pos.top + shortDy), 0xB0B0A0);
                }
                int seconds = cast(int)t;
                int minutes = seconds / 60;
                seconds = seconds % 60;
                string txt;
                if (scale >= 1)
                    txt = "%d:%02d".format(minutes,seconds);
                else if (scale >= 0.1) {
                    int frac = cast(int)round(((t - seconds) * 10));
                    txt = "%d:%02d.%01d".format(minutes,seconds,frac);
                } else if (scale >= 0.01) {
                    int frac = cast(int)round(((t - seconds) * 100));
                    txt = "%d:%02d.%02d".format(minutes,seconds,frac);
                } else if (scale >= 0.001) {
                    int frac = cast(int)round(((t - seconds) * 1000));
                    txt = "%d:%02d.%03d".format(minutes,seconds,frac);
                } else {
                    int frac = cast(int)round(((t - seconds) * 10000));
                    txt = "%d:%02d.%04d".format(minutes,seconds,frac);
                }
                dstring dtxt = txt.toUTF32;
                int w = font.textSize(dtxt).x;
                font.drawText(buf, x - w / 2, ytext, dtxt, 0x808080);
            }
        }
    }

}

struct MinMax {
    float minvalue = 0;
    float maxvalue = 0;
    @property float amplitude() {
        float n1 = minvalue < 0 ? -minvalue : minvalue;
        float n2 = maxvalue < 0 ? -maxvalue : maxvalue;
        return n1 > n2 ? n1 : n2;
    }
}

class WaveFileWidget : WidgetGroupDefaultDrawing {
    protected Mixer _mixer;
    protected Mp3Player _player;
    protected WaveFile _file;
    protected ScrollBar _hScroll;
    protected HRuler _hruler;
    protected Rect _clientRect;
    protected int _hscale = 1;
    protected float _vscale = 1;
    protected int _scrollPos = 0;
    protected int _cursorPos = 0;
    protected int _selStart = 0;
    protected int _selEnd = 0;
    protected MinMax[] _zoomCache;
    protected int _zoomCacheScale;
    protected ulong _playTimer;
    this(Mixer mixer) {
        _mixer = mixer;
        _player = new Mp3Player();
        _mixer.addSource(_player);
        _hruler = new HRuler();
        _hScroll = new ScrollBar("wavehscroll", Orientation.Horizontal);
        _hScroll.layoutWidth = FILL_PARENT;
        //styleId = "EDIT_BOX";
        backgroundImageId = "editbox_background_dark";
        addChild(_hruler);
        addChild(_hScroll);
        _hScroll.scrollEvent = &onScrollEvent;
        focusable = true;
        clickable = true;
        padding = Rect(3,3,3,3);
        margins = Rect(2,2,2,2);
        acceleratorMap.add([
            ACTION_VIEW_HZOOM_1, ACTION_VIEW_HZOOM_IN, ACTION_VIEW_HZOOM_OUT, ACTION_VIEW_HZOOM_MAX, ACTION_VIEW_HZOOM_SEL,
            ACTION_VIEW_VZOOM_1, ACTION_VIEW_VZOOM_IN, ACTION_VIEW_VZOOM_OUT, ACTION_VIEW_VZOOM_MAX,
            ACTION_INSTRUMENT_OPEN_SOUND_FILE, ACTION_INSTRUMENT_PLAY_PAUSE, ACTION_INSTRUMENT_PLAY_PAUSE_SELECTION]);
    }
    ~this() {
        if (_mixer) {
            _player.paused = true;
            _mixer.removeSource(_player);
            destroy(_player);
        }
    }
    @property WaveFile file() { return _file; }
    @property void file(WaveFile f) { 
        if (_player) {
            _player.paused = true;
            _player.setWave(f, false);
        }
        _file = f;
        _selStart = _selEnd = 0;
        _cursorPos = 0;
        _scrollPos = 0;
        _zoomCache = null;
        zoomFull();
        if (window)
            window.update();
    }
    @property Mp3Player player() { return _player; }

    /// override to allow extra views
    int getExtraViewsHeight(int parentHeight) { return 0; }
    /// override to allow extra views
    void layoutExtraViews(Rect rc) { }
    /// override to allow extra views
    void drawExtraViews(DrawBuf buf) {}

    void updateZoomCache() {
        if (!_file || _zoomCacheScale == _hscale || _hscale <= 16)
            return;
        int len = (_file.frames + _hscale - 1) / _hscale;
        _zoomCache = new MinMax[len];
        for (int i = 0; i < len; i++) {
            _zoomCache[i] = getDisplayValuesNoCache(i);
        }
        _zoomCacheScale = _hscale;
    }

    void updateView() {
        updateScrollBar();
        invalidate();
    }
    void zoomFull() {
        _scrollPos = 0;
        _hscale = 1;
        _vscale = 1;
        if (_file) {
            _hscale = _file.frames / (_clientRect.width ? _clientRect.width : 1);
            _vscale = visibleYRange().amplitude;
            if (_vscale > 0)
                _vscale = 1 / _vscale;
            else
                _vscale = 1;
        }
        updateView();
        invalidate();
    }
    MinMax visibleYRange() {
        MinMax res;
        for (int i = 0; i < _clientRect.width; i++) {
            MinMax m = getDisplayValues(i);
            if (res.minvalue > m.minvalue)
                res.minvalue = m.minvalue;
            if (res.maxvalue < m.maxvalue)
                res.maxvalue = m.maxvalue;
        }
        return res;
    }
    /// process key event, return true if event is processed.
    override bool onKeyEvent(KeyEvent event) {
        if (event.action == KeyAction.KeyDown) {
            switch(event.keyCode) {
                case KeyCode.HOME:
                    _scrollPos = 0;
                    updateView();
                    return true;
                case KeyCode.END:
                    _scrollPos = _file ? _file.frames / _hscale - _clientRect.width : 0;
                    updateView();
                    return true;
                case KeyCode.RIGHT:
                _scrollPos += _clientRect.width / 5;
                updateView();
                return true;
            case KeyCode.LEFT:
                _scrollPos -= _clientRect.width / 5;
                updateView();
                return true;
            default:
                break;
            }
        }
        if (_hScroll.onKeyEvent(event))
            return true;
        return super.onKeyEvent(event);
    }

    void openSampleFile(string filename) {
        WaveFile f = loadSoundFile(filename);
        if (f) {
            file = f;
        }
    }
    void openSampleFile() {
        import std.file;
        FileDialog dlg = new FileDialog(UIString("Open Sample MP3 file"d), window, null);
        dlg.addFilter(FileFilterEntry(UIString("Sound files (*.mp3;*.wav)"d), "*.mp3;*.wav"));
        dlg.dialogResult = delegate(Dialog dlg, const Action result) {
            if (result.id == ACTION_OPEN.id) {
                string filename = result.stringParam;
                if (filename.exists && filename.isFile) {
                    openSampleFile(filename);
                }
            }
        };
        dlg.show();
    }

    /// override to handle specific actions
    override bool handleAction(const Action a) {
        switch(a.id) {
        case Actions.ViewHZoomIn:
            _hscale = _hscale * 2 / 3;
            updateView();
            return true;
        case Actions.ViewHZoomOut:
            _hscale = _hscale < 3 ? _hscale + 1 : _hscale * 3 / 2;
            updateView();
            return true;
        case Actions.ViewHZoom1:
            _hscale = 1;
            updateView();
            return true;
        case Actions.ViewHZoomMax:
            zoomFull();
            return true;
        case Actions.ViewVZoomMax:
            _vscale = 1;
            updateView();
            return true;
        case Actions.ViewHZoomSel:
            int sellen = _selEnd - _selStart;
            if (sellen > 16) {
                _hscale = (sellen + _clientRect.width - 1) / _clientRect.width;
                if (_hscale < 1)
                    _hscale = 1;
                _scrollPos = _selStart / _hscale;
                updateView();
            }
            return true;
        case Actions.ViewVZoom1:
            _vscale = visibleYRange().amplitude;
            if (_vscale > 0)
                _vscale = 1 / _vscale;
            else
                _vscale = 1;
            updateView();
            return true;
        case Actions.ViewVZoomIn:
            _vscale *= 1.3;
            updateView();
            return true;
        case Actions.ViewVZoomOut:
            _vscale /= 1.3;
            updateView();
            return true;
        case Actions.InstrumentEditorPlayPause:
            // play/pause
            Log.d("play/pause");
            if (_player) {
                if (!_playTimer)
                    _playTimer = setTimer(50);
                if (_player.paused) {
                    if (_cursorPos >= _file.frames - 100)
                        _cursorPos = 0;
                    setPlayPosition();
                    _player.paused = false;
                } else {
                    _player.paused = true;
                    getPlayPosition();
                    _player.removeLoop();
                }
            }
            return true;
        case Actions.InstrumentEditorPlayPauseSelection:
            // play/pause selection
            Log.d("play/pause selection");
            if (_player) {
                if (!_playTimer)
                    _playTimer = setTimer(50);
                if (_player.paused) {
                    if (_selEnd > _selStart || _cursorPos >= _selEnd)
                        _cursorPos = _selStart;
                    setPlayPosition();
                    _player.setLoop(_file.frameToTime(_selStart), _file.frameToTime(_selEnd));
                    _player.paused = false;
                } else {
                    _player.paused = true;
                    getPlayPosition();
                    _player.removeLoop();
                }
            }
            return true;
        case Actions.InstrumentOpenSoundFile:
            openSampleFile();
            return true;
        default:
            break;
        }
        return super.handleAction(a);
    }

    WaveFile getSelectionUpsampled() {
        int sellen = _selEnd - _selStart;
        if (sellen > 16) {
            return _file.upsample4x(_selStart, _selEnd);
        }
        return null;
    }

    void ensureCursorVisible() {
        if (!_file)
            return;
        int p = _cursorPos / _hscale;
        if (p < _scrollPos) {
            _scrollPos = p;
            updateView();
        } else if (p > _scrollPos + _clientRect.width * 9 / 10) {
            _scrollPos = p - _clientRect.width / 10;
            updateView();
        }
    }

    /// player position to screen
    void getPlayPosition() {
        if (!_file)
            return;
        PlayPosition p = _player.position;
        int frame = _file.timeToFrame(p.currentPosition);
        _cursorPos = frame;
        ensureCursorVisible();
        invalidate();
        window.update();
    }

    /// set cursor position to player position
    void setPlayPosition() {
        if (!_file)
            return;
        _player.position = _file.frameToTime(_cursorPos);
    }

    override bool onTimer(ulong id) {
        if (id == _playTimer) {
            if (!_player.paused)
                getPlayPosition();
            return true;
        } else {
            return super.onTimer(id);
        }
    }

    void limitPosition(ref int position) {
        int maxx = _file ? _file.frames - 1 : 0;
        if (position > maxx)
            position = maxx;
        if (position < 0)
            position = 0;
    }
    void updateScrollBar() {
        if (!_clientRect.width)
            return;
        limitPosition(_cursorPos);
        limitPosition(_selStart);
        limitPosition(_selEnd);
        if (_hscale < 1)
            _hscale = 1;
        if (_vscale > 5000.0f)
            _vscale = 5000.0f;
        int maxScale = _file ? (_file.frames / (_clientRect.width ? _clientRect.width : 1)) : 1;
        if (_hscale > maxScale)
            _hscale = maxScale;
        if (_hscale < 1)
            _hscale = 1;
        float amp = visibleYRange.amplitude;
        if (amp < 0.0001)
            amp = 0.0001f;
        float minvscale = 1 / amp * 0.1;
        float maxvscale = 1 / amp * 10;
        if (minvscale > 1)
            minvscale = 1;
        if (_vscale < minvscale)
            _vscale = minvscale;
        if (_vscale > maxvscale)
            _vscale = maxvscale;
        if (!_file) {
            _hScroll.maxValue = 0;
            _hScroll.pageSize = 1;
            _hScroll.position = 0;
            _hruler.setPosition(0, 0, 0);
        } else {
            int w = _clientRect.width;
            int fullw = _file.frames / _hscale;
            int visiblew = w;
            if (visiblew > fullw)
                visiblew = fullw;
            if (_scrollPos + visiblew > fullw)
                _scrollPos = fullw - visiblew;
            if (_scrollPos < 0)
                _scrollPos = 0;
            if (_hScroll.pageSize != visiblew) {
                _hScroll.pageSize = visiblew;
                _hScroll.requestLayout();
            }
            if (_hScroll.maxValue != fullw) {
                _hScroll.maxValue = fullw; //fullw - visiblew;
                _hScroll.requestLayout();
            }
            _hScroll.position = _scrollPos;
            _hruler.setPosition(_file.frameToTime(_scrollPos * _hscale), _file.frameToTime(fullw * _hscale), _file.frameToTime(visiblew * _hscale));
        }
    }

    /// handle scroll event
    bool onScrollEvent(AbstractSlider source, ScrollEvent event) {
        _scrollPos = event.position;
        updateView();
        return true;
    }

    /** 
        Measure widget according to desired width and height constraints. (Step 1 of two phase layout).
    */
    override void measure(int parentWidth, int parentHeight) {
        _hruler.measure(parentWidth, parentHeight);
        int hRulerHeight = _hruler.measuredHeight;
        int extraHeight = getExtraViewsHeight(parentHeight);
        _hScroll.measure(parentWidth, parentHeight);
        int hScrollHeight = _hScroll.measuredHeight;
        measuredContent(parentWidth, parentHeight, 0, 200 + hRulerHeight + hScrollHeight + extraHeight);
    }

    /// Set widget rectangle to specified value and layout widget contents. (Step 2 of two phase layout).
    override void layout(Rect rc) {
        if (visibility == Visibility.Gone) {
            return;
        }
        _pos = rc;
        _needLayout = false;
        Rect m = margins;
        Rect p = padding;
        rc.left += margins.left + padding.left;
        rc.right -= margins.right + padding.right;
        rc.top += margins.top + padding.top;
        rc.bottom -= margins.bottom + padding.bottom;
        int hScrollHeight = _hScroll.measuredHeight;
        Rect hscrollRc = rc;
        hscrollRc.top = hscrollRc.bottom - hScrollHeight;
        _hScroll.layout(hscrollRc);
        int hRulerHeight = _hruler.measuredHeight;
        Rect hrulerRc = rc;
        hrulerRc.bottom = hscrollRc.top;
        hrulerRc.top = hrulerRc.bottom - hRulerHeight;
        _hruler.layout(hrulerRc);
        int extraHeight = getExtraViewsHeight(rc.height);
        if (extraHeight) {
            Rect extraRc = rc;
            extraRc.bottom = hrulerRc.top;
            extraRc.top = extraRc.bottom - extraHeight;
            layoutExtraViews(extraRc);
        }
        _clientRect = rc;
        _clientRect.bottom = hrulerRc.top - 1 - extraHeight;
        _clientRect.top += 1;
        updateView();
    }


    MinMax getDisplayValuesNoCache(int offset) {
        MinMax res;
        if (!_file)
            return res;
        int p0 = cast(int)((offset) * _hscale);
        int p1 = cast(int)((offset + 1) * _hscale);
        for (int i = p0; i < p1; i++) {
            if (i >= 0 && i < _file.frames) {
                float v = _file.data.ptr[i * _file.channels];
                if (i == p0) {
                    res.minvalue = res.maxvalue = v;
                } else {
                    if (res.minvalue > v)
                        res.minvalue = v;
                    if (res.maxvalue < v)
                        res.maxvalue = v;
                }
            }
        }
        return res;
    }

    MinMax getDisplayValues(int offset) {
        offset += _scrollPos;
        if (_hscale > 16) {
            MinMax res;
            updateZoomCache();
            if (offset < 0 || offset >= _zoomCache.length)
                return res;
            return _zoomCache.ptr[offset];
        }
        return getDisplayValuesNoCache(offset);
    }

    bool getDisplayPos(int offset, ref int y0, ref int y1) {
        MinMax v = getDisplayValues(offset);
        int my = _clientRect.middley;
        int dy = _clientRect.height / 2;
        y0 = my - cast(int)((v.maxvalue * _vscale) * dy);
        y1 = my + 1 - cast(int)((v.minvalue * _vscale) * dy);
        if (y0 >= _clientRect.bottom || y1 <= _clientRect.top)
            return false;
        return true;
    }

    void setCursorPos(int x) {
        limitPosition(x);
        if (_cursorPos != x) {
            _cursorPos = x;
            invalidate();
            if (!_player.paused)
                setPlayPosition();
        }
    }

    void updateSelection(int x) {
        limitPosition(x);
        if (_cursorPos < x) {
            _selStart = _cursorPos;
            _selEnd = x;
            invalidate();
        } else {
            _selStart = x;
            _selEnd = _cursorPos;
            invalidate();
        }
    }


    void updateHScale(int newScale, int preserveX) {
        int maxScale = _file ? (_file.frames / (_clientRect.width ? _clientRect.width : 1)) : 1;
        if (newScale > maxScale)
            newScale = maxScale;
        if (newScale < 1)
            newScale = 1;
        int oldxpos = preserveX / _hscale - _scrollPos;
        _hscale = newScale;
        _scrollPos = preserveX / _hscale - oldxpos;
        updateView();
    }

    /// process mouse event; return true if event is processed by widget.
    override bool onMouseEvent(MouseEvent event) {
        if (event.action == MouseAction.ButtonDown && !focused && canFocus)
            setFocus();
        if (_clientRect.isPointInside(event.x, event.y)) {
            int x = (_scrollPos + (event.x - _clientRect.left)) * _hscale;
            if ((event.action == MouseAction.ButtonDown || event.action == MouseAction.Move) && (event.flags & MouseFlag.LButton)) {
                setCursorPos(x);
                return true;
            }
            if ((event.action == MouseAction.ButtonDown || event.action == MouseAction.Move) && (event.flags & MouseFlag.RButton)) {
                updateSelection(x);
                return true;
            }
            if (event.action == MouseAction.Wheel) {
                if (event.flags & MouseFlag.Control) {
                    // vertical zoom
                    handleAction(event.wheelDelta > 0 ? ACTION_VIEW_VZOOM_IN : ACTION_VIEW_VZOOM_OUT);
                } else {
                    // horizontal zoom
                    int newScale = _hscale * 2 / 3;
                    if (event.wheelDelta < 0) {
                        newScale = _hscale < 3 ? _hscale + 1 : _hscale * 3 / 2;
                    }
                    updateHScale(newScale, x);
                }
                return true;
            }
            return false;
        }
        return super.onMouseEvent(event);
    }

    /// Draw widget at its position to buffer
    override void onDraw(DrawBuf buf) {
        if (visibility != Visibility.Visible)
            return;
        super.onDraw(buf);
        _needDraw = false;
        {
            auto saver = ClipRectSaver(buf, _clientRect, alpha);
            // erase background
            buf.fillRect(_clientRect, 0x102010);
            int my = _clientRect.middley;
            int dy = _clientRect.height / 2;
            // draw wave
            if (_file) {
                int cursorx = _cursorPos / _hscale - _scrollPos;
                int selstartx = _selStart / _hscale - _scrollPos;
                int selendx = _selEnd / _hscale - _scrollPos;
                for (int i = 0; i < _clientRect.width; i++) {
                    int x = _clientRect.left + i;
                    int y0, y1;
                    if (getDisplayPos(i, y0, y1)) {
                        buf.fillRect(Rect(x, y0, x + 1, y1), 0x4020C020);
                        if (_hscale <= 10) {
                            int exty0 = y0;
                            int exty1 = y1;
                            int prevy0, prevy1;
                            int nexty0, nexty1;
                            if (getDisplayPos(i - 1, prevy0, prevy1)) {
                                if (prevy0 < exty0)
                                    exty0 = (prevy0 + y0) / 2;
                                if (prevy1 > exty1)
                                    exty1 = (prevy1 + y1) / 2;
                            }
                            if (getDisplayPos(i + 1, nexty0, nexty1)) {
                                if (nexty0 < exty0)
                                    exty0 = (nexty0 + y0) / 2;
                                if (nexty1 > exty1)
                                    exty1 = (nexty1 + y1) / 2;
                            }
                            if (exty0 < y0)
                                buf.fillRect(Rect(x, exty0, x + 1, y0), 0xE040FF40);
                            if (exty1 > y1)
                                buf.fillRect(Rect(x, y1, x + 1, exty1), 0xE040FF40);
                        }
                    }
                    if (x >= selstartx && x <= selendx)
                        buf.fillRect(Rect(x, _clientRect.top, x + 1, _clientRect.bottom), 0xD00000FF);
                    if (x == cursorx)
                        buf.fillRect(Rect(x, _clientRect.top, x + 1, _clientRect.bottom), 0x40FFFFFF);
                }
                if (_file.marks.length) {
                    for (int i = 0; i < _file.marks.length; i++) {
                        int markSample = _file.timeToFrame(_file.marks[i]);
                        int x = (markSample / _hscale) - _scrollPos + _clientRect.left;
                        if (x >= _clientRect.left && x < _clientRect.right) {
                            buf.fillRect(Rect(x, _clientRect.top, x + 1, _clientRect.bottom), 0xA0FF0000);
                        }
                    }
                }
                if (_file.negativeMarks.length) {
                    for (int i = 0; i < _file.negativeMarks.length; i++) {
                        int markSample = _file.timeToFrame(_file.negativeMarks[i]);
                        int x = (markSample / _hscale) - _scrollPos + _clientRect.left;
                        if (x >= _clientRect.left && x < _clientRect.right) {
                            buf.fillRect(Rect(x, _clientRect.top, x + 1, _clientRect.bottom), 0xA00000FF);
                        }
                    }
                }
            }
            // draw y==0
            buf.fillRect(Rect(_clientRect.left, my, _clientRect.right, my + 1), 0x80606030);
        }
        drawExtraViews(buf);
    }

}

class SourceWaveFileWidget : WaveFileWidget {
    this(Mixer mixer) {
        super(mixer);
    }
}

class LoopWaveWidget : WaveFileWidget {
    protected Rect _ampRect;
    protected Rect _freqRect;
    protected Rect _fftRect;
    protected bool _hasAmps;
    protected bool _hasFreqs;
    protected bool _hasFft;
    protected float _minAmp = 0;
    protected float _maxAmp = 0;
    protected float _maxFftAmp = 0;
    protected float _minFreq = 0;
    protected float _maxFreq = 0;
    this(Mixer mixer) {
        super(mixer);
    }
    @property override void file(WaveFile f) { 
        super.file(f);
        if (_file && _file.amplitudes.length == _file.frames) {
            _minAmp = _maxAmp = _file.amplitudes[0];
            foreach(v; _file.amplitudes) {
                if (_minAmp > v)
                    _minAmp = v;
                if (_maxAmp < v)
                    _maxAmp = v;
            }
            _hasAmps = _maxAmp > _minAmp;
        }
        if (_file && _file.frequencies.length == _file.frames) {
            _minFreq = _maxFreq = _file.frequencies[0];
            foreach(v; _file.frequencies) {
                if (_minFreq > v)
                    _minFreq = v;
                if (_maxFreq < v)
                    _maxFreq = v;
            }
            _hasFreqs = _maxFreq > _minFreq;
        }
        if (_file && _file.periods.length > 0) {
            _maxFftAmp = 0;
            foreach (p; _file.periods) {
                foreach(amp; p.fftAmp) {
                    if (_maxFftAmp < amp)
                        _maxFftAmp = amp;
                }
            }
            _hasFft = _maxFftAmp > 0;
        }
    }

    /// override to allow extra views
    override int getExtraViewsHeight(int parentHeight) {
        int h = 0;
        if (_hasAmps) {
            h += 32;
        }
        if (_hasFreqs) {
            h += 32;
        }
        if (_hasFft)
            h += 256;
        return h;
    }
    /// override to allow extra views
    override void layoutExtraViews(Rect rc) {
        _fftRect = rc;
        if (_hasFft) {
            _fftRect.top = rc.bottom - 256;
            rc.bottom = _fftRect.top;
        } else {
            _fftRect.bottom = _fftRect.top;
        }
        _ampRect = rc;
        _freqRect = rc;
        if (_hasAmps && _hasFreqs) {
            _ampRect.bottom = _freqRect.top = rc.middley;
        }
    }

    protected void drawExtraArray(DrawBuf buf, Rect rc, float[] data, float minValue, float maxValue, string title, uint bgColor = 0, uint foreColor = 0x808080) {
        auto saver = ClipRectSaver(buf, rc, alpha);
        // erase background
        buf.fillRect(rc, bgColor);
        buf.fillRect(Rect(rc.left, rc.top, rc.right, rc.top + 1), 0x404040);
        for (int i = 0; i < rc.width; i++) {
            int index = (_scrollPos + i) * _hscale;
            int x = rc.left + i;
            if (index < data.length) {
                float value = data[index];
                int y = cast(int)(rc.bottom - rc.height * (value - minValue) / (maxValue - minValue));
                buf.fillRect(Rect(x, y, x + 1, rc.bottom), foreColor);
            }
        }
        import std.format;
        import std.utf;
        font.drawText(buf, rc.left + 2, rc.top + 2, "%s: min=%f max=%f".format(title, minValue, maxValue).toUTF32, 0xFFFFFF);
    }

    protected void drawFft(DrawBuf buf, ref PeriodInfo period, Rect rc) {
        import std.math : PI, sqrt, log2;
        for (int i = 0; i < 128; i++) {
            float amp = (period.fftAmp[i] / _maxFftAmp); // range is 0..1
            amp = log2(amp + 1); // range is 0..1, but log scaled
            amp = log2(amp + 1); // range is 0..1, but log scaled
            amp = log2(amp + 1); // range is 0..1, but log scaled
            amp = log2(amp + 1); // range is 0..1, but log scaled
            amp = log2(amp + 1); // range is 0..1, but log scaled
            amp = log2(amp + 1); // range is 0..1, but log scaled
            float phase = (period.fftPhase[i] + PI) / (2 * PI);
            uint iamp = cast(int)(amp * 256);
            uint iphase = cast(int)(phase * 256);
            uint ampcolor = (iamp << 16) | (iamp << 8)| (iamp);
            uint phcolor = (iphase << 16) | (iphase << 8)| (iphase);
            buf.fillRect(Rect(rc.left, rc.top + i, rc.right, rc.top + i + 1), ampcolor);
            buf.fillRect(Rect(rc.left, rc.top + i + 128, rc.right, rc.top + i + 1 + 128), phcolor);
        }
    }

    protected void drawLsp(DrawBuf buf, ref PeriodInfo period, Rect rc) {
        import std.math: PI;
        for (int i = 0; i < LPC_SIZE; i++) {
            Rect rect = rc;
            rect.top += i * 10;
            rect.bottom = rect.top + 10;
            float middle = (i + 1.0f) - PI / (LPC_SIZE + 1);
            float amp = middle / (period.lsp[i] / PI); // range is 0..1
            if (amp < 0)
                amp = -amp;
            uint iamp = cast(int)(amp * 50);
            uint ampcolor = (iamp << 16) | (iamp << 8)| (iamp);
            buf.fillRect(rect, ampcolor);
        }
    }

    /// override to allow extra views
    override void drawExtraViews(DrawBuf buf) {
        if (_hasAmps) {
            drawExtraArray(buf, _ampRect, _file.amplitudes, _minAmp, _maxAmp, "Amplitude", 0x202000, 0x604000);
        }
        if (_hasFreqs) {
            drawExtraArray(buf, _freqRect, _file.frequencies, _minFreq, _maxFreq, "Frequency", 0x002000, 0x0000C0);
        }
        if (_hasFft) {
            auto saver = ClipRectSaver(buf, _fftRect, alpha);
            buf.fillRect(_fftRect, 0x100000);
            foreach(period; _file.periods) {
                int startFrame = _file.timeToFrame(period.startTime);
                int endFrame = _file.timeToFrame(period.endTime);
                int startx = startFrame / _hscale - _scrollPos + _fftRect.left;
                int endx = endFrame / _hscale - _scrollPos + _fftRect.left;
                if (startx < _fftRect.right && endx > _fftRect.left) {
                    // frame is visible
                    drawLsp(buf, period, Rect(startx, _fftRect.top, endx, _fftRect.bottom));
                    //drawFft(buf, period, Rect(startx, _fftRect.top, endx, _fftRect.bottom));
                }
            }
        }
    }

}

class InstrEditorBody : VerticalLayout {
    SourceWaveFileWidget _wave;
    LoopWaveWidget _loop;
    protected Mixer _mixer;
    this(Mixer mixer) {
        super("instrEditBody");
        _mixer = mixer;
        layoutWidth = FILL_PARENT;
        layoutHeight = FILL_PARENT;
        backgroundColor(0x000000);
        _wave = new SourceWaveFileWidget(_mixer);
        addChild(_wave);
        _loop = new LoopWaveWidget(_mixer);
        addChild(_loop);
        addChild(new VSpacer());
    }

    ~this() {
    }

    /// override to handle specific actions
    override bool handleAction(const Action a) {
        switch(a.id) {
            case Actions.InstrumentCreateLoop:
                WaveFile tmp = _wave.getSelectionUpsampled();
                if (tmp) {
                    float baseFrequency = tmp.calcBaseFrequency();
                    int lowpassFilterSize = tmp.timeToFrame((1/baseFrequency) / 16) | 1;
                    int highpassFilterSize = tmp.timeToFrame((1/baseFrequency) * 1.5) | 1;
                    float[] lowpassFirFilter = blackmanWindow(lowpassFilterSize);
                    float[] highpassFirFilter = blackmanWindow(highpassFilterSize); //makeLowpassBlackmanFirFilter(highpassFilterSize);
                    WaveFile lowpass = tmp.firFilter(lowpassFirFilter);
                    WaveFile highpass = lowpass.firFilterInverse(highpassFirFilter);
                    int lowpassSign = lowpass.getMaxAmplitudeSign();
                    //float[] zeroPhasePositionsLowpass = lowpass.findZeroPhasePositions(lowpassSign);
                    int highpassSign = highpass.getMaxAmplitudeSign();
                    float[] zeroCrossHighpass = highpass.findZeroCrossingPositions(highpassSign);
                    
                    //float[] zeroPhasePositionsHighpassPositive = highpass.findZeroPhasePositions(1);
                    //float[] zeroPhasePositionsHighpassNegative = highpass.findZeroPhasePositions(-1);
                    //smoothTimeMarksShifted(zeroPhasePositionsHighpassPositive, zeroPhasePositionsHighpassNegative);
                    //smoothTimeMarksShifted(zeroPhasePositionsHighpassPositive, zeroPhasePositionsHighpassNegative);
                    //smoothTimeMarksShifted(zeroPhasePositionsHighpassPositive, zeroPhasePositionsHighpassNegative);
                    //smoothTimeMarks(zeroPhasePositionsHighpassPositive);
                    //smoothTimeMarks(zeroPhasePositionsHighpassPositive);
                    //smoothTimeMarks(zeroPhasePositionsHighpassNegative);
                    //smoothTimeMarks(zeroPhasePositionsHighpassNegative);

                    int normalSign = tmp.getMaxAmplitudeSign();
                    //float[] zeroPhasePositionsNormal = tmp.findZeroPhasePositions(normalSign);
                    //Log.d("Zero phase positions for lowpass filtered data: ", zeroPhasePositionsLowpass);
                    //Log.d("Zero phase positions for lowpass+highpass filtered data: ", zeroPhasePositionsHighpassPositive);
                    //Log.d("Zero phase positions for non filtered data: ", zeroPhasePositionsNormal);
                    //tmp.setMarks(zeroPhasePositionsHighpassPositive, zeroPhasePositionsHighpassNegative);
                    //lowpass.setMarks(zeroPhasePositionsHighpassPositive, zeroPhasePositionsHighpassNegative);
                    //highpass.setMarks(zeroPhasePositionsHighpassPositive, zeroPhasePositionsHighpassNegative);
                    for (int i = 0; i < 10; i++)
                        smoothTimeMarks(zeroCrossHighpass);
                    highpass.setMarks(zeroCrossHighpass);
                    highpass.fillPeriodsFromMarks();
                    highpass.fillAmplitudesFromPeriods();
                    highpass.normalizeAmplitude();
                    //highpass.correctMarksForNormalizedAmplitude();
                    //highpass.smoothMarks();
                    //highpass.smoothMarks();
                    highpass.generateFrequenciesFromMarks();
                    tmp.marks = highpass.marks;
                    tmp.negativeMarks = highpass.negativeMarks;
                    tmp.frequencies = highpass.frequencies;
                    tmp.amplitudes = highpass.amplitudes;
                    tmp.normalizeAmplitude;
                    tmp.fillPeriodsFromMarks();
                    //if (zeroPhasePositionsNormal.length > 1) {
                    //    tmp.removeDcOffset(zeroPhasePositionsHighpass[0], zeroPhasePositionsHighpass[$-1]);
                    //    tmp.generateFrequenciesFromMarks();
                    //}
                    //_loop.file = lowpass;
                    //_loop.file = highpass;
                    _loop.file = tmp;
                }
                return true;
            default:
                break;
        }
        return super.handleAction(a);
    }

    /// map key to action
    override Action findKeyAction(uint keyCode, uint flags) {
        Action action = _wave.findKeyAction(keyCode, flags);
        if (action)
            return action;
        return super.findKeyAction(keyCode, flags);
    }
}

class InstrumentEditorDialog : Dialog {
    protected ToolBarHost _toolbarHost;
    protected InstrEditorBody _body;
    protected Mixer _mixer;

    this(Window parentWindow, Mixer mixer, int initialWidth = 0, int initialHeight = 0) {
        _mixer = mixer;
        super(UIString("Instrument Editor"d), parentWindow, DialogFlag.Modal | DialogFlag.Resizable, initialWidth, initialHeight);
    }

    ToolBarHost createToolbars() {
        ToolBarHost tbhost = new ToolBarHost();
        ToolBar tb = tbhost.getOrAddToolbar("toolbar1");
        tb.addButtons(ACTION_INSTRUMENT_OPEN_SOUND_FILE,
                      ACTION_SEPARATOR,
                      ACTION_INSTRUMENT_PLAY_PAUSE, ACTION_INSTRUMENT_PLAY_PAUSE_SELECTION, 
                      ACTION_SEPARATOR,
                      ACTION_INSTRUMENT_CREATE_LOOP,
                      ACTION_SEPARATOR,
                      ACTION_VIEW_HZOOM_1, ACTION_VIEW_HZOOM_IN, ACTION_VIEW_HZOOM_OUT, ACTION_VIEW_HZOOM_MAX, ACTION_VIEW_HZOOM_SEL,
                      ACTION_SEPARATOR,
                      ACTION_VIEW_VZOOM_1, ACTION_VIEW_VZOOM_IN, ACTION_VIEW_VZOOM_OUT, ACTION_VIEW_VZOOM_MAX
                      );
        acceleratorMap.add([ACTION_INSTRUMENT_OPEN_SOUND_FILE,
                           ACTION_INSTRUMENT_PLAY_PAUSE, ACTION_INSTRUMENT_PLAY_PAUSE_SELECTION, ACTION_INSTRUMENT_CREATE_LOOP,
                           ACTION_VIEW_HZOOM_1, ACTION_VIEW_HZOOM_IN, ACTION_VIEW_HZOOM_OUT, ACTION_VIEW_HZOOM_MAX, ACTION_VIEW_HZOOM_SEL,
                           ACTION_VIEW_VZOOM_1, ACTION_VIEW_VZOOM_IN, ACTION_VIEW_VZOOM_OUT, ACTION_VIEW_VZOOM_MAX]);

        return tbhost;
    }

    InstrEditorBody createBody() {
        InstrEditorBody res = new InstrEditorBody(_mixer);
        return res;
    }

    /// map key to action
    override Action findKeyAction(uint keyCode, uint flags) {
        Action action = _toolbarHost.findKeyAction(keyCode, flags);
        if (action)
            return action;
        action = _body.findKeyAction(keyCode, flags);
        if (action)
            return action;
        return super.findKeyAction(keyCode, flags);
    }
    /// override to implement creation of dialog controls
    override void initialize() {
        Log.d("InstrumentEditorDialog.initialize");
        _toolbarHost = createToolbars();
        _body = createBody();
        addChild(_toolbarHost);
        addChild(_body);
    }

}
