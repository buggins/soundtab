module soundtab.ui.actions;

import dlangui.core.events;

enum Actions : int {
    FileExit = 1030000,
    FileOptions,
    FileOpenAccompaniment,
    FilePlayPauseAccompaniment,
    InstrumentEditor,
    InstrumentOpenSoundFile,
    ViewHZoomIn,
    ViewHZoomOut,
    ViewHZoom1,
    ViewHZoomMax,
}

const Action ACTION_FILE_OPTIONS = new Action(Actions.FileOptions, "Options..."d);
const Action ACTION_FILE_EXIT = new Action(Actions.FileExit, "Exit"d);
const Action ACTION_FILE_OPEN_ACCOMPANIMENT = new Action(Actions.FileOpenAccompaniment, "Open .mp3"d, null, KeyCode.F3, 0);
const Action ACTION_FILE_PLAY_PAUSE_ACCOMPANIMENT = new Action(Actions.FilePlayPauseAccompaniment, "Play/Pause"d, null, KeyCode.F5, 0);
const Action ACTION_INSTRUMENT_EDITOR = new Action(Actions.InstrumentEditor, "Instrument editor"d, null, KeyCode.F4, 0);
const Action ACTION_INSTRUMENT_OPEN_SOUND_FILE = new Action(Actions.InstrumentOpenSoundFile, "Open sound file"d, "document-open", KeyCode.F3, 0);
const Action ACTION_VIEW_HZOOM_IN = new Action(Actions.ViewHZoomIn, "H Zoom In"d, "hzoomin", KeyCode.ADD, 0);
const Action ACTION_VIEW_HZOOM_OUT = new Action(Actions.ViewHZoomOut, "H Zoom Out"d, "hzoomout", KeyCode.SUB, 0);
const Action ACTION_VIEW_HZOOM_1 = new Action(Actions.ViewHZoom1, "H Zoom 1:1"d, "hzoom1", KeyCode.ADD, KeyFlag.Control);
const Action ACTION_VIEW_HZOOM_MAX = new Action(Actions.ViewHZoomMax, "H Zoom Max"d, "hzoommax", KeyCode.SUB, KeyFlag.Control);
