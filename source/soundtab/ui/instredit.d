module soundtab.ui.instredit;

import dlangui.platforms.common.platform;
import dlangui.dialogs.dialog;
import dlangui.core.logger;
import dlangui.core.i18n;
import dlangui.widgets.widget;
import dlangui.widgets.layouts;
import dlangui.widgets.controls;
import dlangui.widgets.toolbars;
import dlangui.widgets.scrollbar;
import soundtab.ui.actions;
import soundtab.audio.loader;

class HRuler : Widget {
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
    this() {
        _hruler = new HRuler();
        _hScroll = new ScrollBar("wavehscroll", Orientation.Horizontal);
        _hScroll.layoutWidth = FILL_PARENT;
        addChild(_hruler);
        addChild(_hScroll);
        _hScroll.scrollEvent = &onScrollEvent;
        focusable = true;
        clickable = true;
        acceleratorMap.add([
            ACTION_VIEW_HZOOM_1, ACTION_VIEW_HZOOM_IN, ACTION_VIEW_HZOOM_OUT, ACTION_VIEW_HZOOM_MAX, ACTION_VIEW_HZOOM_SEL,
            ACTION_VIEW_VZOOM_1, ACTION_VIEW_VZOOM_IN, ACTION_VIEW_VZOOM_OUT, ACTION_VIEW_VZOOM_MAX]);
    }
    @property WaveFile file() { return _file; }
    @property void file(WaveFile f) { 
        _file = f;
        zoomFull();
    }

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
        }
        updateView();
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
        default:
            break;
        }
        return super.handleAction(a);
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
        _hScroll.measure(parentWidth, parentHeight);
        int hScrollHeight = _hScroll.measuredHeight;
        measuredContent(parentWidth, parentHeight, 0, 200 + hRulerHeight + hScrollHeight);
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
        _clientRect = rc;
        _clientRect.bottom = hrulerRc.top - 1;
        _clientRect.top += 1;
        updateView();
    }


    MinMax getDisplayValuesNoCache(int offset) {
        MinMax res;
        if (!_file)
            return res;
        int p0 = cast(int)((_scrollPos + offset) * _hscale);
        int p1 = cast(int)((_scrollPos + offset + 1) * _hscale);
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
                            buf.fillRect(Rect(x, exty0, x + 1, y0), 0xA040FF40);
                        if (exty1 > y1)
                            buf.fillRect(Rect(x, y1, x + 1, exty1), 0xA040FF40);
                    }
                }
                if (x >= selstartx && x <= selendx)
                    buf.fillRect(Rect(x, _clientRect.top, x + 1, _clientRect.bottom), 0xE8FFFF00);
                if (x == cursorx)
                    buf.fillRect(Rect(x, _clientRect.top, x + 1, _clientRect.bottom), 0x40FFFFFF);
            }
        }
        // draw y==0
        buf.fillRect(Rect(_clientRect.left, my, _clientRect.right, my + 1), 0x80606030);
    }

}

class InstrEditorBody : VerticalLayout {
    WaveFileWidget _wave;
    this() {
        super("instrEditBody");
        layoutWidth = FILL_PARENT;
        layoutHeight = FILL_PARENT;
        backgroundColor(0x102010);
        _wave = new WaveFileWidget();
        WaveFile wav = loadSoundFile("jmj-chronologie3.mp3", true);
        _wave.file = wav;
        addChild(_wave);
        addChild(new VSpacer());
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
    this(UIString caption, Window parentWindow = null, uint flags = DialogFlag.Modal | DialogFlag.Resizable, int initialWidth = 0, int initialHeight = 0) {
        super(caption, parentWindow, flags, initialWidth, initialHeight);
    }

    ToolBarHost createToolbars() {
        ToolBarHost tbhost = new ToolBarHost();
        ToolBar tb = tbhost.getOrAddToolbar("toolbar1");
        tb.addButtons(ACTION_INSTRUMENT_OPEN_SOUND_FILE,
                      ACTION_VIEW_HZOOM_1, ACTION_VIEW_HZOOM_IN, ACTION_VIEW_HZOOM_OUT, ACTION_VIEW_HZOOM_MAX, ACTION_VIEW_HZOOM_SEL,
                      ACTION_VIEW_VZOOM_1, ACTION_VIEW_VZOOM_IN, ACTION_VIEW_VZOOM_OUT, ACTION_VIEW_VZOOM_MAX
                      );
        return tbhost;
    }

    InstrEditorBody createBody() {
        InstrEditorBody res = new InstrEditorBody();
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