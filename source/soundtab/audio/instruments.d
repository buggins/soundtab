module soundtab.audio.instruments;

import dlangui.core.logger;
import soundtab.ui.noteutil;
import soundtab.audio.audiosource;
import soundtab.audio.filters;
import soundtab.audio.generators;
import std.math : log2, exp2, sin, cos, pow, PI;

/// Standard controller IDs
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
    YAxisController,
    Noise
}


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


struct Controller {
    ControllerId id;
    dstring name;
    int minValue;
    int maxValue;
    int value;
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
    InterpolatorF _noise;

    float _targetVibratoAmount = 0;
    float _targetVibratoFreq = 10;
    float _targetChorus = 0;
    float _targetDistortion = 0;
    float _targetNoise = 0;

    protected override void calcParams() {
        // copy dynamic values
        _pitch.target = freqToStepMul256(_targetPitch);
        _gain.target = _targetGain;
        _chorus.target = _targetChorus;
        //_controller1.target = _targetController1;
        _vibratoAmount.target = _targetVibratoAmount;
        _vibratoFreq.target = freqToStepMul256(_targetVibratoFreq);
        _distortion.target = _targetDistortion;
        _noise.target = _targetNoise;
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
            _noise.reset();
        }
        _pitch.init(frameCount);
        _chorus.init(frameCount);
        _controller1.init(frameCount);
        _vibratoAmount.init(frameCount);
        _vibratoFreq.init(frameCount);
        _distortion.init(frameCount);
        _noise.init(frameCount);
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
            case ControllerId.Noise:
                // 1 .. 20 hz
                _targetNoise = value / 1000.0f;
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

float[] mulSequence(float firstValue, float mult, int len) {
    float[] res = new float[len];
    float value = firstValue;
    for (int i = 0; i < len; i++) {
        res[i] = value;
        value *= mult;
    }
    return res;
}

class PhonemeOscillerF : OscillerF {
    PhonemeFormantsFilter _formantFilter;
    OneZero _onezero;
    OnePole _onepole;
    Noise _noise;
    this(PhonemeType phoneme, float formantFreqMult = 1) {
        super(SIN_TABLE_F, 1, 0, mulSequence(1, -0.85, 40).dup);//VOICE_IMPULSE_F SAW_TABLE_F VOICE_EXPERIMENTAL_F
        //super(VOICE_EXPERIMENTAL_F);//VOICE_IMPULSE_F SAW_TABLE_F VOICE_EXPERIMENTAL_F VOICE_EX_1_F
        _formantFilter = new PhonemeFormantsFilter(phoneme, formantFreqMult);
        _onezero = new OneZero();
        _onepole = new OnePole();
        _onezero.setZero( -0.9 );
        _onepole.setPole( 0.9 );
    }
    void setPhoneme(PhonemeType phoneme, float formantFreqMult = 1) {
        _formantFilter.setPhoneme(phoneme, formantFreqMult);
    }
    void setSampleRate(int samplesPerSecond) {
        _formantFilter.setSampleRate(samplesPerSecond);
    }
    float step(int step_mul_256, float noiseGain) {
        int oldPhase = _phase;
        float value = super.step(step_mul_256);
        //if (oldPhase > _phase)
        //    value = 1;
        //else
        //    value = 0;
        //if ((oldPhase >> 8) < WAVETABLE_SIZE / 12) {
        //    if (noiseGain > 0)
        //        value += _noise.tick() * noiseGain;
        //}

        value = _onepole.tick( _onezero.tick( value ) );

        value = _formantFilter.tick(value);
        return value;
    }
}

class PhonemeSynth : InstrumentBaseF {
    PhonemeOscillerF _tone1;
    PhonemeOscillerF _chorusTone1;
    PhonemeOscillerF _chorusTone2;
    PhonemeOscillerF _chorusTone3;
    PhonemeOscillerF _chorusTone4;
    PhonemeOscillerF _chorusTone5;
    PhonemeOscillerF _chorusTone6;
    PhonemeOscillerF _chorusTone7;
    PhonemeOscillerF _chorusTone8;
    OscillerF _vibrato1;
    OscillerF _chorusVibrato1;
    OscillerF _chorusVibrato2;
    OscillerF _chorusVibrato3;
    OscillerF _chorusVibrato4;
    OscillerF _chorusVibrato5;
    OscillerF _chorusVibrato6;
    OscillerF _chorusVibrato7;
    OscillerF _chorusVibrato8;
    this(string id, dstring name, PhonemeType phoneme) {
        _id = id;
        _name = name;
        _tone1 = new PhonemeOscillerF(phoneme);
        _chorusTone1 = new PhonemeOscillerF(phoneme, 1.01f);
        _chorusTone2 = new PhonemeOscillerF(phoneme, 1.02f);
        _chorusTone3 = new PhonemeOscillerF(phoneme, 1.1f);
        _chorusTone4 = new PhonemeOscillerF(phoneme, 1.04f);
        _chorusTone5 = new PhonemeOscillerF(phoneme, 1.01f);
        _chorusTone6 = new PhonemeOscillerF(phoneme, 1.025f);
        _chorusTone7 = new PhonemeOscillerF(phoneme, 1.035f);
        _chorusTone8 = new PhonemeOscillerF(phoneme, 1.05f);
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

    void setPhoneme(PhonemeType phoneme) {
        _tone1.setPhoneme(phoneme);
        _chorusTone1.setPhoneme(phoneme, 1.1f);
        _chorusTone2.setPhoneme(phoneme, 1.2f);
        _chorusTone3.setPhoneme(phoneme, 1.3f);
        _chorusTone4.setPhoneme(phoneme, 1.4f);
        _chorusTone5.setPhoneme(phoneme, 1.1f);
        _chorusTone6.setPhoneme(phoneme, 1.25f);
        _chorusTone7.setPhoneme(phoneme, 1.35f);
        _chorusTone8.setPhoneme(phoneme, 1.05f);
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
        _tone1.setSampleRate(samplesPerSecond);
        _chorusTone1.setSampleRate(samplesPerSecond);
        _chorusTone2.setSampleRate(samplesPerSecond);
        _chorusTone3.setSampleRate(samplesPerSecond);
        _chorusTone4.setSampleRate(samplesPerSecond);
        _chorusTone5.setSampleRate(samplesPerSecond);
        _chorusTone6.setSampleRate(samplesPerSecond);
        _chorusTone7.setSampleRate(samplesPerSecond);
        _chorusTone8.setSampleRate(samplesPerSecond);
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

            float noiseGain = _noise.next;

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
                chorus1 = _chorusTone1.step(step1, noiseGain);
                chorus2 = _chorusTone2.step(step2, noiseGain);
                chorus3 = _chorusTone3.step(step3, noiseGain);
                chorus4 = _chorusTone4.step(step4, noiseGain);
                chorus5 = _chorusTone5.step(step5, noiseGain);
                chorus6 = _chorusTone6.step(step6, noiseGain);
                chorus7 = _chorusTone7.step(step7, noiseGain);
                chorus8 = _chorusTone8.step(step8, noiseGain);
                chorusSample1 = (
                                 -chorus1
                                 + chorus2
                                 + chorus5/2
                                 + chorus6/3
                                 - chorus7/3
                                 - chorus8/2
                                 + chorus3
                                 + chorus4);
                chorusSample2 = (
                                 chorus5
                                 + chorus6
                                 - chorus1/2
                                 + chorus2/3
                                 - chorus3/3
                                 - chorus4/2
                                 + chorus7
                                 + chorus8);
            }

            float sample = _tone1.step(step, noiseGain);
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
        res ~= Controller(ControllerId.VibratoAmount, "Vibrato Amount", 0, 1000, 300);
        res ~= Controller(ControllerId.VibratoFreq, "Vibrato Freq", 0, 1000, 500);
        res ~= Controller(ControllerId.Chorus, "Chorus", 0, 1000, 1000);
        //res ~= Controller(ControllerId.Noise, "Noise", 0, 1000, 0);
        res ~= Controller(ControllerId.Distortion, "Distortion", 0, 1000, 0);
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
        _instrumentList ~= new PhonemeSynth("voiceAaa", "Voice Aaa", PhonemeType.aaa);
        _instrumentList ~= new PhonemeSynth("voiceIhh", "Voice Ihh", PhonemeType.ihh);
        _instrumentList ~= new PhonemeSynth("voiceEhh", "Voice Ehh", PhonemeType.ehh);
        _instrumentList ~= new PhonemeSynth("voiceEee", "Voice Eee", PhonemeType.eee);
        _instrumentList ~= new PhonemeSynth("voiceAhh", "Voice Ahh", PhonemeType.ahh);
        _instrumentList ~= new PhonemeSynth("voiceAww", "Voice Aww", PhonemeType.aww);
        _instrumentList ~= new PhonemeSynth("voiceOhh", "Voice Ohh", PhonemeType.ohh);
        _instrumentList ~= new PhonemeSynth("voiceUhh", "Voice Uhh", PhonemeType.uhh);
        _instrumentList ~= new PhonemeSynth("voiceUuu", "Voice Uuu", PhonemeType.uuu);
        _instrumentList ~= new PhonemeSynth("voiceOoo", "Voice Ooo", PhonemeType.ooo);
        _instrumentList ~= new PhonemeSynth("voiceRrr", "Voice Rrr", PhonemeType.rrr);
        _instrumentList ~= new PhonemeSynth("voiceLll", "Voice Lll", PhonemeType.lll);
    }
    return _instrumentList;
}
