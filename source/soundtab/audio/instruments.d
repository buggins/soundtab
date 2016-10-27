module soundtab.audio.instruments;

import dlangui.core.logger;
import soundtab.ui.noteutil;

enum SampleFormat {
    signed16,
    float32
}

immutable WAVETABLE_SIZE_BITS = 14;
immutable WAVETABLE_SIZE = 1 << WAVETABLE_SIZE_BITS;
immutable WAVETABLE_SIZE_MASK = WAVETABLE_SIZE - 1;
immutable WAVETABLE_SIZE_MASK_MUL_256 = (1 << (WAVETABLE_SIZE_BITS + 8)) - 1;
immutable WAVETABLE_SCALE_BITS = 14;
immutable WAVETABLE_SCALE = (1 << WAVETABLE_SCALE_BITS);

int[] genWaveTableSin() {
    import std.math;
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
    import std.math;
    float[] res;
    res.length = WAVETABLE_SIZE;
    for (int i = 0; i < WAVETABLE_SIZE; i++) {
        double f = i * 2 * PI / WAVETABLE_SIZE;
        double v = sin(f);
        res[i] = cast(float)v;
    }
    return res;
}

int[] genWaveTableSquare() {
    import std.math;
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
    import std.math;
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

__gshared int[] SIN_TABLE;
__gshared int[] SQUARE_TABLE;
__gshared float[] SIN_TABLE_F;
__gshared float[] SQUARE_TABLE_F;

__gshared static this() {
    SIN_TABLE = genWaveTableSin();
    SIN_TABLE_F = genWaveTableSinF();
    SQUARE_TABLE = genWaveTableSquare();
    SQUARE_TABLE_F = genWaveTableSquareF();
}

void interpolate(int[] arr, int startValue, int endValue) {
    int len = cast(int)arr.length;
    int diff = endValue - startValue;
    for(int i = 0; i < len; i++)
        arr.ptr[i] = startValue + diff * i / len;
}

class FormantFilter {
    int samplesPerSecond;
    int[] table;
    int freqToStep(int freq) {
        return WAVETABLE_SIZE  * freq / samplesPerSecond;
    }
    void init(int samplesPerSecond) {
        this.samplesPerSecond = samplesPerSecond;
        table.length = WAVETABLE_SIZE;
        table[0..$] = 0;
        int maxFreqStep = freqToStep(16000);
        int maxFreqStepCut = freqToStep(22000);
        int minFreqStep = freqToStep(50);
        int minFreqStepCut = freqToStep(20);
        interpolate(table[maxFreqStepCut .. maxFreqStep], 0, 0x10000);
        interpolate(table[maxFreqStep .. minFreqStep], 0x10000, 0x10000);
        interpolate(table[minFreqStep .. minFreqStepCut], 0x10000, 0);
    }
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
    this(float[] wavetable, float scale = 1.0f, float offset = 0) {
        _origWavetable = wavetable;
        rescale(scale, offset);
    }
    void rescale(float scale = 1.0f, float offset = 0) {
        _scale = scale;
        _offset = offset;
        if (scale == 1.0f && offset == 0) {
            _wavetable = _origWavetable;
        } else {
            _wavetable = _origWavetable.dup;
            for (int i = 0; i < _origWavetable.length; i++) {
                _wavetable[i] = _origWavetable[i] * scale + offset;
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

/// for float->short conversion
union ShortConv {
    short value;
    byte[2] bytes;
}

/// for float->byte conversion
union FloatConv {
    float value;
    byte[4] bytes;
}

/// limit int value to fit short range -32768..32767
void limitShortRange(ref int value) {
    if (value < -32768)
        value = -32768;
    else if (value > 32767)
        value = 32767;
}

class AudioSource {

    import core.sync.mutex;

    protected Mutex _lock;


    this() {
        _lock = new Mutex();
    }
    void lock() {
        _lock.lock();
    }
    void unlock() {
        _lock.unlock();
    }

    protected SampleFormat sampleFormat = SampleFormat.float32;
    protected int samplesPerSecond = 44100;
    protected int channels = 2;
    protected int bitsPerSample = 16;
    protected int blockAlign = 4;

    /// recalculate some parameters after format change or after generation
    protected void calcParams() {
    }

    void setFormat(SampleFormat format, int channels, int samplesPerSecond, int bitsPerSample, int blockAlign) {
        lock();
        scope(exit)unlock();

        this.sampleFormat = format;
        this.channels = channels;
        this.samplesPerSecond = samplesPerSecond;
        this.bitsPerSample = bitsPerSample;
        this.blockAlign = blockAlign;
        calcParams();
        onFormatChanged();
    }

    protected void onFormatChanged() {
    }

    /// put samples in int format
    protected void putSamples(ubyte * buf, int sample1, int sample2) {
        if (sampleFormat == SampleFormat.float32) {
            FloatConv floatConv;
            floatConv.value = cast(float)(sample1 / 65536.0);
            buf[0] = floatConv.bytes.ptr[0];
            buf[1] = floatConv.bytes.ptr[1];
            buf[2] = floatConv.bytes.ptr[2];
            buf[3] = floatConv.bytes.ptr[3];
            if (channels > 1) {
                floatConv.value = cast(float)(sample2 / 65536.0);
                buf[4] = floatConv.bytes.ptr[0];
                buf[5] = floatConv.bytes.ptr[1];
                buf[6] = floatConv.bytes.ptr[2];
                buf[7] = floatConv.bytes.ptr[3];
            }
            // TODO: more channels
        } else {
            ShortConv shortConv;
            shortConv.value = cast(short)(sample1);
            buf[0] = shortConv.bytes.ptr[0];
            buf[1] = shortConv.bytes.ptr[1];
            if (channels > 1) {
                shortConv.value = cast(short)(sample2);
                buf[2] = shortConv.bytes.ptr[0];
                buf[3] = shortConv.bytes.ptr[1];
            }
            // TODO: more channels
        }
    }

    /// put samples in float format
    protected void putSamples(ubyte * buf, float sample1, float sample2) {
        if (sampleFormat == SampleFormat.float32) {
            FloatConv floatConv;
            floatConv.value = sample1;
            buf[0] = floatConv.bytes.ptr[0];
            buf[1] = floatConv.bytes.ptr[1];
            buf[2] = floatConv.bytes.ptr[2];
            buf[3] = floatConv.bytes.ptr[3];
            if (channels > 1) {
                floatConv.value = sample2;
                buf[4] = floatConv.bytes.ptr[0];
                buf[5] = floatConv.bytes.ptr[1];
                buf[6] = floatConv.bytes.ptr[2];
                buf[7] = floatConv.bytes.ptr[3];
            }
            // TODO: more channels
        } else {
            ShortConv shortConv;
            int sample1i = cast(int)(sample1 * 32767.0f);
            int sample2i = cast(int)(sample2 * 32767.0f);
            limitShortRange(sample1i);
            limitShortRange(sample2i);
            shortConv.value = cast(short)(sample1i);
            buf[0] = shortConv.bytes.ptr[0];
            buf[1] = shortConv.bytes.ptr[1];
            if (channels > 1) {
                shortConv.value = cast(short)(sample2i);
                buf[2] = shortConv.bytes.ptr[0];
                buf[3] = shortConv.bytes.ptr[1];
            }
            // TODO: more channels
        }
    }

    protected void generateSilence(int frameCount, ubyte * buf) {
        for (int i = 0; i < frameCount; i++) {
            putSamples(buf, 0, 0);
            buf += blockAlign;
        }
    }

    /// load data into buffer
    bool loadData(int frameCount, ubyte * buf, ref uint flags) {
        // silence
        // override to render sound
        flags = 0;
        generateSilence(frameCount, buf);
        return true;
    }
}

struct Controller {
    string id;
    dstring name;
    int minValue;
    int maxValue;
    int value;
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

class Instrument : AudioSource {

    protected string _id;
    protected dstring _name;

    @property dstring name() { return _name; }
    @property string id() { return _id; }

    protected float _targetPitch = 1000; // Hz
    protected float _targetGain = 0; // 0..1
    protected float _targetController1 = 0;

    protected int _attack = 20;
    protected int _release = 40;

    /// returns list of supported controllers
    immutable(Controller)[] getControllers() {
        return [];
    }

    /// returns true if controller value is set, false for unknown controller
    bool updateController(string controllerName, int value) {
        return false;
    }

    void setSynthParams(float pitch, float gain, float controller1) {
        lock();
        scope(exit)unlock();

        if (pitch < 16)
            pitch = 16;
        if (pitch > 12000)
            pitch = 12000;
        if (gain < 0)
            gain = 0;
        if (gain > 1)
            gain = 1;
        if (controller1 < 0)
            controller1 = 0;
        if (controller1 > 1)
            controller1 = 1;
        // lower part of tablet should be sine
        if (controller1 < 0.9)
            controller1 /= 0.9;
        else
            controller1 = 1;
        if (gain > 0.001) {
            _targetPitch = pitch;
            _targetController1 = controller1;
        }
        _targetGain = gain;
    }

    protected int freqToStepMul256(float freq) {
        return cast(int)(WAVETABLE_SIZE * freq / samplesPerSecond * 256);
    }
}

/// i is [0..len-1], interpolate from startValue to endValue
int interpolate(int i, int len, int startValue, int endValue) {
    return startValue + (endValue - startValue) * i / len;
}

/// i is [0..len-1], interpolate from startValue to endValue
float interpolate(int i, int len, float startValue, float endValue) {
    return startValue + (endValue - startValue) * i / len;
}

void interpolateTable(ref float[] table, int len, float startValue, float endValue) {
    if (table.length < len)
        table.length = len;
    float v = startValue;
    float step = (endValue - startValue) / len;
    for (int i = 0; i < len; i++) {
        table.ptr[i] = v;
        v += step;
    }
}

void interpolateTable(ref int[] table, int len, int startValue, int endValue) {
    if (table.length < len)
        table.length = len;
    int v = startValue;
    int step = (endValue - startValue) / len;
    int dstep = (endValue - startValue) % len;
    for (int i = 0; i < len; i++) {
        table.ptr[i] = v;
        v += step;
        if (dstep > 0) {
            v++;
            dstep--;
        } else if (dstep < 0) {
            v--;
            dstep++;
        }
    }
}

/// float calculations instrument base class
class InstrumentBaseF : Instrument {

    Interpolator  _pitch;
    InterpolatorF _gain;
    InterpolatorF _controller1;
    InterpolatorF _vibratoAmount;
    Interpolator  _vibratoFreq;

    float _targetVibratoAmount = 0;
    float _targetVibratoFreq = 10;

    protected int _phase_mul_256 = 0;

    protected override void calcParams() {
        // copy dynamic values
        _pitch.target = freqToStepMul256(_targetPitch);
        _gain.target = _targetGain;
        _controller1.target = _targetController1;
        _vibratoAmount.target = _targetVibratoAmount;
        _vibratoFreq.target = freqToStepMul256(_targetVibratoFreq);
    }

    protected void interpolateParams(int frameCount) {
        int frameMillis = frameCount < 10 ? 10 : 1000 * frameCount / samplesPerSecond;

        _gain.limitTargetChange(frameMillis, _attack, _release);
        _gain.init(frameCount);
        _pitch.init(frameCount);
        _controller1.init(frameCount);
        _vibratoAmount.init(frameCount);
        _vibratoFreq.init(frameCount);
    }

    override protected void onFormatChanged() {
        _phase_mul_256 = 0;
    }

    /// returns true if controller value is set, false for unknown controller
    override bool updateController(string controllerName, int value) {
        switch(controllerName) {
            case "vibratoAmount":
                // 0 .. 1/8 tone
                _targetVibratoAmount = QUARTER_TONE / 2 * value / 1000.0f;
                break;
            case "vibratoFreq":
                // 1 .. 20 hz
                _targetVibratoFreq = 1 + value * 20 / 1000;
                break;
            default:
                break;
        }
        return false;
    }

}

/// integer calculations instrument base class
class InstrumentBase : Instrument {
    protected double _currentPitch = 0; // Hz
    protected double _currentGain = 0; // 0..1
    protected double _currentController1 = 0; // 0..1

    protected int _phase_mul_256 = 0;

    protected int _target_step_mul_256 = 0; // step*256 inside wavetable to generate requested frequency
    protected int _target_gain_mul_65536 = 0;
    protected int _target_controller1_mul_65536 = 0;
    protected int _step_mul_256 = 0; // step*256 inside wavetable to generate requested frequency
    protected int _gain_mul_65536 = 0;
    protected int _controller1_mul_65536 = 0;

    protected override void calcParams() {
        // copy dynamic values
        _currentPitch = _targetPitch;
        _currentGain = _targetGain;
        _currentController1 = _targetController1;
        double onePeriodSamples = samplesPerSecond / _currentPitch;
        double step = WAVETABLE_SIZE / onePeriodSamples;
        _target_step_mul_256 = cast(int)(step * 256);
        _target_gain_mul_65536 = cast(int)(_currentGain * 0x10000);
        _target_controller1_mul_65536 = cast(int)(_currentController1 * 0x10000);
    }

    override protected void onFormatChanged() {
        _phase_mul_256 = 0;
    }
}

class SineWave : InstrumentBaseF {
    OscillerF _tone1;
    float[] _wavetable;
    this() {
        _id = "sinewave";
        _name = "Sine Wave";
        _wavetable = SIN_TABLE_F;
        _tone1 = new OscillerF(_wavetable);
    }

    override bool loadData(int frameCount, ubyte * buf, ref uint flags) {
        {
            lock();
            scope(exit)unlock();
            calcParams();
        }

        interpolateParams(frameCount);

        for (int i = 0; i < frameCount; i++) {
            /// one step
            float gain = _gain.next;
            float controller1 = _controller1.next;

            //float gain1 = gain; //cast(int)((cast(long)gain * gain_vibrato) >> 16); // left
            //float gain2 = gain; //cast(int)((cast(long)gain * (0x20000 - gain_vibrato)) >> 16); // right

            int step = _pitch.next; //_vibrato0.stepMultiply(_step_mul_256, vibratoAmount1);

            float sample = _tone1.step(step) * gain;

            putSamples(buf, sample, sample);

            buf += blockAlign;
        }

        // TODO
        //durationCounter--;
        flags = 0; //durationCounter <= 0 ? AUDCLNT_BUFFERFLAGS.AUDCLNT_BUFFERFLAGS_SILENT : 0;
        //Log.d("Instrument loadData - exit");
        return true;
    }

    /// returns list of supported controllers
    override immutable(Controller)[] getControllers() {
        Controller[] res;
        //res ~= Controller("chorus", "Chorus", 0, 1000, 300);
        //res ~= Controller("reverb", "Reverb", 0, 1000, 300);
        res ~= Controller("vibrato", "Vibrato Amount", 0, 1000, 300);
        res ~= Controller("vibratoFreq", "Vibrato Freq", 0, 1000, 500);
        return cast(immutable(Controller)[])res;
    }

    /// returns true if controller value is set, false for unknown controller
    override bool updateController(string controllerName, int value) {
        return false;
    }

}

class MyAudioSource : InstrumentBase {



    int[] _wavetable;


    Osciller _vibrato0;
    Osciller _vibrato1;
    Osciller _vibrato2;
    Osciller _vibrato3;
    Osciller _vibrato4;
    Osciller _vibrato5;
    Osciller _vibrato21;
    Osciller _vibrato22;
    Osciller _vibrato23;
    Osciller _vibrato24;
    Osciller _vibrato25;
    Osciller _tone1;
    Osciller _tone2;
    Osciller _tone3;
    Osciller _tone4;
    Osciller _tone5;
    Osciller _tone21;
    Osciller _tone22;
    Osciller _tone23;
    Osciller _tone24;
    Osciller _tone25;

    this() {
        _id = "ethereal";
        _name = "Ethereal";
        _wavetable = SIN_TABLE; //genWaveTableSquare(); //genWaveTableSin();
        //_wavetable = genWaveTableSquare(); //genWaveTableSin();
        _vibrato0 = new Osciller(SIN_TABLE, 500, 0x10000);
        _vibrato1 = new Osciller(SIN_TABLE, 500, 0x10000);
        _vibrato2 = new Osciller(SIN_TABLE, 600, 0x10000);
        _vibrato3 = new Osciller(SIN_TABLE, 700, 0x10000);
        _vibrato4 = new Osciller(SIN_TABLE, 1000, 0x10000);
        _vibrato5 = new Osciller(SIN_TABLE, 400, 0x10000);
        _vibrato21 = new Osciller(SIN_TABLE, 700, 0x10000);
        _vibrato22 = new Osciller(SIN_TABLE, 800, 0x10000);
        _vibrato23 = new Osciller(SIN_TABLE, 900, 0x10000);
        _vibrato24 = new Osciller(SIN_TABLE, 700, 0x10000);
        _vibrato25 = new Osciller(SIN_TABLE, 500, 0x10000);
        _tone1 = new Osciller(_wavetable);
        _tone2 = new Osciller(_wavetable);
        _tone3 = new Osciller(_wavetable);
        _tone4 = new Osciller(_wavetable);
        _tone5 = new Osciller(_wavetable);
        _tone21 = new Osciller(_wavetable);
        _tone22 = new Osciller(_wavetable);
        _tone23 = new Osciller(_wavetable);
        _tone24 = new Osciller(_wavetable);
        _tone25 = new Osciller(_wavetable);
    }

    override protected void onFormatChanged() {
        _phase_mul_256 = 0;
        _vibrato0.setPitch(2.234, samplesPerSecond);
        _vibrato1.setPitch(2.234, samplesPerSecond);
        _vibrato2.setPitch(2.12367, samplesPerSecond);
        _vibrato3.setPitch(2.37615263, samplesPerSecond);
        _vibrato4.setPitch(2.78431, samplesPerSecond);
        _vibrato5.setPitch(2.34562, samplesPerSecond);
        _vibrato21.setPitch(2.65321, samplesPerSecond);
        _vibrato22.setPitch(2.5432, samplesPerSecond);
        _vibrato23.setPitch(2.4321, samplesPerSecond);
        _vibrato24.setPitch(2.36345, samplesPerSecond);
        _vibrato25.setPitch(2.76434, samplesPerSecond);
    }

    //int durationCounter = 100;

    override bool loadData(int frameCount, ubyte * buf, ref uint flags) {
        {
            lock();
            scope(exit)unlock();
            calcParams();
        }

        int frameMillis = frameCount < 10 ? 10 : 1000 * frameCount / samplesPerSecond;

        int lastGain = _gain_mul_65536;
        int lastController1 = _controller1_mul_65536;

        _step_mul_256 = _target_step_mul_256;
        _controller1_mul_65536 = _target_controller1_mul_65536;

        if (_gain_mul_65536 < _target_gain_mul_65536) {
            // attack
            if (frameMillis > _attack)
                _gain_mul_65536 = _target_gain_mul_65536;
            else {
                _gain_mul_65536 = _gain_mul_65536 + (_target_gain_mul_65536 - _gain_mul_65536) * frameMillis / _attack;
            }
        } else {
            // release
            if (frameMillis > _release)
                _gain_mul_65536 = _target_gain_mul_65536;
            else {
                _gain_mul_65536 = _gain_mul_65536 + (_target_gain_mul_65536 - _gain_mul_65536) * frameMillis / _release;
            }
        }

        Log.d("Instrument loadData frameCount=", frameCount, " lastGain=", lastGain, " newGain=", _gain_mul_65536);

        for (int i = 0; i < frameCount; i++) {
            /// one step
            int gain = interpolate(i, frameCount, lastGain, _gain_mul_65536);
            int controller1 = interpolate(i, frameCount, lastController1, _controller1_mul_65536);

            int vibratoAmount0 = (500 * controller1) >> 16;
            int vibratoAmount1 = (500 * controller1) >> 16;
            int vibratoAmount2 = (700 * controller1) >> 16;
            int vibratoAmount3 = (600 * controller1) >> 16;
            int vibratoAmount4 = (400 * controller1) >> 16;
            int vibratoAmount5 = (300 * controller1) >> 16;
            //vibratoAmount1 = vibratoAmount2 = vibratoAmount3 = vibratoAmount4 = vibratoAmount5 = 0;


            //int gain_vibrato = _vibrato4.step();

            int gain1 = gain; //cast(int)((cast(long)gain * gain_vibrato) >> 16); // left
            int gain2 = gain; //cast(int)((cast(long)gain * (0x20000 - gain_vibrato)) >> 16); // right

            //int step = _step_mul_256; //_vibrato0.stepMultiply(_step_mul_256, vibratoAmount1);
            int step = _vibrato0.stepMultiply(_step_mul_256, vibratoAmount1);

            int wt_value1 = _tone1.stepWithGain(_vibrato1.stepMultiply(step, vibratoAmount1), 20000);
            int wt_value2 = _tone2.stepWithGain(_vibrato2.stepMultiply(step * 2, vibratoAmount2), 10000);
            int wt_value3 = _tone3.stepWithGain(_vibrato3.stepMultiply(step * 3, vibratoAmount3), 7000);
            int wt_value4 = _tone4.stepWithGain(_vibrato4.stepMultiply(step * 4, vibratoAmount4), 4000);
            int wt_value5 = _tone5.stepWithGain(_vibrato4.stepMultiply(step * 5, vibratoAmount5), 2000);

            int wt_value21 = _tone1.stepWithGain(_vibrato21.stepMultiply(step, vibratoAmount1), 20000);
            int wt_value22 = _tone2.stepWithGain(_vibrato22.stepMultiply(step * 2, vibratoAmount2), 10000);
            int wt_value23 = _tone3.stepWithGain(_vibrato23.stepMultiply(step * 3, vibratoAmount3), 7000);
            int wt_value24 = _tone4.stepWithGain(_vibrato24.stepMultiply(step * 4, vibratoAmount4), 3000);
            int wt_value25 = _tone4.stepWithGain(_vibrato24.stepMultiply(step * 5, vibratoAmount5), 2000);


            //int wt_value_1 = wt_value1;
            //int wt_value_2 = wt_value2;

            //int inv_controller1 = 0x10000 - controller1;
            int wt_value_1 = wt_value1 + wt_value2 + wt_value3 + wt_value4 + wt_value5;
            int wt_value_2 = wt_value21 + wt_value22 + wt_value23 + wt_value24 + wt_value25;

            int sample1 = (wt_value_1 * gain1) >> 16;
            int sample2 = (wt_value_2 * gain2) >> 16;

            if (sample1 < -32767)
                sample1 = -32767;
            else if (sample1 > 32767)
                sample1 = 32767;
            if (sample2 < -32767)
                sample2 = -32767;
            else if (sample2 > 32767)
                sample2 = 32767;
            putSamples(buf, sample1, sample2);

            buf += blockAlign;
        }

        // TODO
        //durationCounter--;
        flags = 0; //durationCounter <= 0 ? AUDCLNT_BUFFERFLAGS.AUDCLNT_BUFFERFLAGS_SILENT : 0;
        //Log.d("Instrument loadData - exit");
        return true;
    }

    /// returns list of supported controllers
    override immutable(Controller)[] getControllers() {
        Controller[] res;
        res ~= Controller("chorus", "Chorus", 0, 1000, 300);
        res ~= Controller("reverb", "Reverb", 0, 1000, 300);
        res ~= Controller("vibrato", "Vibrato Amount", 0, 1000, 300);
        res ~= Controller("vibratoFreq", "Vibrato Freq", 0, 1000, 500);
        return cast(immutable(Controller)[])res;
    }

    /// returns true if controller value is set, false for unknown controller
    override bool updateController(string controllerName, int value) {
        return false;
    }

}

private __gshared Instrument[] _instrumentList;
/// get list of supported instruments
Instrument[] getInstrumentList() {
    if (!_instrumentList.length) {
        _instrumentList ~= new MyAudioSource();
        _instrumentList ~= new SineWave();
    }
    return _instrumentList;
}
