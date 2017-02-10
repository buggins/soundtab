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

class WaveFileWidget : WidgetGroupDefaultDrawing {
    protected WaveFile _file;
    protected ScrollBar _hScroll;
    protected HRuler _hruler;
    protected Rect _clientRect;
    this() {
        _hruler = new HRuler();
        _hScroll = new ScrollBar("wavehscroll", Orientation.Horizontal);
        _hScroll.layoutWidth = FILL_PARENT;
        addChild(_hruler);
        addChild(_hScroll);
    }
    @property WaveFile file() { return _file; }
    @property void file(WaveFile f) { _file = f; invalidate(); }
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
        hrulerRc.top = hrulerRc.bottom - hrulerRc.bottom;
        _hruler.layout(hrulerRc);
        _clientRect = rc;
        _clientRect.bottom = hrulerRc.top - 1;
        _clientRect.top += 1;
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

        buf.fillRect(_clientRect, 0x206020);
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
        tb.addButtons(ACTION_INSTRUMENT_OPEN_SOUND_FILE);
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
