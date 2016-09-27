module soundtab.ui.noteutil;

import std.string : format;
import std.math : exp, log, exp2, log2, floor;

immutable double HALF_TONE = 1.05946309435929530980;
immutable double QUARTER_TONE = 1.02930223664349207440;

immutable double BASE_FREQUENCY = 440.0;

/// Convert frequency to log scale, 0 = BASE_FREQUENCY (440hz), 1 = + half tone, 12 = + octave (880Hz), -12 = -octave (220hz)
double toLogScale(double freq) {
    if (freq < 8)
        return -6 * 12;
    return log2(freq / BASE_FREQUENCY) * 12;
}

/// Convert from note (log scale) to frequency (0 -> 440, 12 -> 880, -12 -> 220)
double fromLogScale(double note) {
    return exp2(note / 12) * BASE_FREQUENCY;
}

/// returns index 0..11 of nearest note (0=A, 1=A#, 2=B, .. 11=G#)
int getNoteIndex(double note) {
    int nn = getNearestNote(note);
    while (nn < 0)
        nn += 12;
    nn %= 12;
    return nn;
}

/// returns nearest int note
int getNearestNote(double note) {
    return cast(int)floor(note + 0.5);
}

int getNoteOctave(double note) {
    int n = getNearestNote(note);
    return ((n - 3) + 12*5) / 12;
}

immutable dstring[9] OCTAVE_NAMES = [
    "0", "1", "2",  "3",  "4", "5",  "6", "7",  "8"
];

dstring getNoteOctaveName(double note) {
    int oct = getNoteOctave(note);
    if (oct < 0 || oct > 8)
        return " ";
    return OCTAVE_NAMES[oct];
}


// 0  1  2  3  4  5  6  7  8  9  10 11
// A  A# B  C  C# D  D# E  F  F# G  G#
immutable static bool[12] BLACK_NOTES = [
    false, // A
    true,  // A#
    false, // B
    false, // C
    true,  // C#
    false, // D
    true,  // D#
    false, // E
    false, // F
    true,  // F#
    false, // G
    true,  // G#
];

/// returns true for "black" - sharp note, e.g. for A#, G#
bool isBlackNote(double note) {
    int nn = getNoteIndex(note);
    return BLACK_NOTES[nn];
}

immutable dstring[12] NOTE_NAMES = [
    "A", "A#", "B",  "C",  "C#", "D",  "D#", "E",  "F",  "F#", "G", "G#"
];

dstring getNoteName(double n) {
    return NOTE_NAMES[getNoteIndex(n)];
}

dstring getNoteFullName(double n) {
    return getNoteName(n) ~ getNoteOctaveName(n);
}
