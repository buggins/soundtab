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
}

class WaveFileWidget : WidgetGroupDefaultDrawing {
    protected WaveFile _file;
    protected ScrollBar _hScroll;
    protected HRuler _hruler;
    protected Rect _clientRect;
    protected int _hscale = 1;
    protected float _vscale = 1;
    protected int _scrollPos = 0;
    this() {
        _hruler = new HRuler();
        _hScroll = new ScrollBar("wavehscroll", Orientation.Horizontal);
        _hScroll.layoutWidth = FILL_PARENT;
        addChild(_hruler);
        addChild(_hScroll);
        _hScroll.scrollEvent = &onScrollEvent;
        focusable = true;
    }
    @property WaveFile file() { return _file; }
    @property void file(WaveFile f) { 
        _file = f;
        //zoomFull();
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
        default:
            break;
        }
        return super.handleAction(a);
    }
    void updateScrollBar() {
        if (_hscale < 1)
            _hscale = 1;
        int maxScale = _file ? (_file.frames / (_clientRect.width ? _clientRect.width : 1)) : 1;
        if (_hscale > maxScale)
            _hscale = maxScale;
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
            _hScroll.maxValue = fullw; //fullw - visiblew;
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


    MinMax getDisplayValues(int offset) {
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

    /// Draw widget at its position to buffer
    override void onDraw(DrawBuf buf) {
        if (visibility != Visibility.Visible)
            return;
        super.onDraw(buf);
        Rect rc = _pos;
        applyMargins(rc);
        auto saver = ClipRectSaver(buf, rc, alpha);
        DrawableRef bg = backgroundDrawable;
        if (!bg.isNull) {
            bg.drawTo(buf, rc, state);
        }
        applyPadding(rc);
        _needDraw = false;
        // erase background
        buf.fillRect(_clientRect, 0x102010);
        int my = _clientRect.middley;
        int dy = _clientRect.height / 2;
        // draw wave
        if (_file) {
            for (int i = 0; i < _clientRect.width; i++) {
                int x = _clientRect.left + i;
                int y0, y1;
                if (getDisplayPos(i, y0, y1)) {
                    buf.fillRect(Rect(x, y0, x + 1, y1), 0x40FF40);
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
        tb.addButtons(ACTION_INSTRUMENT_OPEN_SOUND_FILE, ACTION_VIEW_HZOOM_1, ACTION_VIEW_HZOOM_IN, ACTION_VIEW_HZOOM_OUT, ACTION_VIEW_HZOOM_MAX);
        return tbhost;
    }

    InstrEditorBody createBody() {
        InstrEditorBody res = new InstrEditorBody();
        return res;
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
