module soundtab.ui.actions;

import dlangui.core.events;

enum Actions : int {
    FileExit = 1030000,
    FileOptions,
    FileOpenAccompaniment,
    FilePlayPauseAccompaniment,
}

const Action ACTION_FILE_OPTIONS = new Action(Actions.FileOptions, "Options..."d);
const Action ACTION_FILE_EXIT = new Action(Actions.FileExit, "Exit"d);
const Action ACTION_FILE_OPEN_ACCOMPANIMENT = new Action(Actions.FileOpenAccompaniment, "Open .mp3"d);
const Action ACTION_FILE_PLAY_PAUSE_ACCOMPANIMENT = new Action(Actions.FilePlayPauseAccompaniment, "Play"d);
