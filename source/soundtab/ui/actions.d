module soundtab.ui.actions;

import dlangui.core.events;

enum Actions : int {
    FileExit = 1030000,
    FileOptions,
}

const Action ACTION_FILE_OPTIONS = new Action(Actions.FileOptions, "Options..."d);
const Action ACTION_FILE_EXIT = new Action(Actions.FileExit, "Exit"d);
