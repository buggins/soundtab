module soundtab.ui.instredit;

import dlangui.platforms.common.platform;
import dlangui.dialogs.dialog;
import dlangui.core.logger;
import dlangui.core.i18n;
import dlangui.widgets.widget;
import dlangui.widgets.toolbars;
import soundtab.ui.actions;

class InstrumentEditorDialog : Dialog {
    protected ToolBarHost _toolbarHost;
    protected Widget _body;
    this(UIString caption, Window parentWindow = null, uint flags = DialogFlag.Modal | DialogFlag.Resizable, int initialWidth = 0, int initialHeight = 0) {
        super(caption, parentWindow, flags, initialWidth, initialHeight);
    }

    ToolBarHost createToolbars() {
        ToolBarHost tbhost = new ToolBarHost();
        ToolBar tb = tbhost.getOrAddToolbar("toolbar1");
        tb.addButtons(ACTION_INSTRUMENT_OPEN_SOUND_FILE);
        return tbhost;
    }

    Widget createBody() {
        Widget res = new Widget();
        res.layoutWidth = FILL_PARENT;
        res.layoutHeight = FILL_PARENT;
        res.backgroundColor(0x102010);
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
