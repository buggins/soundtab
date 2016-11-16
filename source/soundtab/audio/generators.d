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
        v /= 32768;
        res[i] = v;
    }
    return res;
}

class Osciller {
    int[] _origWavetable;
    int[] _wavetable;
    int _scale;
    int _offset;
    int _phase; // *256
    int _step;
    this(int[] wavetable, int scale = WAVETABLE_SCALE, int offset = 0) {
        _origWavetable = wavetable;
        rescale(scale, offset);
    }
    void rescale(int scale = WAVETABLE_SCALE, int offset = 0) {
        _scale = scale;
        _offset = offset;
        if (scale == WAVETABLE_SCALE && offset == 0) {
            _wavetable = _origWavetable;
        } else {
            _wavetable = _origWavetable.dup;
            for (int i = 0; i < _origWavetable.length; i++) {
                _wavetable[i] = _origWavetable[i] * scale / WAVETABLE_SCALE + offset;
            }
        }
    }
    void setStep(int step_mul_256) {
        _step = step_mul_256;
    }
    /// set step based on pitch frequency (Hz) and samples per second
    void setPitch(double freq, int samplesPerSecond) {
        _step = cast(int)(WAVETABLE_SIZE  * 256 * freq / samplesPerSecond);
    }
    int step(int step_mul_256) {
        _phase = (_phase + step_mul_256) & WAVETABLE_SIZE_MASK_MUL_256;
        return _wavetable[_phase >> 8];
    }
    // step by value with gain (*0x10000)
    int stepWithGain(int step_mul_256, int gain) {
        _phase = (_phase + step_mul_256) & WAVETABLE_SIZE_MASK_MUL_256;
        return (_wavetable[_phase >> 8] * gain) >> 16;
    }
    // use current step value
    int step() {
        _phase = (_phase + _step) & WAVETABLE_SIZE_MASK_MUL_256;
        return _wavetable[_phase >> 8];
    }
    // multiplies passed value to next step and divide by 0x10000
    int stepMultiply(int n) {
        _phase = (_phase + _step) & WAVETABLE_SIZE_MASK_MUL_256;
        int value = _wavetable[_phase >> 8];
        return cast(int)((cast(long)n * value) >> 16);
    }
    // multiplies passed value to next step using modulation gain relative to 0x10000
    int stepMultiply(int n, int gain) {
        _phase = (_phase + _step) & WAVETABLE_SIZE_MASK_MUL_256;
        int value = _origWavetable[_phase >> 8];
        if (gain > 30)
            value = ((value * gain) >> WAVETABLE_SCALE_BITS) + 0x10000;
        return cast(int)((cast(long)n * value) >> 16);
    }
    void resetPhase() {
        _phase = 0;
    }
}

class OscillerF {
    float[] _origWavetable;
    float[] _wavetable;
    float _scale;
    float _offset;
    int _phase; // *256
    int _step;
    this(float[] wavetable, float scale = 1.0f, float offset = 0, immutable(float[]) formants = null) {
        _origWavetable = wavetable;
        rescale(scale, offset, formants);
    }
    void rescale(float scale = 1.0f, float offset = 0, immutable(float[]) formants = null) {
        _scale = scale;
        _offset = offset;
        if (scale == 1.0f && offset == 0 && !formants.length) {
            _wavetable = _origWavetable;
        } else {
            _wavetable = _origWavetable.dup;
            float maxAmp = 0;
            for (int i = 0; i < _origWavetable.length; i++) {
                float v = _origWavetable[i];
                if (formants.length) {
                    v *= formants[0];
                    for (int j = 2; j < formants.length; j++) {
                        v += _origWavetable[i * j % _origWavetable.length] * formants[j];
                    }
                }
                _wavetable[i] = v;
                if (v > maxAmp)
                    maxAmp = v;
                else if (-v > maxAmp)
                    maxAmp = -v;
            }
            float mult = 1 / maxAmp;
            for (int i = 0; i < _origWavetable.length; i++) {
                _wavetable[i] = _wavetable[i] * mult * scale + offset;
            }
        }
    }
    void setStep(int step_mul_256) {
        _step = step_mul_256;
    }
    /// set step based on pitch frequency (Hz) and samples per second
    void setPitch(double freq, int samplesPerSecond) {
        _step = cast(int)(WAVETABLE_SIZE  * 256 * freq / samplesPerSecond);
    }
    float step(int step_mul_256) {
        _phase = (_phase + step_mul_256) & WAVETABLE_SIZE_MASK_MUL_256;
        return _wavetable[_phase >> 8];
    }
    float stepPitchMultiply(int step_mul_256, int mult_by_100000) {
        step_mul_256 = cast(int)((cast(long)step_mul_256 * mult_by_100000) / 100000);
        _phase = (_phase + step_mul_256) & WAVETABLE_SIZE_MASK_MUL_256;
        return _wavetable[_phase >> 8];
    }
    // step by value with gain (*0x10000)
    float stepWithGain(int step_mul_256, float gain) {
        _phase = (_phase + step_mul_256) & WAVETABLE_SIZE_MASK_MUL_256;
        return _wavetable[_phase >> 8] * gain;
    }
    // use current step value
    float step() {
        _phase = (_phase + _step) & WAVETABLE_SIZE_MASK_MUL_256;
        return _wavetable[_phase >> 8];
    }
    void resetPhase() {
        _phase = 0;
    }
}

