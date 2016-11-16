module soundtab.audio.instruments;

import dlangui.core.logger;
import soundtab.ui.noteutil;
import soundtab.audio.audiosource;
import soundtab.audio.filters;
import soundtab.audio.generators;
import std.math : log2, exp2, sin, cos, pow, PI;

void interpolate(float[] arr, float startValue, float endValue) {
    int len = cast(int)arr.length;
    float diff = endValue - startValue;
    for(int i = 0; i < len; i++)
        arr.ptr[i] = startValue + diff * i / len;
}

void interpolate(int[] arr, int startValue, int endValue) {
    int len = cast(int)arr.length;
    int diff = endValue - startValue;
    for(int i = 0; i < len; i++)
        arr.ptr[i] = startValue + diff * i / len;
}

struct FormantInfo {
    float freq;
    float gain;
    float width;
}

/// base implementation for formant filter - just limit min and max frequences
class FormantFilterBase {
    private int samplesPerSecond;
    private int maxFreqStep;
    private int maxFreqStepCut;
    private int minFreqStep;
    private int minFreqStepCut;
    private int minFreqShapingLen;
    private int maxFreqShapingLen;

    /// returns step*256 for frequency
    int freqToStep(float freq) {
        return cast(int)(WAVETABLE_SIZE  * 256L * freq / samplesPerSecond);
    }

    void init(int samplesPerSecond) {
        this.samplesPerSecond = samplesPerSecond;
        float maxFreqCut = 22000; // max freq cutoff
        float maxFreq = maxFreqCut * 0.8; // max freq when shaping starts
        /// limit max freqs according by sample rate
        float halfFreq = samplesPerSecond / 2.0f * 0.9;
        if (maxFreq > halfFreq) {
            float scale = halfFreq / maxFreq;
            maxFreqCut *= scale;
            maxFreq *= scale;
        }
        maxFreqStep = freqToStep(maxFreq);
        maxFreqStepCut = freqToStep(maxFreqCut);
        minFreqStep = freqToStep(40); // start of low freq shaping = 40Hz
        minFreqStepCut = freqToStep(15); // cutoff lowest freq = 15Hz
        minFreqShapingLen = minFreqStep - minFreqStepCut;
        maxFreqShapingLen = maxFreqStepCut - maxFreqStep;
    }

    /// apply filter to value; returns false if frequency is above max cutoff
    bool apply(int fundamentalFreqStep, int harmonicNumber, ref float value) {
        int step = fundamentalFreqStep * harmonicNumber;
        if (step < minFreqStepCut) {
            value = 0;
            return true; // cut off, but return true to allow higher frequences
        }
        if (step > maxFreqStepCut) {
            value = 0;
            return false; // cut off, return false to stop iteration for higher frequences
        }
        if (step < minFreqStep) {
            // shape lower frequencies
            value *= (step - minFreqStepCut) / cast(float)minFreqShapingLen;
        } else if (step > maxFreqStep) {
            // shape higher frequencies
            value *= (step - maxFreqStep) / cast(float)maxFreqShapingLen;
        }
        return true;
    }
}

class VowelFormantFilter : FormantFilterBase {
    float baseFreq;
    float formant1freq;
    float formant1gain;
    float formant12freq;
    float formant12gain;
    float formant2freq;
    float formant2gain;
    float formant23freq;
    float formant23gain;
    float formant3freq;
    float formant3gain;

    int baseStep;
    int formant1step;
    int formant12step;
    int formant2step;
    int formant23step;
    int formant3step;
    int formant34step;

    this(float baseFreq, float formant1freq, float formant1gain, float formant2freq, float formant2gain, float formant3freq, float formant3gain) {
        this.baseFreq = baseFreq;
        this.formant1freq = formant1freq;
        this.formant1gain = formant1gain;
        this.formant2freq = formant2freq;
        this.formant2gain = formant2gain;
        this.formant3freq = formant3freq;
        this.formant3gain = formant3gain;
        //formant12freq = (formant1freq * formant1gain + formant2freq * formant2gain) / (formant1gain + formant2gain);
        formant12freq = (formant1freq + formant2freq) / 2;
        formant12gain = (formant1gain + formant2gain) / 4;
        //formant23freq = (formant2freq * formant2gain + formant3freq * formant3gain) / (formant2gain + formant3gain);
        formant23freq = (formant2freq + formant3freq) / 2;
        formant23gain = (formant2gain + formant3gain) / 10;
    }

    override void init(int samplesPerSecond) {
        super.init(samplesPerSecond);
        baseStep = freqToStep(baseFreq);
        formant1step = freqToStep(formant1freq);
        formant12step = freqToStep(formant12freq);
        formant2step = freqToStep(formant2freq);
        formant23step= freqToStep(formant23freq);
        formant3step = freqToStep(formant3freq);
        formant34step = freqToStep(formant3freq * 1.2f);
        //for (float f = 10; f < 3000; f+=0.1) {
        //    float v = 1;
        //    apply(freqToStep(f), 1, v);
        //    Log.d(" freq ", f, " : ", v);
        //}
        import std.string : format;
        char[] s;
        for (float f = 10; f < 3000; f+=0.1) {
            float v = 1;
            apply(freqToStep(f), 1, v);
            s ~= "%.2f\t%.5f".format(f,v);
            s ~= "\n";
        }
        Log.d("FreqTable:\n", s);
    }

