module soundtab.audio.generators;

import std.math : log2, exp2, sin, cos, pow, PI;

immutable WAVETABLE_SIZE_BITS = 14;
immutable WAVETABLE_SIZE = 1 << WAVETABLE_SIZE_BITS;
immutable WAVETABLE_SIZE_MASK = WAVETABLE_SIZE - 1;
immutable WAVETABLE_SIZE_MASK_MUL_256 = (1 << (WAVETABLE_SIZE_BITS + 8)) - 1;
immutable WAVETABLE_SCALE_BITS = 14;
immutable WAVETABLE_SCALE = (1 << WAVETABLE_SCALE_BITS);


int[] genWaveTableSin() {
    int[] res;
    res.length = WAVETABLE_SIZE;
    for (int i = 0; i < WAVETABLE_SIZE; i++) {
        double f = i * 2 * PI / WAVETABLE_SIZE;
        double v = sin(f);
        res[i] = cast(int)(v * WAVETABLE_SCALE);
    }
    return res;
}

float[] genWaveTableSinF() {
    float[] res;
    res.length = WAVETABLE_SIZE;
    for (int i = 0; i < WAVETABLE_SIZE; i++) {
        double f = i * 2 * PI / WAVETABLE_SIZE;
        double v = sin(f);
        res[i] = cast(float)v;
    }
    return res;
}

// (cos^2 + 1)/2 half period
float[] genWaveTableCosSquaredF() {
    float[] res;
    res.length = WAVETABLE_SIZE + 1;
    for (int i = 0; i <= WAVETABLE_SIZE; i++) {
        double f = i * PI / WAVETABLE_SIZE;
        double v = (cos(f) + 1) / 2;
        v = v * v;
        res[i] = cast(float)v;
    }
    return res;
}

int[] genWaveTableSquare() {
    int[] res;
    res.length = WAVETABLE_SIZE;
    for (int i = 0; i < WAVETABLE_SIZE; i++) {
        if (i < WAVETABLE_SIZE / 2)
            res[i] = WAVETABLE_SCALE;
        else
            res[i] = -WAVETABLE_SCALE;
    }
    return res;
}

float[] genWaveTableSquareF() {
    float[] res;
    res.length = WAVETABLE_SIZE;
    for (int i = 0; i < WAVETABLE_SIZE; i++) {
        if (i < WAVETABLE_SIZE / 2)
            res[i] = 1.0f;
        else
            res[i] = -1.0f;
    }
    return res;
}

// Based on code from STK library - https://github.com/thestk/stk
// impuls_20 waveform
immutable short[] VOICE_IMPULSE = [
    -385, -30598, -2710, -28077, -16329, 24091, 7938, -2834, -28189, 17376, -1053, -24596, -32265, -4351, -19447, 30477, 
    -7412, -24824, 3586, -3846, -2572, 25585, -10512, 11507, -25609, -4100, -11263, 11269, 18694, 3333, -5375, -16131, 
    -25863, 30454, 1781, -30219, -14345, 7931, -19458, -22783, 19203, 18947, -18687, 1279, -6917, 7417, 22263, -2570, 
    1016, 13050, -3844, -29185, 26625, 5122, 29185, -19457, 19709, -9990, -3592, 2296, 20984, -20231, -13829, 5374, 
    0, 6145, 7169, 4608, 17150, 8444, 13562, -2568, -20488, 27897, -1286, -3076, -9474, 13824, -18944, 15872, 
    -3586, 8701, 17659, -12039, 7673, 22009, 26362, 3324, -9219, 25343, 16384, 17152, 28159, -3331, 13564, -24326, 
    -25863, 24825, -7, 20219, -1796, -27394, -17153, 10240, -16129, -24834, 3325, 28155, 10234, -29703, -16647, -19718, 
    11004, -13827, 10239, -3841, -3585, 11263, -12035, 14076, -15366, -11527, -24839, 13562, 28667, 253, -31490, -25601, 
    0, -25601, -31490, 253, 28667, 13562, -24839, -11527, -15366, 14076, -12035, 11263, -3585, -3841, 10239, -13827, 
    11004, -19718, -16647, -29703, 10234, 28155, 3325, -24834, -16129, 10240, -17153, -27394, -1796, 20219, -7, 24825, 
    -25863, -24326, 13564, -3331, 28159, 17152, 16384, 25343, -9219, 3324, 26362, 22009, 7673, -12039, 17659, 8701, 
    -3586, 15872, -18944, 13824, -9474, -3076, -1286, 27897, -20488, -2568, 13562, 8444, 17150, 4608, 7169, 6145, 
    0, 5374, -13829, -20231, 20984, 2296, -3592, -9990, 19709, -19457, 29185, 5122, 26625, -29185, -3844, 13050, 
    1016, -2570, 22263, 7417, -6917, 1279, -18687, 18947, 19203, -22783, -19458, 7931, -14345, -30219, 1781, 30454, 
    -25863, -16131, -5375, 3333, 18694, 11269, -11263, -4100, -25609, 11507, -10512, 25585, -2572, -3846, 3586, -24824, 
    -7412, 30477, -19447, -4351, -32265, -24596, -1053, 17376, -28189, -2834, 7938, 24091, -16329, -28077, -2710, -30598, 
];

float[] genWaveTableRescaledF(immutable short[] data) {
    float[] res;
    res.length = WAVETABLE_SIZE;
    for (int i = 0; i < WAVETABLE_SIZE; i++) {
        int index = cast(int)(i * data.length / WAVETABLE_SIZE);
        int indexMod = cast(int)(i * data.length % WAVETABLE_SIZE);
        float v1 = data[index % data.length];
        float v2 = data[(index + 1) % data.length];
        float v = (cast(long)v1 * (WAVETABLE_SIZE - indexMod) + v2 * indexMod) / WAVETABLE_SIZE;
        res[i] = v;
    }
    return res;
}

__gshared int[] SIN_TABLE;
__gshared int[] SQUARE_TABLE;
__gshared float[] SIN_TABLE_F;
__gshared float[] SQUARE_TABLE_F;
__gshared float[] COS_2_TABLE_F;
__gshared float[] VOICE_IMPULSE_F;

__gshared static this() {
    SIN_TABLE = genWaveTableSin();
    SIN_TABLE_F = genWaveTableSinF();
    SQUARE_TABLE = genWaveTableSquare();
    SQUARE_TABLE_F = genWaveTableSquareF();
    COS_2_TABLE_F = genWaveTableCosSquaredF();
    VOICE_IMPULSE_F = genWaveTableRescaledF(VOICE_IMPULSE);
}

