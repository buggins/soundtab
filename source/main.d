module app;

import dlangui;

mixin APP_ENTRY_POINT;


import core.sys.windows.windows;

import soundtab.ui.frame;

//version = TestMidi;
version(TestMidi) {
    import wasapi.midi;

    void testMidi() {
        import core.thread;
        MidiProvider midi = new MidiProvider();
        Log.d("Testing MIDI interface");
        Log.d("MIDI Input devices:", midi.inputDevCount, " output devices:", midi.outDevCount);
        MidiOutDeviceDesc desc = midi.getOutputDevice();
        MidiOutDevice midiout = desc.open;
        if (!midiout) {
            Log.e("Cannot open midi out device");
            return;
        }
        midiout.sendEvent(0xC0, 1); // program change
        midiout.sendEvent(0x90, 0x39, 0x4F); // note on A3
        Thread.sleep(1500.dur!"msecs");
        midiout.sendEvent(0x99, 38, 0x7F); // snare drum
        midiout.sendEvent(0x80, 0x39, 0x7F); // note off A3
        midiout.sendEvent(0x90, 0x3B, 0x4F); // note on A3
        Thread.sleep(1500.dur!"msecs");
        midiout.sendEvent(0x80, 0x3B, 0x7F); // note off A3
        Thread.sleep(500.dur!"msecs");
        midiout.sendEvent(0x89, 38, 0x7F); // off
        midiout.close();
    }

}

//version = DumpPulse;


version(DumpPulse)
void convertRaw(string filename) {
    import std.file;
    import std.conv : to;
    short[] data = cast(short[])read(filename);
    char[] buf;
    char[] buf2;
    buf ~= "    ";
    for (int i = 0; i < data.length; i++) {
        buf ~= to!string((cast(int)data[i]));
        buf2 ~= to!string((cast(int)data[i]));
        buf ~= ", ";
        if (i % 16 == 15)
            buf ~= "\n    ";
        buf2 ~= "\n";
    }
    buf ~= "\n";
    write(filename ~ ".d", buf);
    write(filename ~ ".csv", buf2);
}

/// entry point for dlangui based application
extern (C) int UIAppMain(string[] args) {

    auto hr = CoInitialize(null);
    if (hr)
        Log.e("CoInitialize failed");

    //initAudio();
    version(DumpPulse) {
        convertRaw("impuls20.raw");
    }

    version(TestMidi) {
        import wasapi.midi;
        testMidi();
    }

    /*
    import soundtab.audio.loader;
    WaveFile wav = loadSoundFile("jmj-chronologie3.mp3", true);
    if (!wav)
        Log.d("Sound file loaded ok");
    else
        Log.d("Error loading sound file");
    */
    // embed resources listed in views/resources.list into executable
    embeddedResourceList.addResources(embedResourcesFromList!("resources.list")());

    Platform.instance.uiTheme = "theme_dark";
    // create window
    Log.d("Creating window");
    import dlangui.platforms.windows.winapp;
    Win32Window window = cast(Win32Window)Platform.instance.createWindow("SoundTab - Wacom Tablet Theremin", null, WindowFlag.Resizable, 800, 600);
    Log.d("Window created");
    import soundtab.ui.noteutil;
    buildNoteConversionTable();


    // create some widget to show in window
    //window.mainWidget = (new Button()).text("Hello, world!"d).margins(Rect(20,20,20,20));
    new SoundFrame(window);

    window.windowIcon = drawableCache.getImage("dlangui-logo1");

    // show window
    window.show();

    // run message loop
    return Platform.instance.enterMessageLoop();
}