    /// apply filter to value; returns false if frequency is above max cutoff
    override bool apply(int fundamentalFreqStep, int harmonicNumber, ref float value) {
        // correct formant frequences based on fundamental frequency
        long correctedStep = fundamentalFreqStep; //(fundamentalFreqStep * 90 + baseStep * 10) / 100;
        long step = correctedStep * harmonicNumber;
        if (step < formant1step) {
            value *= COS_2_TABLE_F[cast(int)((formant1step - step) * cast(long)WAVETABLE_SIZE / formant1step)] * formant1gain;
        } else if (step < formant12step) {
            value *= COS_2_TABLE_F[cast(int)((step - formant1step) * cast(long)WAVETABLE_SIZE / (formant12step - formant1step))] * (formant1gain - formant12gain) + formant12gain;
        } else if (step < formant2step) {
            value *= COS_2_TABLE_F[cast(int)((formant2step - step) * cast(long)WAVETABLE_SIZE / (formant2step - formant12step))] * (formant2gain - formant12gain) + formant12gain;
        } else if (step < formant23step) {
            value *= COS_2_TABLE_F[cast(int)((step - formant2step) * cast(long)WAVETABLE_SIZE / (formant23step - formant2step))] * (formant2gain - formant23gain) + formant23gain;
        } else if (step < formant3step) {
            value *= COS_2_TABLE_F[cast(int)((formant3step - step) * cast(long)WAVETABLE_SIZE / (formant3step - formant23step))] * (formant3gain - formant23gain) + formant23gain;
        } else if (step < formant34step) {
            value *= COS_2_TABLE_F[cast(int)((step - formant3step) * cast(long)WAVETABLE_SIZE / (formant34step - formant3step))] * formant3gain;
        } else {
            value = 0;
        }
        return super.apply(fundamentalFreqStep, harmonicNumber, value);
    }
}

class FormantFilter : FormantFilterBase {
    private float baseGain = 0.2;
    private FormantInfo[] formants;
    int maxFreqStepCutMul256;
    /// right shift bits for input step value (step*256)
    private int stepShift;
    private int interpolationStepModShift;
    private float[] table;

    this(float baseGain, FormantInfo[] formants) {
        this.baseGain = baseGain;
        this.formants = formants;
        init(44100);
    }

    override void init(int samplesPerSecond) {
        /*
        for (float f = 0; f <= 3.14; f += 0.1) {
            float v = formantFunc(f);
            Log.d("formantFunc(", f, ")=", v);
        }
        for (float f = 0; f <= 1; f += 0.02) {
            float v = formantShape(f);
            Log.d("formantShape(", f, ")=", v);
        }
        */
        if (this.samplesPerSecond == samplesPerSecond)
            return;
        super.init(samplesPerSecond);
        int len = maxFreqStepCut;
        stepShift = 0;
        interpolationStepModShift = 8;
        maxFreqStepCutMul256 = maxFreqStepCut;
        // limit table size
        while (len > 4096) {
            len /= 2;
            maxFreqStep /= 2;
            maxFreqStepCut /= 2;
            minFreqStep /= 2;
            minFreqStepCut /= 2;
            stepShift++;
            interpolationStepModShift--;
        }
        table.length = len + 5;
        table[0..$] = 0;
        interpolate(table[minFreqStepCut .. minFreqStep], 0, baseGain);
        interpolate(table[minFreqStep .. maxFreqStep], baseGain, baseGain);
        interpolate(table[maxFreqStep .. maxFreqStepCut], baseGain, 0);
        for (int i = 0; i < formants.length; i++) {
            addFormant(formants[i]);
        }
    }

    private void applyFormant(int step, float gain) {
        if (step < minFreqStepCut || step > maxFreqStepCut || gain <= 0)
            return;
        gain += baseGain;
        if (step < minFreqStep) {
            gain *= 1 - (minFreqStep - step) / cast(float)(minFreqStep - minFreqStepCut);
        } else if (step > maxFreqStep) {
            gain *= 1 - (step - maxFreqStep) / cast(float)(maxFreqStepCut - maxFreqStep);
        }
        if (table.ptr[step] < gain)
            table.ptr[step] = gain;
    }

    private static float formantFunc(float v) {
        import std.math : cos;
        float f = (cos(v) + 1) / 2;
        f = f*f*f*f;
        return f;
    }
    /// for input values 0..1 return 1..0 shaped non-linearly
    private static float formantShape(float v) {
        immutable float point0x = 0.0f;
        immutable float point0y = formantFunc(point0x);
        immutable float point1x = 3.14f;
        immutable float point1y = formantFunc(point1x);
        immutable float diffX = (point1x - point0x);
        immutable float oneByDiffY = 1 / (point0y - point1y);
        // shape input value
        v = point0x + v * diffX;
        // apply function
        v = formantFunc(v);
        // shape output value
        v = (v - point1y) * oneByDiffY;
        return v;
    }

