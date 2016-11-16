/**
    Filters.

    Based on code from STK library
         https://github.com/thestk/stk
         https://ccrma.stanford.edu/software/stk/
*/
module soundtab.audio.filters;

import std.math : log2, exp2, sin, cos, pow, PI;

immutable float TWO_PI = PI * 2;


//float linearToDb(float f) {
//
//}
/// decibels to linear
float dbToLinear(float f) {
    return pow(10.0f, f / 20);
}


/// digital filter - base interface
interface Filter {
    // set sample rate (frames per second)
    void setSampleRate(int samplesPerSecond);
    // feed single input sample and get filtered result
    float tick(float input);
    // clear state
    void clear();
}

abstract class FilterBase  : Filter {
    int _sampleRate = 44100;
    void setSampleRate(int samplesPerSecond) {
        _sampleRate = samplesPerSecond;
    }
}

class OnePole : FilterBase {
    this(float thePole = 0.9f) {
        setPole(thePole);
    }
    void setPole(float thePole) {
        // Normalize coefficients for peak unity gain.
        if (thePole > 0.0f)
            _b[0] = 1.0f - thePole;
        else
            _b[0] = 1.0f + thePole;

        _a[1] = -thePole;
    }
    float tick(float input) {
        _inputs[0] = _gain * input;
        _lastFrame = _b[0] * _inputs[0] - _a[1] * _outputs[1];
        _outputs[1] = _lastFrame;
        return _lastFrame;
    }
    // clear state
    void clear() {
        _inputs = [0,0];
        _outputs = [0,0];
        _lastFrame = 0;
    }
    float _gain = 1.0f;
    float[2] _a = [0,0];
    float[2] _b = [0,0];
    float[2] _inputs = [0,0];
    float[2] _outputs = [0,0];
    float _lastFrame = 0;
}

class OneZero : FilterBase {
    this(float theZero = -1.0f) {
        setZero(theZero);
    }
    void setZero(float theZero) {
        // Normalize coefficients for unity gain.
        if ( theZero > 0.0 )
            _b[0] = 1 / (1 + theZero);
        else
            _b[0] = 1 / (1 - theZero);

        _b[1] = -theZero * _b[0];
    }
    float tick(float input) {
        _inputs[0] = _gain * input;
        _lastFrame = _b[1] * _inputs[1] + _b[0] * _inputs[0];
        _inputs[1] = _inputs[0];
        return _lastFrame;
    }
    // clear state
    void clear() {
        _inputs = [0,0];
        _outputs = [0,0];
        _lastFrame = 0;
    }
    float _gain = 1.0f;
    float[2] _a = [0,0];
    float[2] _b = [0,0];
    float[2] _inputs = [0,0];
    float[2] _outputs = [0,0];
    float _lastFrame = 0;
}

class Formant  : FilterBase {
    this() {
    }
    void setParams(float frequency, float radius, float gain) {
        _gain = gain;
        setResonance(frequency, radius);
    }
    override void setSampleRate(int samplesPerSecond) {
        super.setSampleRate(samplesPerSecond);
        setResonance(_frequency, _radius);
    }
    void setResonance(float frequency, float radius) {
        _radius = radius;
        _frequency = frequency;
        _a[2] = radius * radius;
        _a[1] = -2.0f * radius * cos( TWO_PI * frequency / _sampleRate );
        // Use zeros at +- 1 and normalize the filter peak gain.
        _b[0] = 0.5 - 0.5 * _a[2];
        _b[1] = 0.0;
        _b[2] = -_b[0];
    }
    float tick(float input) {
        _inputs[0] = _gain * input;
        _lastFrame = _b[0] * _inputs[0] + _b[1] * _inputs[1] + _b[2] * _inputs[2];
        _lastFrame -= _a[2] * _outputs[2] + _a[1] * _outputs[1];
        _inputs[2] = _inputs[1];
        _inputs[1] = _inputs[0];
        _outputs[2] = _outputs[1];
        _outputs[1] = _lastFrame;
        return _lastFrame;
    }
    // clear state
    void clear() {
        _inputs = [0,0,0,0];
        _outputs = [0,0,0,0];
        _lastFrame = 0;
    }
    float _frequency = 400;
    float _radius = 0;
    float _gain = 1.0f;
    float[4] _a = [0,0,0,0];
    float[4] _b = [0,0,0,0];
    float[4] _inputs = [0,0,0,0];
    float[4] _outputs = [0,0,0,0];
    float _lastFrame = 0;
}

