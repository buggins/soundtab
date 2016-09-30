module soundtab.audio.instruments;

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

class Osciller {
    int[] _origWavetable;
    int[] _wavetable;
    int _phase; // *256
    int _step;
    this(int[] wavetable, int scale = WAVETABLE_SCALE, int offset = 0) {
        _origWavetable = wavetable;
        rescale(scale, offset);
    }
    void rescale(int scale = WAVETABLE_SCALE, int offset = 0) {
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
    // use current step value
    int step() {
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

class AudioSource {

    protected SampleFormat sampleFormat = SampleFormat.float32;
    protected int samplesPerSecond = 44100;
    protected int channels = 2;
    protected int bitsPerSample = 16;
    protected int blockAlign = 4;

    void setFormat(SampleFormat format, int channels, int samplesPerSecond, int bitsPerSample, int blockAlign) {
        this.sampleFormat = format;
        this.channels = channels;
        this.samplesPerSecond = samplesPerSecond;
        this.bitsPerSample = bitsPerSample;
        this.blockAlign = blockAlign;
    }

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

class Instrument : AudioSource {

    protected double _targetPitch = 1000; // Hz
    protected double _targetGain = 0; // 0..1
    protected double _targetController1 = 0;

    protected int _attack = 20;
    protected int _release = 40;

    void setSynthParams(double pitch, double gain, double controller1) {
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
        _targetPitch = pitch;
        _targetGain = gain;
        _targetController1 = controller1;
    }
}

class MyAudioSource : Instrument {


    double _currentPitch = 0; // Hz
    double _currentGain = 0; // 0..1
    double _currentController1 = 0; // 0..1


    int[] _wavetable;

    int _phase_mul_256 = 0;

    int _target_step_mul_256 = 0; // step*256 inside wavetable to generate requested frequency
    int _target_gain_mul_65536 = 0;
    int _target_controller1_mul_65536 = 0;
    int _step_mul_256 = 0; // step*256 inside wavetable to generate requested frequency
    int _gain_mul_65536 = 0;
    int _controller1_mul_65536 = 0;

    Osciller _vibrato1;
    Osciller _vibrato2;
    Osciller _vibrato3;
    Osciller _vibrato4;
    Osciller _vibrato21;
    Osciller _vibrato22;
    Osciller _vibrato23;
    Osciller _vibrato24;
    Osciller _tone1;
    Osciller _tone2;
    Osciller _tone3;
    Osciller _tone4;
    Osciller _tone21;
    Osciller _tone22;
    Osciller _tone23;
    Osciller _tone24;

    this() {
        int[] sintable = genWaveTableSin();
        int[] square = genWaveTableSquare();
        _wavetable = sintable; //genWaveTableSquare(); //genWaveTableSin();
        //_wavetable = genWaveTableSquare(); //genWaveTableSin();
        _vibrato1 = new Osciller(sintable, 500, 0x10000);
        _vibrato2 = new Osciller(sintable, 600, 0x10000);
        _vibrato3 = new Osciller(sintable, 700, 0x10000);
        _vibrato4 = new Osciller(sintable, 1000, 0x10000);
        _vibrato21 = new Osciller(sintable, 700, 0x10000);
        _vibrato22 = new Osciller(sintable, 800, 0x10000);
        _vibrato23 = new Osciller(sintable, 900, 0x10000);
        _vibrato24 = new Osciller(sintable, 700, 0x10000);
        _tone1 = new Osciller(_wavetable);
        _tone2 = new Osciller(_wavetable);
        _tone3 = new Osciller(_wavetable);
        _tone4 = new Osciller(_wavetable);
        _tone21 = new Osciller(_wavetable);
        _tone22 = new Osciller(_wavetable);
        _tone23 = new Osciller(_wavetable);
        _tone24 = new Osciller(_wavetable);
    }

    override void setFormat(SampleFormat format, int channels, int samplesPerSecond, int bitsPerSample, int blockAlign) {
        super.setFormat(format, channels, samplesPerSecond, bitsPerSample, blockAlign);
        _phase_mul_256 = 0;
        calcParams();
        _vibrato1.setPitch(5, samplesPerSecond);
        _vibrato2.setPitch(7.12367, samplesPerSecond);
        _vibrato3.setPitch(9.37615263, samplesPerSecond);
        _vibrato4.setPitch(3.78431, samplesPerSecond);
        _vibrato21.setPitch(4.65321, samplesPerSecond);
        _vibrato22.setPitch(6.5432, samplesPerSecond);
        _vibrato23.setPitch(11.4321, samplesPerSecond);
        _vibrato24.setPitch(7.36345, samplesPerSecond);
    }

    void calcParams() {
        _currentPitch = _targetPitch;
        _currentGain = _targetGain;
        _currentController1 = _targetController1;
        double onePeriodSamples = samplesPerSecond / _currentPitch;
        double step = WAVETABLE_SIZE / onePeriodSamples;
        _target_step_mul_256 = cast(int)(step * 256);
        _target_gain_mul_65536 = cast(int)(_currentGain * 0x10000);
        _target_controller1_mul_65536 = cast(int)(_currentController1 * 0x10000);
    }


    //int durationCounter = 100;

    override bool loadData(int frameCount, ubyte * buf, ref uint flags) {
        calcParams();

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

        Log.d("LoadData frameCount=", frameCount, " lastGain=", lastGain, " newGain=", _gain_mul_65536);

        for (int i = 0; i < frameCount; i++) {
            /// one step
            int gain = lastGain + (_gain_mul_65536 - lastGain) * i / frameCount;
            int controller1 = lastController1 + (_controller1_mul_65536 - lastController1) * i / frameCount;
            int gain_vibrato = _vibrato4.step();

            int gain1 = cast(int)((cast(long)gain * gain_vibrato) >> 16); // left
            int gain2 = cast(int)((cast(long)gain * (0x20000 - gain_vibrato)) >> 16); // right

            int step1 = cast(int)((cast(long)_step_mul_256 * _vibrato1.step()) >> 16);
            int step2 = cast(int)((cast(long)_step_mul_256 * _vibrato2.step()) >> 16);
            int step3 = cast(int)((cast(long)_step_mul_256 * _vibrato3.step()) >> 16);
            int step4 = cast(int)((cast(long)_step_mul_256 * _vibrato4.step()) >> 16);

            int step21 = cast(int)((cast(long)_step_mul_256 * _vibrato21.step()) >> 16);
            int step22 = cast(int)((cast(long)_step_mul_256 * _vibrato22.step()) >> 16);
            int step23 = cast(int)((cast(long)_step_mul_256 * _vibrato23.step()) >> 16);
            int step24 = cast(int)((cast(long)_step_mul_256 * _vibrato24.step()) >> 16);

            int wt_value1 = _tone1.step(step1) * 1 / 1;
            int wt_value2 = _tone2.step(step2) * 1 / 2;
            int wt_value3 = _tone3.step(step3) * 1 / 3;
            int wt_value4 = _tone4.step(step3) * 1 / 3;

            int wt_value21 = _tone1.step(step21) * 1 / 1;
            int wt_value22 = _tone2.step(step22) * 1 / 2;
            int wt_value23 = _tone3.step(step23) * 1 / 3;
            int wt_value24 = _tone3.step(step23) * 1 / 3;

            int inv_controller1 = 0x10000 - controller1;
            int wt_value_1 = ((wt_value1 + wt_value2 + wt_value3) * inv_controller1 >> 16) + (wt_value4 * controller1 >> 16);
            int wt_value_2 = ((wt_value21 + wt_value22 + wt_value23) * inv_controller1 >> 16) + (wt_value24 * controller1 >> 16);

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
        }

        // TODO
        //durationCounter--;
        flags = 0; //durationCounter <= 0 ? AUDCLNT_BUFFERFLAGS.AUDCLNT_BUFFERFLAGS_SILENT : 0;
        return true;
    }
}