    private void addFormant(ref FormantInfo formant) {
        int step0 = freqToStep(formant.freq) >> stepShift;
        int maxstep = freqToStep(formant.freq * formant.width) >> stepShift;
        int minstep = freqToStep(formant.freq / formant.width) >> stepShift;
        float gain = formant.gain - baseGain;
        if (gain <= 0)
            return;
        applyFormant(step0, gain);
        int lenPlus = maxstep - step0;
        int lenMinus = step0 - minstep;
        for (int i = 1; i < lenPlus; i++) {
            float f = i / cast(float) lenPlus;
            f = formantShape(f); // 0..1
            float k = f * gain;
            applyFormant(step0 + i, k);
        }
        for (int i = 1; i < lenMinus; i++) {
            float f = (i / cast(float) lenMinus); // 0..1
            f = formantShape(f); // 0..1
            float k = f * gain;
            applyFormant(step0 - i, k);
        }
    }

    /// apply filter to value; returns false if frequency is above max cutoff
    override bool apply(int fundamentalFreqStep, int harmonicNumber, ref float value) {
        int stepMul256 = fundamentalFreqStep * harmonicNumber;
        int step = stepMul256 >> stepShift;
        if (step < minFreqStepCut || step > maxFreqStepCut) { // cutoff freq test
            value = 0;
            return step < maxFreqStepCut;
        }
        // calc interpolation coefficient 0..255
        int stepMod = stepMul256;
        if (interpolationStepModShift < 0)
            stepMod >>= -interpolationStepModShift;
        else if (interpolationStepModShift > 0)
            stepMod <<= interpolationStepModShift;
        stepMod &= 255;
        // get two values
        float v0 = table[step];
        float v1 = table[step + 1];
        // interpolate between values
        value *= (v0 * stepMod + v1 * (256 - stepMod)) / 256;
        return true;
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
    FormantFilter _formantFilter;
    float[] _origWavetable;
    float[] _wavetable;
    float _scale;
    float _offset;
    int _phase; // *256
    int _step;
    this(float[] wavetable, float scale = 1.0f, float offset = 0, immutable(float[]) formants = null, FormantFilter formantFilter = null) {
        _origWavetable = wavetable;
        _formantFilter = formantFilter;
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

class FormantFilteredOscillerF {
    FormantFilterBase _formantFilter;
    immutable(float[]) _formants;
    int[] _formantPhases;
    float[] _wavetable;
    this(immutable(float[]) formants, FormantFilterBase formantFilter) {
        _wavetable = SIN_TABLE_F;
        _formants = formants;
        _formantFilter = formantFilter;
        _formantPhases = new int[_formants.length];
    }
    /// move using particular step
    float step(int step_mul_256) {
        float res = 0;
        int formantStep = step_mul_256;
        for (int i = 0; i < _formants.length; i++) {
            int phase = _formantPhases[i];
            float formantGain = _formants[i];
            if (!_formantFilter.apply(step_mul_256, i + 1, formantGain))
                break; // frequency is too high
            res += formantGain * _wavetable[phase >> 8];
            // update formant phase by formant step
            _formantPhases[i] = (phase + formantStep) & WAVETABLE_SIZE_MASK_MUL_256;
            // next formant
            formantStep += step_mul_256;
        }
        return res;
    }
    /// reset phases to zero
    void resetPhase() {
        _formantPhases[0 .. $] = 0;
    }
}

enum ControllerId {
    PitchCorrection,
    VibratoAmount,
    VibratoFreq,
    Chorus,
    Reverb,
    Distortion,
    InstrumentVolume,
    AccompanimentVolume,
    None,
    YAxisController
}

struct Controller {
    ControllerId id;
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

class Instrument : AudioSource {

    protected string _id;
    protected dstring _name;
    protected ControllerId _yAxisControllerId = ControllerId.None;

    @property dstring name() { return _name; }
    @property string id() { return _id; }

    protected float _targetPitch = 1000; // Hz
    protected float _targetGain = 0; // 0..1
    //protected float _targetController1 = 0;

    protected int _attack = 20;
    protected int _release = 40;

    /// returns list of supported controllers
    immutable(Controller)[] getControllers() {
        return [];
    }

    /// returns true if controller value is set, false for unknown controller
    bool updateController(ControllerId id, int value) {
        return false;
    }

    void setYAxisController(ControllerId controllerId) {
        _yAxisControllerId = controllerId;
    }

    void setSynthParams(float pitch, float gain, float controller1) {

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
        //if (controller1 < 0.9)
        //    controller1 /= 0.9;
        //else
        //    controller1 = 1;
        if (_yAxisControllerId != ControllerId.None) {
            updateController(_yAxisControllerId, cast(int)((1 - controller1) * 1000));
        }
        //===========================================
        lock();
        scope(exit)unlock();
        //if (gain > 0.001) {
            _targetPitch = pitch;
            //_targetController1 = controller1;
        //}
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
    InterpolatorF _chorus;
    InterpolatorF _distortion;

    float _targetVibratoAmount = 0;
    float _targetVibratoFreq = 10;
    float _targetChorus = 0;
    float _targetDistortion = 0;

    protected override void calcParams() {
        // copy dynamic values
        _pitch.target = freqToStepMul256(_targetPitch);
        _gain.target = _targetGain;
        _chorus.target = _targetChorus;
        //_controller1.target = _targetController1;
        _vibratoAmount.target = _targetVibratoAmount;
        _vibratoFreq.target = freqToStepMul256(_targetVibratoFreq);
        _distortion.target = _targetDistortion;
    }

    protected void interpolateParams(int frameCount) {
        int frameMillis = frameCount < 10 ? 10 : 1000 * frameCount / samplesPerSecond;

        _gain.limitTargetChange(frameMillis, _attack, _release);
        _gain.init(frameCount);
        if (_gain.value < 0.001f) {
            _pitch.reset();
            _chorus.reset();
            _controller1.reset();
            _vibratoAmount.reset();
            _vibratoFreq.reset();
            _distortion.reset();
        }
        _pitch.init(frameCount);
        _chorus.init(frameCount);
        _controller1.init(frameCount);
        _vibratoAmount.init(frameCount);
        _vibratoFreq.init(frameCount);
        _distortion.init(frameCount);
    }

    override protected void onFormatChanged() {
    }

    /// returns true if controller value is set, false for unknown controller
    override bool updateController(ControllerId id, int value) {
        switch(id) {
            case ControllerId.VibratoAmount:
                // 0 .. 1/8 tone
                double lsAmount = ((value / 1000.0) / 4 / 12); // quarter_tone
                double n = exp2(lsAmount) - 1;
                _targetVibratoAmount = n; //exp2(log2(QUARTER_TONE) / 3 * value / 1000.0f);
                break;
            case ControllerId.VibratoFreq:
                // 1 .. 20 hz
                _targetVibratoFreq = 1 + value * 15 / 1000.0f;
                break;
            case ControllerId.Chorus:
                // 1 .. 20 hz
                _targetChorus = value / 1000.0f;
                break;
            case ControllerId.Distortion:
                _targetDistortion = value / 1000.0f;
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
        //_currentController1 = _targetController1;
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

void limitDistortion(ref float v) {
    if (v < -0.9f) {
        float delta = -v - 0.9f;
        // map delta 0..5 -> 0..0.1
        delta = log2(delta + 1) / 40;
        v = -0.9f - delta;
    } else if (v > 0.9f) {
        float delta = v - 0.9f;
        delta = log2(delta + 1) / 40;
        v = 0.9f + delta;
    }
        
}

class SineHarmonicWaveTable : InstrumentBaseF {
    OscillerF _tone1;
    OscillerF _chorusTone1;
    OscillerF _chorusTone2;
    OscillerF _chorusTone3;
    OscillerF _chorusTone4;
    OscillerF _chorusTone5;
    OscillerF _chorusTone6;
    OscillerF _chorusTone7;
    OscillerF _chorusTone8;
    OscillerF _vibrato1;
    OscillerF _chorusVibrato1;
    OscillerF _chorusVibrato2;
    OscillerF _chorusVibrato3;
    OscillerF _chorusVibrato4;
    OscillerF _chorusVibrato5;
    OscillerF _chorusVibrato6;
    OscillerF _chorusVibrato7;
    OscillerF _chorusVibrato8;
    float[] _wavetable;
    this(string id, dstring name, immutable(float[])formants = null) {
        _id = id;
        _name = name;
        _wavetable = SIN_TABLE_F;
        //immutable(float[]) formants = null;
        //_tone1 = new OscillerF(_wavetable, 1, 0, [0.7, 0.5, 0.3, 0.1, 0.05, 0.05]);
        _tone1 = new OscillerF(_wavetable, 1, 0, formants);
        _chorusTone1 = new OscillerF(_wavetable, 1, 0, formants);
        _chorusTone2 = new OscillerF(_wavetable, 1, 0, formants);
        _chorusTone3 = new OscillerF(_wavetable, 1, 0, formants);
        _chorusTone4 = new OscillerF(_wavetable, 1, 0, formants);
        _chorusTone5 = new OscillerF(_wavetable, 1, 0, formants);
        _chorusTone6 = new OscillerF(_wavetable, 1, 0, formants);
        _chorusTone7 = new OscillerF(_wavetable, 1, 0, formants);
        _chorusTone8 = new OscillerF(_wavetable, 1, 0, formants);
        _vibrato1 = new OscillerF(SIN_TABLE_F);
        _chorusVibrato1 = new OscillerF(SIN_TABLE_F, 0.00312, 1.000, [0.4, -0.3, 0.2, 0.1, 0.05, 0.02, 0.01, -0.01]);
        _chorusVibrato2 = new OscillerF(SIN_TABLE_F, 0.00323, 1.002, [0.2,-0.2, 0.2,-0.1, 0.3, 0.02, 0.01, -0.01]);
        _chorusVibrato3 = new OscillerF(SIN_TABLE_F, 0.00334, 0.999, [0.3,-0.3, 0.2,-0.2, 0.15, 0.02, 0.01, -0.01]);
        _chorusVibrato4 = new OscillerF(SIN_TABLE_F, 0.00315, 0.998, [0.45, 0.1, 0.2, 0.1, 0.02, 0.1, 0.01, -0.01]);
        _chorusVibrato5 = new OscillerF(SIN_TABLE_F, 0.00323, 1.000, [0.31, -0.2, 0.2, 0.3, 0.03, 0.1, 0.01, -0.01]);
        _chorusVibrato6 = new OscillerF(SIN_TABLE_F, 0.00331, 1.002, [0.42, 0.1, -0.2, 0.1, 0.01, 0.02, 0.01, -0.01]);
        _chorusVibrato7 = new OscillerF(SIN_TABLE_F, 0.00317, 0.999, [0.13, -0.3, 0.3, 0.1, 0.08, 0.02, 0.01, -0.01]);
        _chorusVibrato8 = new OscillerF(SIN_TABLE_F, 0.00323, 0.998, [0.21, 0.2, 0.2, 0.05, 0.02, 0.02, 0.01, -0.01]);
    }


    void resetPhase() {
        _tone1.resetPhase();
        _chorusTone1.resetPhase();
        _chorusTone2.resetPhase();
        _chorusTone3.resetPhase();
        _chorusTone4.resetPhase();
        _chorusTone5.resetPhase();
        _chorusTone6.resetPhase();
        _chorusTone7.resetPhase();
        _chorusTone8.resetPhase();
    }

    override protected void onFormatChanged() {
        resetPhase();
    }


    override bool loadData(int frameCount, ubyte * buf, ref uint flags) {
        {
            lock();
            scope(exit)unlock();
            calcParams();
        }

        interpolateParams(frameCount);



        if (_gain.isZero /* || _zeroVolume */) {
            // silent
            //flags = AUDIO_SOURCE_SILENCE_FLAG;
            generateSilence(frameCount, buf);
            resetPhase();
            return true;
        }

        bool hasVibrato = !_vibratoAmount.isZero;
        bool hasChorus = !_chorus.isZero;
        float chorusSample1 = 0;
        float chorusSample2 = 0;
        int chorusVibratoStep1 = freqToStepMul256( 1.2354124f);
        int chorusVibratoStep2 = freqToStepMul256( 3.53452334f);
        int chorusVibratoStep3 = freqToStepMul256( 2.1234523f);
        int chorusVibratoStep4 = freqToStepMul256( 0.7234543234f);
        int chorusVibratoStep5 = freqToStepMul256( 0.43453f);
        int chorusVibratoStep6 = freqToStepMul256( 2.334245746f);
        int chorusVibratoStep7 = freqToStepMul256( 1.984545f);
        int chorusVibratoStep8 = freqToStepMul256( 1.6332675f);
        for (int i = 0; i < frameCount; i++) {
            /// one step
            float gain = _gain.next;
            if (!_unityVolume)
                gain *= _volume;
            float controller1 = _controller1.next;

            int step = _pitch.next; //_vibrato0.stepMultiply(_step_mul_256, vibratoAmount1);
            // apply vibrato
            if (hasVibrato) {
                int vibratoStep = _vibratoFreq.next;
                float vibratoAmount = _vibratoAmount.next;
                float vibrato = _vibrato1.step(vibratoStep) * vibratoAmount + 1;
                step = cast(int)(step * vibrato);
            }

            if (hasChorus) {
                float chorus = _chorus.next;
                float chorusGain = gain * chorus * 7 / 10;
                gain -= chorusGain;
                float chorus1 = _chorusVibrato1.step(chorusVibratoStep1);
                float chorus2 = _chorusVibrato2.step(chorusVibratoStep2);
                float chorus3 = _chorusVibrato3.step(chorusVibratoStep3);
                float chorus4 = _chorusVibrato4.step(chorusVibratoStep4);
                float chorus5 = _chorusVibrato5.step(chorusVibratoStep5);
                float chorus6 = _chorusVibrato6.step(chorusVibratoStep6);
                float chorus7 = _chorusVibrato7.step(chorusVibratoStep7);
                float chorus8 = _chorusVibrato8.step(chorusVibratoStep8);
                int step1 = cast(int)(chorus1 * step);
                int step2 = cast(int)(chorus2 * step);
                int step3 = cast(int)(chorus3 * step);
                int step4 = cast(int)(chorus4 * step);
                int step5 = cast(int)(chorus5 * step);
                int step6 = cast(int)(chorus6 * step);
                int step7 = cast(int)(chorus7 * step);
                int step8 = cast(int)(chorus8 * step);
                chorus1 = _chorusTone1.step(step1);
                chorus2 = _chorusTone2.step(step2);
                chorus3 = _chorusTone3.step(step3);
                chorus4 = _chorusTone4.step(step4);
                chorus5 = _chorusTone5.step(step5);
                chorus6 = _chorusTone6.step(step6);
                chorus7 = _chorusTone7.step(step7);
                chorus8 = _chorusTone8.step(step8);
                chorusSample1 = (
                      -chorus1
                    + chorus2
                    + chorus5/3
                    + chorus6/4
                    - chorus7/4
                    - chorus8/3
                    + chorus3
                    + chorus4) / 6;
                chorusSample2 = (
                    chorus5
                    + chorus6
                    - chorus1/3
                    + chorus2/4
                    - chorus3/4
                    - chorus4/3
                    + chorus7
                    + chorus8) / 6;
            }

            float sample = _tone1.step(step);
            float sample1 = (sample + chorusSample1);
            float sample2 = (sample + chorusSample2);
            if (!_distortion.isZero) {
                float distort = 1 + _distortion.next * 5;
                sample1 *= distort;
                sample1 *= distort;
                limitDistortion(sample1);
                limitDistortion(sample2);
            }
            sample1 *= gain;
            sample2 *= gain;
            limitDistortion(sample1);
            limitDistortion(sample2);

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
        //res ~= Controller("chorus", "Chorus", 0, 1000, 300);
        //res ~= Controller("reverb", "Reverb", 0, 1000, 300);
        res ~= Controller(ControllerId.VibratoAmount, "Vibrato Amount", 0, 1000, 300);
        res ~= Controller(ControllerId.VibratoFreq, "Vibrato Freq", 0, 1000, 500);
        res ~= Controller(ControllerId.Chorus, "Chorus", 0, 1000, 0);
        res ~= Controller(ControllerId.Distortion, "Distortion", 0, 1000, 0);
        return cast(immutable(Controller)[])res;
    }

    /// returns true if controller value is set, false for unknown controller
    override bool updateController(ControllerId id, int value) {
        return super.updateController(id, value);
    }

}

class SineHarmonicFormants : InstrumentBaseF {
    FormantFilterBase _formantFilter;
    FormantFilteredOscillerF _tone1;
    FormantFilteredOscillerF _chorusTone1;
    FormantFilteredOscillerF _chorusTone2;
    FormantFilteredOscillerF _chorusTone3;
    FormantFilteredOscillerF _chorusTone4;
    FormantFilteredOscillerF _chorusTone5;
    FormantFilteredOscillerF _chorusTone6;
    FormantFilteredOscillerF _chorusTone7;
    FormantFilteredOscillerF _chorusTone8;
    OscillerF _vibrato1;
    OscillerF _chorusVibrato1;
    OscillerF _chorusVibrato2;
    OscillerF _chorusVibrato3;
    OscillerF _chorusVibrato4;
    OscillerF _chorusVibrato5;
    OscillerF _chorusVibrato6;
    OscillerF _chorusVibrato7;
    OscillerF _chorusVibrato8;
    this(string id, dstring name, immutable(float[])formants, float baseGain, FormantInfo[] filterFormants) {
        _id = id;
        _name = name;
        //_formantFilter = filterFormants.length ? new FormantFilter(baseGain, filterFormants) : new FormantFilterBase();
        _formantFilter = filterFormants.length 
                ? new VowelFormantFilter(80, filterFormants[0].freq, filterFormants[0].gain,
                                         filterFormants[1].freq, filterFormants[1].gain,
                                         filterFormants[2].freq, filterFormants[2].gain)
                : new FormantFilterBase();
        
        //immutable(float[]) formants = null;
        //_tone1 = new OscillerF(_wavetable, 1, 0, [0.7, 0.5, 0.3, 0.1, 0.05, 0.05]);
        _tone1 = new FormantFilteredOscillerF(formants, _formantFilter);
        _chorusTone1 = new FormantFilteredOscillerF(formants, _formantFilter);
        _chorusTone2 = new FormantFilteredOscillerF(formants, _formantFilter);
        _chorusTone3 = new FormantFilteredOscillerF(formants, _formantFilter);
        _chorusTone4 = new FormantFilteredOscillerF(formants, _formantFilter);
        _chorusTone5 = new FormantFilteredOscillerF(formants, _formantFilter);
        _chorusTone6 = new FormantFilteredOscillerF(formants, _formantFilter);
        _chorusTone7 = new FormantFilteredOscillerF(formants, _formantFilter);
        _chorusTone8 = new FormantFilteredOscillerF(formants, _formantFilter);
        _vibrato1 = new OscillerF(SIN_TABLE_F);
        _chorusVibrato1 = new OscillerF(SIN_TABLE_F, 0.00312, 1.000, [0.4, -0.3, 0.2, 0.1, 0.05, 0.02, 0.01, -0.01]);
        _chorusVibrato2 = new OscillerF(SIN_TABLE_F, 0.00323, 1.002, [0.2,-0.2, 0.2,-0.1, 0.3, 0.02, 0.01, -0.01]);
        _chorusVibrato3 = new OscillerF(SIN_TABLE_F, 0.00334, 0.999, [0.3,-0.3, 0.2,-0.2, 0.15, 0.02, 0.01, -0.01]);
        _chorusVibrato4 = new OscillerF(SIN_TABLE_F, 0.00315, 0.998, [0.45, 0.1, 0.2, 0.1, 0.02, 0.1, 0.01, -0.01]);
        _chorusVibrato5 = new OscillerF(SIN_TABLE_F, 0.00323, 1.000, [0.31, -0.2, 0.2, 0.3, 0.03, 0.1, 0.01, -0.01]);
        _chorusVibrato6 = new OscillerF(SIN_TABLE_F, 0.00331, 1.002, [0.42, 0.1, -0.2, 0.1, 0.01, 0.02, 0.01, -0.01]);
        _chorusVibrato7 = new OscillerF(SIN_TABLE_F, 0.00317, 0.999, [0.13, -0.3, 0.3, 0.1, 0.08, 0.02, 0.01, -0.01]);
        _chorusVibrato8 = new OscillerF(SIN_TABLE_F, 0.00323, 0.998, [0.21, 0.2, 0.2, 0.05, 0.02, 0.02, 0.01, -0.01]);
    }


    void resetPhase() {
        _tone1.resetPhase();
        _chorusTone1.resetPhase();
        _chorusTone2.resetPhase();
        _chorusTone3.resetPhase();
        _chorusTone4.resetPhase();
        _chorusTone5.resetPhase();
        _chorusTone6.resetPhase();
        _chorusTone7.resetPhase();
        _chorusTone8.resetPhase();
    }

    override protected void onFormatChanged() {
        resetPhase();
        _formantFilter.init(samplesPerSecond);
    }

    override bool loadData(int frameCount, ubyte * buf, ref uint flags) {
        {
            lock();
            scope(exit)unlock();
            calcParams();
        }

        interpolateParams(frameCount);

        if (_gain.isZero /* || _zeroVolume */) {
            // silent
            //flags = AUDIO_SOURCE_SILENCE_FLAG;
            generateSilence(frameCount, buf);
            resetPhase();
            return true;
        }

        bool hasVibrato = !_vibratoAmount.isZero;
        bool hasChorus = !_chorus.isZero;
        float chorusSample1 = 0;
        float chorusSample2 = 0;
        int chorusVibratoStep1 = freqToStepMul256( 1.2354124f);
        int chorusVibratoStep2 = freqToStepMul256( 3.53452334f);
        int chorusVibratoStep3 = freqToStepMul256( 2.1234523f);
        int chorusVibratoStep4 = freqToStepMul256( 0.7234543234f);
        int chorusVibratoStep5 = freqToStepMul256( 0.43453f);
        int chorusVibratoStep6 = freqToStepMul256( 2.334245746f);
        int chorusVibratoStep7 = freqToStepMul256( 1.984545f);
        int chorusVibratoStep8 = freqToStepMul256( 1.6332675f);
        for (int i = 0; i < frameCount; i++) {
            /// one step
            float gain = _gain.next;
            if (!_unityVolume)
                gain *= _volume;
            float controller1 = _controller1.next;

            int step = _pitch.next; //_vibrato0.stepMultiply(_step_mul_256, vibratoAmount1);
            // apply vibrato
            if (hasVibrato) {
                int vibratoStep = _vibratoFreq.next;
                float vibratoAmount = _vibratoAmount.next;
                float vibrato = _vibrato1.step(vibratoStep) * vibratoAmount + 1;
                step = cast(int)(step * vibrato);
            }

            if (hasChorus) {
                float chorus = _chorus.next;
                float chorusGain = gain * chorus * 7 / 10;
                gain -= chorusGain;
                float chorus1 = _chorusVibrato1.step(chorusVibratoStep1);
                float chorus2 = _chorusVibrato2.step(chorusVibratoStep2);
                float chorus3 = _chorusVibrato3.step(chorusVibratoStep3);
                float chorus4 = _chorusVibrato4.step(chorusVibratoStep4);
                float chorus5 = _chorusVibrato5.step(chorusVibratoStep5);
                float chorus6 = _chorusVibrato6.step(chorusVibratoStep6);
                float chorus7 = _chorusVibrato7.step(chorusVibratoStep7);
                float chorus8 = _chorusVibrato8.step(chorusVibratoStep8);
                int step1 = cast(int)(chorus1 * step);
                int step2 = cast(int)(chorus2 * step);
                int step3 = cast(int)(chorus3 * step);
                int step4 = cast(int)(chorus4 * step);
                int step5 = cast(int)(chorus5 * step);
                int step6 = cast(int)(chorus6 * step);
                int step7 = cast(int)(chorus7 * step);
                int step8 = cast(int)(chorus8 * step);
                chorus1 = _chorusTone1.step(step1);
                chorus2 = _chorusTone2.step(step2);
                chorus3 = _chorusTone3.step(step3);
                chorus4 = _chorusTone4.step(step4);
                chorus5 = _chorusTone5.step(step5);
                chorus6 = _chorusTone6.step(step6);
                chorus7 = _chorusTone7.step(step7);
                chorus8 = _chorusTone8.step(step8);
                chorusSample1 = (
                                 -chorus1
                                 + chorus2
                                 + chorus5/3
                                 + chorus6/4
                                 - chorus7/4
                                 - chorus8/3
                                 + chorus3
                                 + chorus4) / 6;
                chorusSample2 = (
                                 chorus5
                                 + chorus6
                                 - chorus1/3
                                 + chorus2/4
                                 - chorus3/4
                                 - chorus4/3
                                 + chorus7
                                 + chorus8) / 6;
            }

            float sample = _tone1.step(step);
            float sample1 = (sample + chorusSample1);
            float sample2 = (sample + chorusSample2);
            if (!_distortion.isZero) {
                float distort = 1 + _distortion.next * 5;
                sample1 *= distort;
                sample1 *= distort;
                limitDistortion(sample1);
                limitDistortion(sample2);
            }
            sample1 *= gain;
            sample2 *= gain;
            limitDistortion(sample1);
            limitDistortion(sample2);

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
        //res ~= Controller("chorus", "Chorus", 0, 1000, 300);
        //res ~= Controller("reverb", "Reverb", 0, 1000, 300);
        res ~= Controller(ControllerId.VibratoAmount, "Vibrato Amount", 0, 1000, 300);
        res ~= Controller(ControllerId.VibratoFreq, "Vibrato Freq", 0, 1000, 500);
        res ~= Controller(ControllerId.Chorus, "Chorus", 0, 1000, 0);
        res ~= Controller(ControllerId.Distortion, "Distortion", 0, 1000, 0);
        return cast(immutable(Controller)[])res;
    }

    /// returns true if controller value is set, false for unknown controller
    override bool updateController(ControllerId id, int value) {
        return super.updateController(id, value);
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
        res ~= Controller(ControllerId.Chorus, "Chorus", 0, 1000, 300);
        res ~= Controller(ControllerId.Reverb, "Reverb", 0, 1000, 300);
        res ~= Controller(ControllerId.VibratoAmount, "Vibrato Amount", 0, 1000, 300);
        res ~= Controller(ControllerId.VibratoFreq, "Vibrato Freq", 0, 1000, 500);
        return cast(immutable(Controller)[])res;
    }

    /// returns true if controller value is set, false for unknown controller
    override bool updateController(ControllerId id, int value) {
        return super.updateController(id, value);
    }

}

private __gshared Instrument[] _instrumentList;
/// get list of supported instruments
Instrument[] getInstrumentList() {
    if (!_instrumentList.length) {
        _instrumentList ~= new SineHarmonicWaveTable("sinewave", "Sine Wave", null);
        _instrumentList ~= new SineHarmonicWaveTable("strings", "Strings", [0.7, -0.6, 0.5, -0.4, 0.3, -0.2]);
        _instrumentList ~= new SineHarmonicWaveTable("strings2", "Strings 2", [0.5, -0.4, 0.3, -0.3, 0.25, -0.3, 0.15, -0.15, 0.1, -0.05, 0.04, -0.03, 0.02, -0.01]);
        _instrumentList ~= new SineHarmonicWaveTable("brass", "Brass", [0.1, -0.3, 0.4, -0.4, 0.6, -0.6, 0.8, -0.8, 0.4, -0.35, 0.2, -0.1, 0.05, -0.02]);
        _instrumentList ~= new SineHarmonicFormants("voiceAh", "Voice Ah", 
                                                    //[0.9f, -0.85f, +0.8f, -0.75f, +0.7f, -0.65f, 0.6f, -0.55f, 0.5f, -0.45f, 0.4f, -0.4f, 0.35f, -0.30f, 0.25f, -0.20f, 0.20f, -0.20f, 0.20f, -0.20f, 0.20f, -0.20f, 0.20f, -0.20f],
                                                    //[0.9f, -0.9f, 0.9f, -0.9f, 0.9f, -0.9f, 0.9f, -0.9f, 0.9f, -0.9f, 0.9f, -0.9f, 0.9f, -0.9f, 0.9f, -0.9f, 0.9f, -0.9f, 0.9f, -0.9f, 0.9f, -0.9f, 0.9f, -0.9f, 0.9f, -0.9f, 0.9f, -0.9f, 0.9f, -0.9f, 0.9f, -0.9f, 0.9f, -0.9f, 0.9f, -0.9f, 0.9f, -0.9f],
                                                    [0.8f, -0.6f, +0.4f, -0.3f, +0.25f, -0.2f, 0.15f, -0.12f, 0.10f, -0.08f, 0.07f, -0.06f, 0.05f, -0.04f, 0.03f, -0.02f],
                                                    0.1f,
                                                    [FormantInfo(740, 1.0f, 1.4f), FormantInfo(1180, 0.9f, 1.4f), FormantInfo(2640, 0.3f, 1.4f)]
                                                    //[FormantInfo(700, 1.0f, 1.7f), FormantInfo(1100, 0.8f, 1.8f), FormantInfo(2600, 0.4f, 1.9f)]
                                                    );
        _instrumentList ~= new SineHarmonicFormants("voiceAh2", "Voice Ah2", [0.05f, -0.1f, 0.18f, -0.25f, 0.28f, -0.65f, 0.55f, -0.22f, 0.23f, -0.45f, 0.25f, -0.18f, 0.15f, -0.10f, 0.09f, -0.08f, 0.07f, -0.07f, 0.08f, -0.09f, 0.10f, -0.15f, 0.20f, -0.18f, 0.10f, -0.08f, 0.06f, -0.05f],
                                                    1,
                                                    //[FormantInfo(700, 1.0f, 1.7f), FormantInfo(1100, 0.8f, 1.8f), FormantInfo(2600, 0.4f, 1.9f)]
                                                    //[FormantInfo(740, 1.0f, 1.4f), FormantInfo(1180, 0.9f, 1.4f), FormantInfo(2640, 0.3f, 1.4f)]
                                                    null
                                                    );
        _instrumentList ~= new MyAudioSource();
    }
    return _instrumentList;
}