class PhonemeFormantsFilter : Filter {
    Formant[4] _formants;
    float _formantFreqMult;
    this(PhonemeType phoneme = PhonemeType.ahh, float formantFreqMult = 1) {
        _formantFreqMult = formantFreqMult;
        for(int i = 0; i < 4; i++)
            _formants[i] = new Formant();
        setPhoneme(phoneme, formantFreqMult);
    }

    void setPhoneme(PhonemeType type, float formantFreqMult = 1) {
        _formantFreqMult = formantFreqMult;
        for (int i = 0; i < 4; i ++) {
            _formants[i].setParams(_formantFreqMult * phonemes[type][i].frequency, phonemes[type][i].radius, dbToLinear(phonemes[type][i].gainDb));
        }
    }

    void setSampleRate(int samplesPerSecond) {
        for(int i = 0; i < 4; i++)
            _formants[i].setSampleRate(samplesPerSecond);
    }

    float tick(float input) {
        float temp = input;

        _lastFrame = _formants[0].tick(temp);
        _lastFrame += _formants[1].tick(temp);
        _lastFrame += _formants[2].tick(temp);
        _lastFrame += _formants[3].tick(temp);
        return _lastFrame;
    }
    // clear state
    void clear() {
        for(int i = 0; i < 4; i++)
            _formants[i].clear();
    }
    float _lastFrame = 0;
}

struct FormantParams {
    float frequency;
    float radius;
    float gainDb;
}

alias PhonemeParams = FormantParams[4];

enum PhonemeType {
    eee,
    ihh,
    ehh,
    aaa,

    ahh,
    aww,
    ohh,
    uhh,

    uuu,
    ooo,
    rrr,
    lll,
}

PhonemeParams[12] phonemes = [
    [ 
        //// PhonemeType.eee (beet)
        FormantParams(273, 0.996,  10),
        FormantParams(2086, 0.945, -16),
        FormantParams(2754, 0.979, -12),
        FormantParams(3270, 0.440, -17)
    ],
    [
        //// PhonemeType.ihh (bit)
        FormantParams(385, 0.987,  10),
        FormantParams(2056, 0.930, -20),
        FormantParams(2587, 0.890, -20),
        FormantParams(3150, 0.400, -20)
    ],
    [
        //// PhonemeType.ehh (bet)
        FormantParams(515, 0.977,  10),
        FormantParams(1805, 0.810, -10),
        FormantParams(2526, 0.875, -10),
        FormantParams(3103, 0.400, -13)
    ],
    [
        //// PhonemeType.aaa (bat)
        FormantParams(773, 0.950,  10),
        FormantParams(1676, 0.830,  -6),
        FormantParams(2380, 0.880, -20),
        FormantParams(3027, 0.600, -20)
    ],
    [
        //// PhonemeType.ahh (father)
        FormantParams(770, 0.950,   0),
        FormantParams(1153, 0.970,  -9),
        FormantParams(2450, 0.780, -29),
        FormantParams(3140, 0.800, -39)
    ],
    [
        //// PhonemeType.aww (bought)
        FormantParams(637, 0.910,   0),
        FormantParams(895, 0.900,  -3),
        FormantParams(2556, 0.950, -17),
        FormantParams(3070, 0.910, -20)
    ],
    [ 
        //// PhonemeType.ohh (bone)  NOTE::  same as aww (bought)
        FormantParams(637, 0.910,   0),
        FormantParams(895, 0.900,  -3),
        FormantParams(2556, 0.950, -17),
        FormantParams(3070, 0.910, -20)
    ],
    [
        //// PhonemeType.uhh (but)
        FormantParams(561, 0.965,   0),
        FormantParams(1084, 0.930, -10),
        FormantParams(2541, 0.930, -15),
        FormantParams(3345, 0.900, -20)
    ],
    [
        //// PhonemeType.uuu (foot)
        FormantParams(515, 0.976,   0),
        FormantParams(1031, 0.950,  -3),
        FormantParams(2572, 0.960, -11),
        FormantParams(3345, 0.960, -20)
    ],
    [
        //// PhonemeType.ooo (boot)
        FormantParams(349, 0.986, -10),
        FormantParams(918, 0.940, -20),
        FormantParams(2350, 0.960, -27),
        FormantParams(2731, 0.950, -33)
    ],
    [
        //// PhonemeType.rrr (bird)
        FormantParams(394, 0.959, -10),
        FormantParams(1297, 0.780, -16),
        FormantParams(1441, 0.980, -16),
        FormantParams(2754, 0.950, -40)
    ],
    [
        //// PhonemeType.lll (lull)
        FormantParams(462, 0.990,  +5),
        FormantParams(1200, 0.640, -10),
        FormantParams(2500, 0.200, -20),
        FormantParams(3000, 0.100, -30)
    ],
];