struct Interpolator {
    private int _target;
    private int _value;
    private int _step;
    private int _dstep;
    private bool _const = true;
    private bool _zero = true;
    /// reset to const
    void reset(int v) {
        _value = v;
        _step = _dstep = 0;
        _const = true;
        _zero = (_value == 0);
    }
    /// reset to target value
    void reset() {
        _value = _target;
        _step = _dstep = 0;
        _const = true;
        _zero = (_value == 0);
    }
    /// set target value for interpolation
    @property void target(int newValue) {
        _target = newValue;
    }
    /// get target value
    @property int target() { return _target; }
    /// get current value
    @property int value() { return _value; }
    /// returns true if interpolator will return const value
    @property bool isConst() { return _const; }
    /// returns true if interpolator will return const value 0
    @property bool isZero() { return _zero; }
    /// set interpolation parameters to interpolate values in range _value .. _newValue in len frames
    void init(int len) {
        if (_target == _value) {
            _const = true;
            _zero = (_value == 0);
        } else {
            _const = false;
            _zero = false;
            int delta = _target - _value;
            _step = delta / len;
            _dstep = delta % len;
        }
    }
    /// get next interpolated value
    @property int next() {
        if (_const)
            return _value;
        int res = _value;
        _value += _step;
        if (_dstep > 0) {
            _value++;
            _dstep--;
        } else if (_dstep < 0) {
            _value--;
            _dstep++;
        }
        return res;
    }
}

/// float value interpolator
struct InterpolatorF {
    private float _target = 0;
    private float _value = 0;
    private float _step = 0;
    private bool _const = true;
    private bool _zero = true;
    /// reset to const
    void reset(float v) {
        _value = v;
        _step = 0;
        _const = true;
        _zero = (v == 0);
    }
    /// reset to target
    void reset() {
        _value = _target;
        _step = 0;
        _const = true;
        _zero = (_value == 0);
    }
    /// returns true if interpolator will return const value
    @property bool isConst() { return _const; }
    /// returns true if interpolator will return const value 0
    @property bool isZero() { return _zero; }
    /// set target value for interpolation
    @property void target(float newValue) {
        _target = newValue;
    }
    /// get target value
    @property float target() { return _target; }
    /// get current value
    @property float value() { return _value; }
    /// set interpolation parameters to interpolate values in range _value .. _target in len frames
    void init(int len) {
        _step = (_target - _value) / len;
        if (_step >= -0.0000000001f && _step <= 0.0000000001f) {
            _const = true;
            _zero = (_value >= -0.000001f && _value <= 0.000001f);
        } else {
            _const = false;
            _zero = false;
        }
    }
    /// get next interpolated value
    @property float next() {
        if (_const)
            return _value;
        float res = _value;
        _value += _step;
        return res;
    }
    /// limit speed of target change 
    void limitTargetChange(int frameMillis, int attackMillis, int releaseMillis) {
        if (_value < _target) {
            // attack
            if (frameMillis < attackMillis)
                _target = _value + (_target - _value) * frameMillis / attackMillis;
        } else {
            // release
            if (frameMillis < releaseMillis)
                _target = _value + (_target - _value) * frameMillis / releaseMillis;
        }
    }
}

__gshared int[] SIN_TABLE;
__gshared int[] SQUARE_TABLE;
__gshared float[] SIN_TABLE_F;
__gshared float[] SQUARE_TABLE_F;
__gshared float[] COS_2_TABLE_F;
__gshared float[] VOICE_IMPULSE_F;
__gshared float[] SAW_TABLE_F;
__gshared float[] SAW_TABLE_2_F;
__gshared float[] VOICE_EXPERIMENTAL_F;
__gshared float[] VOICE_EX_1_F;

float[] normalize(float[] data, float amp = 1) {
    float[] res = data.dup;
    float s = 0;
    foreach(sample; res)
        s+=sample;
    s /= res.length;
    foreach(ref sample; res)
        sample -= s;
    float minv = res[0];
    float maxv = res[0];
    foreach(sample; res) {
        if (minv > sample)
            minv = sample;
        if (maxv < sample)
            maxv = sample;
    }
    if (-minv > maxv)
        maxv = -minv;
    float mult = amp / maxv;
    foreach(ref sample; res)
        sample *= mult;
    return res;
}

immutable ulong RANDOM_MULTIPLIER  = 0x5DEECE66D;
immutable ulong RANDOM_MASK = ((cast(ulong)1 << 48) - 1);
immutable ulong RANDOM_ADDEND = cast(ulong)0xB;

struct Random {
    ulong seed;
    //Random();
    void setSeed(ulong value) {
        seed = (value ^ RANDOM_MULTIPLIER) & RANDOM_MASK;
    }

    int next(int bits) {
        seed = (seed * RANDOM_MULTIPLIER + RANDOM_ADDEND) & RANDOM_MASK;
        return cast(int)(seed >> (48 - bits));
    }

    int nextInt() {
        return next(31);
    }
    int nextInt(int n) {
        if ((n & -n) == n)  // i.e., n is a power of 2
            return cast(int)((n * cast(long)next(31)) >> 31);
        int bits, val;
        do {
            bits = next(31);
            val = bits % n;
        } while (bits - val + (n - 1) < 0);
        return val;
    }
}

struct Noise {
    Random _rnd;
    float tick() {
        int value = _rnd.next(16) - 32768;
        return value / 32768.0f;
    }
}

__gshared static this() {
    SIN_TABLE = genWaveTableSin();
    SIN_TABLE_F = genWaveTableSinF();
    SQUARE_TABLE = genWaveTableSquare();
    SQUARE_TABLE_F = genWaveTableSquareF();
    COS_2_TABLE_F = genWaveTableCosSquaredF();
    VOICE_IMPULSE_F = genWaveTableRescaledF(VOICE_IMPULSE);
    SAW_TABLE_F = genWaveTableRescaledF([0, 32767, 0, -32767]);
    SAW_TABLE_2_F = genWaveTableRescaledF([0, 32767]);
    //VOICE_EXPERIMENTAL_F = genWaveTableRescaledF([0, 32767, 30000, -24000, -20000, 16384, 15000, -12000, -10000, 8000, -4000, 2000, -1000, 0, 0, 0, 0,]);
    //VOICE_EXPERIMENTAL_F = genWaveTableRescaledF([0, 32767, 30000, 4000, -32767, -30000, -4000, -2000, 0, 0, 0, 0, 0, 0, 0, 0,]);
    //VOICE_EXPERIMENTAL_F = genWaveTableRescaledF([0, 32767, 32767, -24000, -24000, 8000, 8000, -4000, -4000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,]);
    VOICE_EX_1_F = genWaveTableRescaledF([
        0,
        30000,
        30000,
        0,
        0,
        0,
        0,
        0,
        0,
        -100,
        -300,
        -500,
        -1000,
        -2000,
        -3000,
        -2000,
        -1000,
    ]);
    VOICE_EXPERIMENTAL_F = genWaveTableRescaledF([
            0,
            25000,
            30000,
            32000,
            30000,
            26000,
            15000,
            12000,
            10000,
            7000,
            4000,
            3000,
            2000,
            1000,
            500,
            0,
            -500,
            -1000,
            -2000,
            -3000,
            -4000,
            -5000,
            -6000,
            -7000,
            -10000,
            -12000,
            -15000,
            -26000,
            -30000,
            -32000,
            -30000,
            -25000,
    ]);
}
