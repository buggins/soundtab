module soundtab.audio.wavefile;

immutable int PERIOD_FFT_SIZE = 256;
struct PeriodInfo {
    float startTime = 0;
    float periodTime = 0;
    float ampPlus = 0;
    float ampMinus = 0;
    float energy = 0;
    float[PERIOD_FFT_SIZE / 2] fftAmp;
    float[PERIOD_FFT_SIZE / 2] fftPhase;
    @property float middleTime() {
        return startTime + periodTime / 2;
    }
    @property float endTime() {
        return startTime + periodTime;
    }
}

class WaveFile {
    string filename;
    int channels;
    int sampleRate;
    int frames;
    float[] data;

    float[] marks;
    float[] negativeMarks;

    PeriodInfo[] periods;

    float middleFrequency = 0;
    float[] frequencies; // multipliers relative to middle frequency, to get real frequency, use frequency[i]*middleFrequency
    float minFrequencyK = 0;
    float maxFrequencyK = 0;

    this() {
    }

    this(WaveFile v, bool forceMono = false) {
        channels = v.channels;
        sampleRate = v.sampleRate;
        frames = v.frames;
        if (channels == 1 || !forceMono) {
            // just duplicate
            data = v.data.dup;
        } else {
            // take left channel only
            data = new float[frames];
            for (int i = 0; i < frames; i++)
                data[i] = v.data[i * channels];
            channels = 1;
        }
        if (v.marks.length)
            marks = v.marks.dup;
        middleFrequency = v.middleFrequency;
        if (v.frequencies.length)
            frequencies = v.frequencies.dup; // multipliers relative to middle frequency, to get real frequency, use frequency[i]*middleFrequency
        minFrequencyK = v.minFrequencyK;
        maxFrequencyK = v.maxFrequencyK;
    }

    void fill(float value) {
        data[0..$] = value;
    }

    void setMarks(float[] _marks, float[] _negativeMarks = null) {
        marks = _marks;
        negativeMarks = _negativeMarks;
    }

    void fillPeriodsFromMarks() {
        periods = null;
        if (marks.length > 1) {
            periods.length = marks.length - 1;
            for (int i = 0; i + 1 < marks.length; i++) {
                fillPeriodInfo(periods[i], marks[i], marks[i + 1]);
            }
        }
    }

    immutable bool sqEnergy = true;
    float[] amplitudes;
    /// returns sign of biggest amplitude
    int fillAmplitudesFromPeriods() {
        amplitudes = null;
        if (periods.length > 1) {
            float[] ampPlus = new float[frames];
            float[] ampMinus = new float[frames];
            float[] energy = new float[frames];
            int prevPeriodMiddleFrame = 0;
            float prevPeriodAmpPlus = periods[0].ampPlus;
            float prevPeriodAmpMinus = periods[0].ampMinus;
            float prevPeriodEnergy = periods[0].energy;
            float avgPeriod = 0;
            for (int i = 0; i < periods.length; i++) {
                avgPeriod += periods[i].periodTime;
                int middleFrame = timeToFrame(periods[i].middleTime);
                float currentAmpPlus = periods[i].ampPlus;
                float currentAmpMinus = periods[i].ampMinus;
                float currentEnergy = periods[i].energy;
                int frameLen = middleFrame - prevPeriodMiddleFrame;
                for (int j = 0; j < frameLen; j++) {
                    ampPlus[prevPeriodMiddleFrame + j] = prevPeriodAmpPlus + (currentAmpPlus - prevPeriodAmpPlus) * j / frameLen;
                    ampMinus[prevPeriodMiddleFrame + j] = prevPeriodAmpMinus + (currentAmpMinus - prevPeriodAmpMinus) * j / frameLen;
                    energy[prevPeriodMiddleFrame + j] = prevPeriodEnergy + (currentEnergy - prevPeriodEnergy) * j / frameLen;
                }
                prevPeriodMiddleFrame = middleFrame;
                prevPeriodAmpPlus = currentAmpPlus;
                prevPeriodAmpMinus = currentAmpMinus;
                prevPeriodEnergy = currentEnergy;
            }
            avgPeriod /= periods.length;
            // fill till end of wave
            for (int i = prevPeriodMiddleFrame; i < frames; i++) {
                ampPlus[i] = prevPeriodAmpPlus;
                ampMinus[i] = prevPeriodAmpMinus;
                energy[i] = prevPeriodEnergy;
            }
            int lowpassFilterSize = cast(int)(10 * (1/avgPeriod)) | 1;
            float[] lowpassFirFilter = blackmanWindow(lowpassFilterSize);
            float[] ampPlusFiltered = new float[frames];
            float[] ampMinusFiltered = new float[frames];
            float[] energyFiltered = new float[frames];
            applyFirFilter(ampPlus, ampPlusFiltered, lowpassFirFilter);
            applyFirFilter(ampMinus, ampMinusFiltered, lowpassFirFilter);
            applyFirFilter(energy, energyFiltered, lowpassFirFilter);
            amplitudes = new float[frames];
            float maxAmpPlus = ampPlusFiltered[0];
            float maxAmpMinus = ampMinusFiltered[0];
            float maxEnergy = energyFiltered[0];
            for (int i = 1; i < frames; i++) {
                if (maxAmpPlus < ampPlusFiltered[i])
                    maxAmpPlus = ampPlusFiltered[i];
                if (maxAmpMinus < ampMinusFiltered[i])
                    maxAmpMinus = ampMinusFiltered[i];
                if (maxEnergy < energyFiltered[i])
                    maxEnergy = energyFiltered[i];
            }
            float maxAmp = maxAmpPlus > maxAmpMinus ? maxAmpPlus : maxAmpMinus;
            float kPlus = 0;
            float kMinus = 0;
            float kEnergy = 0;
            //if (maxAmpPlus > maxAmpMinus)
            //    amplitudes = ampPlusFiltered;
            //else
            //    amplitudes = ampMinusFiltered;
            kPlus = maxAmpPlus / (maxAmpPlus + maxAmpMinus);
            kMinus = maxAmpMinus / (maxAmpPlus + maxAmpMinus);
            for (int i = 0; i < frames; i++) {
                amplitudes[i] = kPlus * ampPlusFiltered[i] + kMinus * ampMinusFiltered[i] + kEnergy * maxAmp / maxEnergy;
                //amplitudes[i] = energyFiltered[i] * maxAmp / maxEnergy;
            }
            return maxAmpPlus > maxAmpMinus ? 1 : -1;
        }
        return 1;
    }

    void normalizeAmplitude() {
        if (amplitudes && amplitudes.length == frames) {
            for (int i = 0; i < frames; i++) {
                data.ptr[i] /= amplitudes.ptr[i];
            }
        }
    }

    void correctMarksForNormalizedAmplitude() {
        correctMarksForNormalizedAmplitude(marks, 1);
        //smoothTimeMarks(marks);
        //smoothTimeMarks(marks);
        correctMarksForNormalizedAmplitude(negativeMarks, -1);
        //smoothTimeMarks(negativeMarks);
        //smoothTimeMarks(negativeMarks);
    }

    void correctMarksForNormalizedAmplitude(ref float[] marks, int sign) {
        if (marks.length < 3)
            return;
        for (int i = 1; i + 1 < marks.length; i++) {
            float period = (marks[i + 1] - marks[i - 1]) / 2;
            float freq = 1 / period;
            float zeroPhaseTimePosSeconds;
            float amp;
            findNearPhase0(marks[i], freq, sign, zeroPhaseTimePosSeconds, amp);
            float diff = zeroPhaseTimePosSeconds - marks[i];
            if (diff < period / 5 && diff > -period / 5)
                marks[i] = zeroPhaseTimePosSeconds;
        }
        for (int i = 0; i < 8; i++)
            smoothTimeMarksShifted(marks, negativeMarks);
    }

    void fillPeriodInfo(ref PeriodInfo period, float start, float end) {
        import std.math : sqrt;
        period.startTime = start;
        period.periodTime = end - start;
        int startSample = timeToFrame(start);
        int endSample = timeToFrame(end);
        float maxValue = 0;
        float minValue = 0;
        float energy = 0;
        float energyDiv = 0;
        for (int i = startSample; i < endSample; i++) {
            if (i >= 0 && i < frames) {
                float sample = data.ptr[i * channels];
                float absSample = sample < 0 ? -sample : sample;
                if (maxValue < sample)
                    maxValue = sample;
                if (minValue > sample)
                    minValue = sample;
                if (i == startSample) {
                    float part = start * sampleRate - startSample;
                    part = 1 - part;
                    if (sqEnergy)
                        energy += absSample * absSample * part * part;
                    else
                        energy += absSample * part;
                    energyDiv = energyDiv + part;
                } else if (i == endSample) {
                    float part = end * sampleRate - endSample;
                    if (sqEnergy)
                        energy += absSample * absSample * part * part;
                    else
                        energy += absSample * part;
                    energyDiv = energyDiv + part;
                } else {
                    if (sqEnergy)
                        energy += absSample * absSample;
                    else
                        energy += absSample;
                    energyDiv = energyDiv + 1;
                }
            }
        }
        energy = energy / energyDiv;
        if (sqEnergy)
            energy = sqrt(energy);
        period.ampPlus = maxValue;
        period.ampMinus = -minValue;
        period.energy = energy;
        double[] src = new double[PERIOD_FFT_SIZE];
        float step = (end - start) / PERIOD_FFT_SIZE;
        float t = start;
        for (int i = 0; i < PERIOD_FFT_SIZE; i++) {
            src[i] = getSampleInterpolated(t);
            t += step;
        }
        import std.numeric;
        import std.math;
        import std.complex;
        Complex!double[] res = new Complex!double[PERIOD_FFT_SIZE];
        static Fft periodFFT = null;
        if (!periodFFT)
            periodFFT = new Fft(PERIOD_FFT_SIZE);
        periodFFT.fft(src[0..$], res[0..$]);
        for (int i = 0; i < PERIOD_FFT_SIZE / 2; i++) {
            double re = res[i].re;
            double im = res[i].im;
            double amp = sqrt((re*re + im*im) / PERIOD_FFT_SIZE);
            double phase = 0;
            if (amp > 0.0001) {
                phase = atan2(re, im);
            } else {
                amp = 0;
            }
            period.fftAmp[i] = amp;
            period.fftPhase[i] = phase;
        }
        import dlangui.core.logger;
        Log.d("period[", period.startTime, "] fft amps=", period.fftAmp);
    }

    void smoothMarks() {
        smoothTimeMarks(marks);
    }

    void generateFrequenciesFromMarks() {
        frequencies = null;
        middleFrequency = 0;
        minFrequencyK = 0;
        maxFrequencyK = 0;
        if (!data.length || marks.length < 3)
            return;
        frequencies.length = data.length;
        double s = 0;
        // calc avg frequency
        float lastFreq = 1 / (marks[1] - marks[0]);
        double minFreq = lastFreq;
        double maxFreq = lastFreq;
        int lastFreqPos = 0;
        for (int i = 1; i < marks.length; i++) {
            float freq = 1 / (marks[i] - marks[i - 1]);
            if (minFreq > freq)
                minFreq = freq;
            if (maxFreq < freq)
                maxFreq = freq;
            s += freq;
            int pos = timeToFrame((marks[i] + marks[i - 1]) / 2);
            for (int j = lastFreqPos; j < pos; j++) {
                float f = lastFreq + (freq - lastFreq) * (j - lastFreqPos) / (pos - lastFreqPos);
                frequencies[j] = f;
            }
            lastFreq = freq;
            lastFreqPos = pos;
        }
        for (int j = lastFreqPos; j < frequencies.length; j++) {
            frequencies[j] = lastFreq;
        }
        middleFrequency = s / (marks.length - 1);



        //int lowpassFilterSize = 3 * timeToFrame(1/middleFrequency) | 1;
        //float[] lowpassFirFilter = blackmanWindow(lowpassFilterSize);
        //float[] frequenciesFiltered = new float[frames];
        //applyFirFilter(frequencies, frequenciesFiltered, lowpassFirFilter);
        //frequencies = frequenciesFiltered;



        /*

        for (int i = 1; i < marks.length; i++) {
            double period = marks[i] - marks[i - 1];
            double freq = 1 / period;
            if (i == 1 || minFreq > freq)
                minFreq = freq;
            if (i == 1 || maxFreq < freq)
                maxFreq = freq;
        }
        middleFrequency = (maxFreq + minFreq) / 2;
        minFrequencyK = minFreq / middleFrequency;
        maxFrequencyK = maxFreq / middleFrequency;
        int firstFilled = 0;
        int lastFilled = 0;
        for (int i = 1; i + 1 < marks.length; i++) {
            float prevFreq = 1 / (marks[i] - marks[i - 1]);
            float nextFreq = 1 / (marks[i + 1] - marks[i]);
            int prevPeriodMiddle = timeToFrame((marks[i] + marks[i - 1]) / 2);
            int nextPeriodMiddle = timeToFrame((marks[i + 1] + marks[i]) / 2);
            float prevFreqK = prevFreq / middleFrequency;
            float nextFreqK = nextFreq / middleFrequency;
            // interpolate coeffs
            for (int j = prevPeriodMiddle; j < nextPeriodMiddle; j++) {
                frequencies[j] = prevFreqK + (nextFreqK - prevFreqK) * (j - prevPeriodMiddle) / (nextPeriodMiddle / prevPeriodMiddle);
            }
            if (!firstFilled)
                firstFilled = prevPeriodMiddle;
            lastFilled = nextPeriodMiddle - 1;
        }
        frequencies[0 .. firstFilled] = frequencies[firstFilled];
        frequencies[lastFilled .. $] = frequencies[lastFilled - 1];
        */
    }

    void removeDcOffset(float minTime, float maxTime) {
        int startFrame = timeToFrame(minTime);
        int endFrame = timeToFrame(maxTime);
        double s = 0;
        for (int i = startFrame; i < endFrame; i++)
            s += data.ptr[i];
        s /= (endFrame - startFrame);
        for (int i = 0; i < data.length; i++)
            data.ptr[i] -= s;
    }

    int timeToFrame(float time) {
        return cast(int)(time * sampleRate);
    }
    float frameToTime(int frame) {
        return (cast(float)frame / sampleRate);
    }
    float frameToTime(float frame) {
        return (frame / sampleRate);
    }
    void limitFrameIndex(ref int index) {
        if (index >= frames)
            index = frames;
        if (index < 0)
            index = 0;
    }
    float getSample(int index, int channel = 0) {
        if (index < 0 || index >= frames)
            return 0;
        return data.ptr[index * channels + channel];
    }
    void getSamples(int startIndex, int channel, float[] buf) {
        int len = cast(int)buf.length;
        for (int i = 0; i < len; i++) {
            int index = startIndex + i;
            buf.ptr[i] = index >= 0 && index < frames ? data.ptr[index] : 0.0f;
        }
    }
    void getSamplesZpad4(int startIndex, int channel, float[] buf) {
        int len = cast(int)buf.length;
        for (int i = 0; i * 4 < len; i++) {
            int index = startIndex + i;
            float sample = getSample(index);
            buf.ptr[i * 4] = sample;
            buf.ptr[i * 4 + 1] = 0; 
            buf.ptr[i * 4 + 2] = 0; 
            buf.ptr[i * 4 + 3] = 0; 
        }
    }
    /// linearly interpolated sample by time
    float getSampleInterpolated(float time, int channel = 0) {
        if (channel >= channels)
            channel = channel % channels;
        int index = cast(int)(time * sampleRate);
        float deltaTime = time - cast(float)index / sampleRate;
        float s0 = getSample(index, channel);
        float s1 = getSample(index + 1, channel);
        return s0 * (1 - deltaTime) + s1 * deltaTime;
    }

    void getSamplesInterpolated(float frameMiddle, float step, float[] buf) {
        int len = cast(int)buf.length;
        float x = frameMiddle - (len / 2) * step;
        for (int i = 0; i < len; i++) {
            int index = cast(int)x;
            float delta = x - index; // delta is 0..1
            float s0 = getSample(index, 0);
            float s1 = getSample(index + 1, 0);
            buf.ptr[i] = s0 * (1 - delta) + s1 * delta;
            x += step;
        }
    }

    WaveFile getRange(int start, int end) {
        int len = end - start;
        if (len <= 0 || start < 0 || end > frames)
            return null;
        WaveFile res = new WaveFile();
        res.channels = channels;
        res.sampleRate = sampleRate;
        res.frames = len;
        res.data = new float[len * channels];
        res.data[0..$] = data[start * channels .. (start + len) * channels];
        return res;
    }

    WaveFile upsample4x(int start, int end) {
        if (start < 0)
            start = 0;
        if (end > frames)
            end = frames;
        int dstart = 16;
        int dend = 16;
        if (start - dstart < 0)
            dstart = start;
        if (end + dend > frames)
            dend = frames - end;
        WaveFile tmp = getRange(start - dstart, end + dend);
        WaveFile resampled = tmp.upsample4x();
        return resampled.getRange(dstart * 4, resampled.frames - dend * 4);
    }

    WaveFile upsample4x() {
        import std.numeric;
        import std.complex;
        immutable int BATCH_SIZE = 256;
        immutable int overlap = BATCH_SIZE/4;
        Fft fft = new Fft(BATCH_SIZE);
        Fft ifft = new Fft(BATCH_SIZE);
        WaveFile res = new WaveFile();
        res.channels = 1;
        res.sampleRate = sampleRate * 4;
        res.frames = frames * 4;
        res.data = new float[res.frames];
        res.data[0..$] = 0;
        float[] srcBuf = new float[BATCH_SIZE];
        Complex!double[] fftFrame = new Complex!double[BATCH_SIZE];
        Complex!double[] invBuf = new Complex!double[BATCH_SIZE];

        float maxsrc = 0;
        float maxdst = 0;
        for (int i = 0; i < frames; i++)
            if (maxsrc < data[i])
                maxsrc = data[i];
        
        for (int x = -overlap / 4; x < frames; x += BATCH_SIZE / 4 - overlap / 2) {
            getSamplesZpad4(x, 0, srcBuf);
            //immutable int SMOOTH_RANGE = BATCH_SIZE / 10;
            //for (int i = 0; i < SMOOTH_RANGE; i++) {
            //    float k = 1.0f - i / cast(float)SMOOTH_RANGE;
            //    float s1 = srcBuf[i * 4];
            //    float s2 = srcBuf[BATCH_SIZE - i * 4 - 4];
            //    float sm = (s1 + s2) / 2;
            //    srcBuf[i * 4] = s1 * (1 - k) + sm * k;
            //    srcBuf[BATCH_SIZE - i * 4 - 4] = s2 * (1 - k) + sm * k;
            //}
            fft.fft(srcBuf, invBuf);
            for (int i = BATCH_SIZE / 8 - 5; i <= BATCH_SIZE * 7 / 8 + 5 + 1; i++) {
                invBuf[i] = Complex!double(0,0);
            }
            // smoother lowpass filter
            /*
            immutable int SMOOTH_DIST = BATCH_SIZE / 30;
            for (int i = 1; i < SMOOTH_DIST; i++) {
                float k = SMOOTH_DIST / i;
                invBuf[BATCH_SIZE / 8 - i].re *= k;
                invBuf[BATCH_SIZE / 8 - i].im *= k;
                invBuf[BATCH_SIZE * 7 / 8 + i].re *= k;
                invBuf[BATCH_SIZE * 7 / 8 + i].im *= k;
            }
            */
            ifft.inverseFft(invBuf, fftFrame);
            for (int i = overlap; i < BATCH_SIZE - overlap; i++) {
                int index = x * 4 + i;
                if (index >= 0 && index < res.frames)
                    res.data.ptr[index] = fftFrame[i].re * 4;
            }
        }

        for (int i = 0; i < res.frames; i++)
            if (maxdst < res.data[i])
                maxdst = res.data[i];

        import dlangui.core.logger;

        Log.d("max value before upsampling: ", maxsrc, " after: ", maxdst);

        return res;
    }

    /// returns autocorrelation best frequency at center of file
    float calcBaseFrequency() {
        return calcLocalFrequency(frameToTime(frames / 2), 30);
    }

    int getMaxAmplitudeSign() {
        float maxPositive = 0;
        float maxNegative = 0;
        foreach(v; data) {
            if (v > 0 && maxPositive < v)
                maxPositive = v;
            if (v < 0 && maxNegative < -v)
                maxNegative = -v;
        }
        return maxPositive > maxNegative ? 1 : -1;
    }

    float findZeroCrossingNear(float timePosition) {
        int frame = timeToFrame(timePosition);

        int frame0, frame1;
        frame0 = frame1 = frame;
        for (int i = 0; i < 10000; i++) {
            float sample = getSample(frame + i);
            float sample1 = getSample(frame + i + 1);
            if ((sample >= 0 && sample1 <=0) || (sample <= 0 && sample1 >=0)) {
                frame0 = frame + i;
                frame1 = frame + i + 1;
                break;
            }
            sample = getSample(frame - i);
            sample1 = getSample(frame - i - 1);
            if ((sample >= 0 && sample1 <=0) || (sample <= 0 && sample1 >=0)) {
                frame0 = frame - i - 1;
                frame1 = frame - i;
                break;
            }
        }

        if (frame0 < frame1) {
            float sample0 = getSample(frame0);
            float sample1 = getSample(frame1);
            if (sample0 != sample1) {
                float time0 = frameToTime(frame0);
                float time1 = frameToTime(frame1);
                // linear equation, find crossing 0
                float t = time0 - sample0 * (time1 - time0) / (sample1 - sample0);
                return t;
            }
            return frameToTime(frame0);
        }
        // cannot correct
        return timePosition;
    }

    float findMaxDiffPosition(int startFrame, int endFrame) {
        float maxDiffPlus = 0;
        float maxDiffMinus = 0;
        int maxDiffPositionPlus = startFrame;
        int maxDiffPositionMinus = startFrame;
        for (int i = startFrame + 1; i < endFrame; i++) {
            float diff = getSample(i) - getSample(i - 1);
            if (diff > 0) {
                if (maxDiffPlus < diff) {
                    maxDiffPlus = diff;
                    maxDiffPositionPlus = i;
                }
            } else {
                if (maxDiffMinus < -diff) {
                    maxDiffMinus = -diff;
                    maxDiffPositionMinus = i;
                }
            }
        }
        if (maxDiffPlus > maxDiffMinus)
            return frameToTime(maxDiffPositionPlus);
        return frameToTime(maxDiffPositionMinus);
    }

    /// sign == 1 if biggest amplitude is positive, -1 if negative
    float[] findZeroCrossingPositions(int sign = 1) {
        import dlangui.core.logger;

        float freqPosition = frameToTime(frames / 2);
        float freqBigRange = calcLocalFrequency(freqPosition, 40);
        float freqShortRange = calcLocalFrequency(freqPosition, freqBigRange / 4);
        Log.d("Frequencies: ", freqBigRange, " ", freqShortRange);

        freqBigRange = calcLocalFrequency(freqPosition, 40);
        freqShortRange = calcLocalFrequency(freqPosition, freqBigRange / 4);

        float zeroPhaseTime;
        float amplitude;
        //findNearPhase0(freqPosition, freqShortRange, 1, zeroPhaseTime, amplitude);
        float zeroPhaseTime2;
        float amplitude2;
        float freq;

        // find max difference position
        freqPosition = findMaxDiffPosition(timeToFrame(freqPosition - 1/freqShortRange), timeToFrame(freqPosition + 1/freqShortRange));
        // find near zero crossing
        freqPosition = findZeroCrossingNear(freqPosition);

        float initialPosition = freqPosition;
        float initialFreq = freqShortRange;
        float[] zpositions;
        float[] zpositionsBefore;
        zpositions ~= freqPosition;

        float maxtime = frames / cast(float)sampleRate - 1f / initialFreq;
        float mintime = 1f / initialFreq;


        Log.d("Scanning time range ", initialPosition, " .. ", maxtime);
        freqPosition = initialPosition;
        freq = initialFreq;
        float step = 1/freq;
        float prevPosition = freqPosition;
        freqPosition += step;
        for (int i = 0; i < 10000; i++) {
            if (freqPosition > maxtime)
                break;
            freqPosition = findZeroCrossingNear(freqPosition);
            step = freqPosition - prevPosition;
            prevPosition = freqPosition;
            zpositions ~= freqPosition;
            freqPosition += step;
        }
        // till end - just use fixed freq
        maxtime = frames / cast(float)sampleRate - 0.1f / initialFreq;
        for (int i = 0; i < 3; i++) {
            if (freqPosition > maxtime)
                break;
            zpositions ~= freqPosition;
            freqPosition += step;
        }
        Log.d("Scanning time range ", mintime, " .. ", initialPosition);
        freqPosition = initialPosition;
        freq = initialFreq;
        step = 1/freq;
        prevPosition = freqPosition;
        freqPosition -= step;
        for (int i = 0; i < 10000; i++) {
            if (freqPosition < mintime)
                break;
            freqPosition = findZeroCrossingNear(freqPosition);
            step = prevPosition - freqPosition;
            prevPosition = freqPosition;
            zpositionsBefore ~= freqPosition;
            freqPosition -= step;
        }
        // till beginning - just use fixed freq
        mintime = 0.1f / initialFreq;
        for (int i = 0; i < 3; i++) {
            if (freqPosition < mintime)
                break;
            zpositionsBefore ~= freqPosition;
            freqPosition -= step;
        }

        //Log.d("zpositions: ", zpositions, "   before: ", zpositionsBefore);

        // combine positions before and after
        float[] zpositionsAll;
        for (int i = cast(int)zpositionsBefore.length - 1; i >= 0; i--)
            zpositionsAll ~= zpositionsBefore[i];
        zpositionsAll ~= zpositions;

        float[] freqs;
        for (int i = 1; i < zpositionsAll.length; i++) {
            freqs ~= 1 / (zpositionsAll[i] - zpositionsAll[i - 1]);
        }

        //Log.d("zpositionsAll: ", zpositionsAll);
        Log.d("freqs: ", freqs);
        return zpositionsAll;
    }



    /// sign == 1 if biggest amplitude is positive, -1 if negative
    float[] findZeroPhasePositions(int sign = 1) {
        import dlangui.core.logger;

        float freqPosition = frameToTime(frames / 2);
        float freqBigRange = calcLocalFrequency(freqPosition, 40);
        float freqShortRange = calcLocalFrequency(freqPosition, freqBigRange / 4);
        Log.d("Frequencies: ", freqBigRange, " ", freqShortRange);

        freqBigRange = calcLocalFrequency(freqPosition, 40);
        freqShortRange = calcLocalFrequency(freqPosition, freqBigRange / 4);

        float zeroPhaseTime;
        float amplitude;
        //findNearPhase0(freqPosition, freqShortRange, 1, zeroPhaseTime, amplitude);
        float zeroPhaseTime2;
        float amplitude2;
        float freq;
        findNearPhase0FreqAutocorrection(freqPosition, freqShortRange, 1/freqShortRange, sign, zeroPhaseTime2, amplitude2, freq);
        Log.d("Zero phase near ", freqPosition, " at freq ", freqShortRange, " : pos=", zeroPhaseTime2, " amp=", amplitude2, " freq=", freq);
        freqPosition = zeroPhaseTime2;


        float initialPosition = freqPosition;
        float initialFreq = freq;
        float[] zpositions;
        float[] zpositionsBefore;
        zpositions ~= freqPosition;

        float maxtime = frames / cast(float)sampleRate - 2f / initialFreq;
        float mintime = 2f / initialFreq;


        Log.d("Scanning time range ", initialPosition, " .. ", maxtime);
        freqPosition = initialPosition;
        freq = initialFreq;
        float step = 1/freq;
        freqPosition += step;
        for (int i = 0; i < 10000; i++) {
            if (freqPosition > maxtime)
                break;
            float oldFreq = freq;
            findNearPhase0FreqAutocorrection(freqPosition, oldFreq, 0.2 / oldFreq, sign, zeroPhaseTime2, amplitude2, freq);
            Log.d("Zero phase near ", freqPosition, " at freq ", oldFreq, " : pos=", zeroPhaseTime2, " amp=", amplitude2, " step=", step, " freq=", freq);
            step = 1/freq;
            freqPosition = zeroPhaseTime2;
            zpositions ~= freqPosition;
            freqPosition += step;
        }
        // till end - just use fixed freq
        maxtime = frames / cast(float)sampleRate - 0.1f / initialFreq;
        for (int i = 0; i < 3; i++) {
            if (freqPosition > maxtime)
                break;
            zpositions ~= freqPosition;
            freqPosition += step;
        }
        Log.d("Scanning time range ", mintime, " .. ", initialPosition);
        freqPosition = initialPosition;
        freq = initialFreq;
        step = 1/freq;
        freqPosition -= step;
        for (int i = 0; i < 10000; i++) {
            if (freqPosition < mintime)
                break;
            float oldFreq = freq;
            findNearPhase0FreqAutocorrection(freqPosition, oldFreq, 0.2 / oldFreq, sign, zeroPhaseTime2, amplitude2, freq);
            Log.d("Zero phase near ", freqPosition, " at freq ", oldFreq, " : pos=", zeroPhaseTime2, " amp=", amplitude2, " step=", step, " freq=", freq);
            step = 1/freq;
            freqPosition = zeroPhaseTime2;
            zpositionsBefore ~= freqPosition;
            freqPosition -= step;
        }
        // till beginning - just use fixed freq
        mintime = 0.1f / initialFreq;
        for (int i = 0; i < 3; i++) {
            if (freqPosition < mintime)
                break;
            zpositionsBefore ~= freqPosition;
            freqPosition -= step;
        }

        //Log.d("zpositions: ", zpositions, "   before: ", zpositionsBefore);

        float[] zpositionsAll;
        for (int i = cast(int)zpositionsBefore.length - 1; i >= 0; i--)
            zpositionsAll ~= zpositionsBefore[i];
        zpositionsAll ~= zpositions;

        float[] freqs;
        for (int i = 1; i < zpositionsAll.length; i++) {
            freqs ~= 1 / (zpositionsAll[i] - zpositionsAll[i - 1]);
        }

        //Log.d("zpositionsAll: ", zpositionsAll);
        Log.d("freqs: ", freqs);
        return zpositionsAll;
    }

    float calcLocalFrequency(float position, float minFreq) {
        import dlangui.core.logger;
        int pos = timeToFrame(position);
        int windowSize = timeToFrame(1 / minFreq) * 2;
        windowSize &= 0xFFFFFE;
        float[] window = blackmanWindow(windowSize);
        float[] frame = new float[windowSize + 1];
        float[] corr = new float[windowSize + 1];
        float[] windowcorr = new float[windowSize + 1];
        getSamples(pos - windowSize / 2, 0, frame);
        for (int i = 0; i < frame.length; i++) {
            frame[i] *= window[i];
        }
        correlation(frame, frame, corr);
        correlation(window, window, windowcorr);

        int p = 1;
        for (; p < corr.length; p++) {
            if (corr[p] < 0)
                break;
        }
        //Log.d("Negative correlation at offset ", p);
        float maxcorr = corr[p];
        int maxcorrpos = p;
        for (; p < corr.length; p++) {
            if (maxcorr < corr[p]) {
                maxcorr = corr[p];
                maxcorrpos = p;
            }
        }
        float a, b, c;
        float correction1 = windowcorr[maxcorrpos-1];
        float correction2 = windowcorr[maxcorrpos];
        float correction3 = windowcorr[maxcorrpos+1];
        correction1 = correction2 = correction3 = 1;
        calcParabola(maxcorrpos - 1, 
                     corr[maxcorrpos-1] / correction1, 
                     corr[maxcorrpos] / correction2, 
                     corr[maxcorrpos+1] / correction3, a, b, c);
        float x0 = -b / (2 * a);
        //Log.d("Max correlation = ", maxcorr, " at offset ", maxcorrpos, " corr0: ", corr[0], " approx best position = ", x0);
        float period = frameToTime(x0);
        if (period > 0)
            return 1 / period;
        return 0;
    }

    void findNearPhase0FreqAutocorrection(float positionTimeSeconds, float freqHerz, float maxCorrection, int sign, ref float zeroPhaseTimePosSeconds, ref float amplitude, ref float newFreq) {
        import dlangui.core.logger;
        float startPosition = positionTimeSeconds;
        findNearPhase0(positionTimeSeconds, freqHerz, sign, zeroPhaseTimePosSeconds, amplitude);
        float autocorrelatedFrequency = calcLocalFrequency(zeroPhaseTimePosSeconds, freqHerz / 2);
        //Log.d("Initial phase detection: freq=", freqHerz, " pos=", positionTimeSeconds, " => ", zeroPhaseTimePosSeconds, " amp=", amplitude, "  autocorrFreq=", autocorrelatedFrequency);
        if (autocorrelatedFrequency >= freqHerz * 0.8 && autocorrelatedFrequency <= freqHerz * 1.2) {
            freqHerz = autocorrelatedFrequency;
            positionTimeSeconds = zeroPhaseTimePosSeconds;
            findNearPhase0(positionTimeSeconds, freqHerz, sign, zeroPhaseTimePosSeconds, amplitude);
            //Log.d("    position updated (1) for freq=", freqHerz, " pos=", positionTimeSeconds, " => ", zeroPhaseTimePosSeconds, " amp=", amplitude);
        }
        if (zeroPhaseTimePosSeconds >= startPosition - maxCorrection && zeroPhaseTimePosSeconds <= startPosition + maxCorrection) {
            positionTimeSeconds = zeroPhaseTimePosSeconds;
            newFreq = freqHerz;
        } else {
            zeroPhaseTimePosSeconds = startPosition;
            newFreq = freqHerz;
        }
        // calculate again at zero phase position
        //findNearPhase0(positionTimeSeconds, freqHerz, sign, zeroPhaseTimePosSeconds, amplitude);
        //Log.d("    position updated (2) for freq=", freqHerz, " pos=", positionTimeSeconds, " => ", zeroPhaseTimePosSeconds, " amp=", amplitude);
        //newFreq = freqHerz;
    }

    void findNearPhase0(float positionTimeSeconds, float freqHerz, int sign, ref float zeroPhaseTimePosSeconds, ref float amplitude) {
        import std.math : sqrt, atan2, PI;
        immutable int TABLE_LEN = 256;
//        immutable int TABLE_LEN = 768;
        float[TABLE_LEN] buf;
        float x = positionTimeSeconds * sampleRate;
        float periodSamples = sampleRate / freqHerz;
        // get interpolated one period of freq
        getSamplesInterpolated(x, periodSamples / TABLE_LEN, buf[0..$]);
        double sumSin = 0;
        double sumCos = 0;
        //double sumSin2 = 0;
        //double sumCos2 = 0;
        //float stepWidth = periodSamples / 256;
        //for (int i = 0; i < TABLE_LEN; i++) {
        //    sumSin += sign * buf.ptr[i] * SIN_SYNC_TABLE_768.ptr[i];
        //    sumCos += sign * buf.ptr[i] * SIN_SYNC_TABLE_768.ptr[i];
        //    //sumSin2 += SIN_SYNC_TABLE_768.ptr[i] * SIN_SYNC_TABLE_768.ptr[i];
        //    //sumCos2 += SIN_SYNC_TABLE_768.ptr[i] * SIN_SYNC_TABLE_768.ptr[i];
        //}
        for (int i = 0; i < TABLE_LEN; i++) {
            sumSin += sign * buf.ptr[i] * SIN_TABLE_256.ptr[i];
            sumCos += sign * buf.ptr[i] * COS_TABLE_256.ptr[i];
            //sumSin2 += SIN_TABLE_256.ptr[i] * SIN_TABLE_256.ptr[i];
            //sumCos2 += COS_TABLE_256.ptr[i] * SIN_TABLE_256.ptr[i];
        }
        sumSin /= TABLE_LEN;
        sumCos /= TABLE_LEN;
        //sumSin /= (periodSamples * periodSamples);
        //sumCos /= (periodSamples * periodSamples);
        // calc amplitude
        amplitude = sqrt(sumSin * sumSin + sumCos * sumCos); // / periodSamples;
        // normalize
        //sumSin /= amplitude;
        //sumCos /= amplitude;
        float phase = atan2(sumSin, sumCos) - PI/2;
        if (phase < -PI)
            phase += PI * 2;
        //float phase2 = atan2(sumSin2, sumCos2) - PI/2;
        float zeroPhaseX = x + periodSamples * phase / (2 * PI);
        zeroPhaseTimePosSeconds = zeroPhaseX / sampleRate;
    }

    float sinAmpAt(float positionTimeSeconds, float freqHerz, int sign) {
        import std.math : sqrt, atan2, PI;
        float[256] buf;
        float x = positionTimeSeconds * sampleRate;
        float periodSamples = sampleRate / freqHerz;
        // get interpolated one period of freq
        getSamplesInterpolated(x, periodSamples / 256, buf[0..$]);
        float sumSin = 0;
        //float stepWidth = periodSamples / 256;
        for (int i = 0; i < 256; i++) {
            sumSin += sign * buf.ptr[i] * SIN_TABLE_256.ptr[i];
        }
        sumSin /= 256;
        //sumSin /= (periodSamples * periodSamples);
        //sumCos /= (periodSamples * periodSamples);
        // calc amplitude
        //float amplitude = sqrt(sumSin * sumSin); // / periodSamples;
        return sumSin; //amplitude;
    }

    /// create WaveFile which is FIR filtered copy of current wave
    WaveFile firFilter(float[] filter) {
        WaveFile res = new WaveFile(this, true);
        applyFirFilter(data, res.data, filter);
        return res;
    }

    /// create WaveFile which is FIR inverse filtered copy of current wave
    WaveFile firFilterInverse(float[] filter) {
        WaveFile res = new WaveFile(this, true);
        applyFirFilterInverse(data, res.data, filter);
        return res;
    }

}

/* Autocorrelation LPC coeff generation algorithm invented by
   N. Levinson in 1947, modified by J. Durbin in 1959. */

/* Input : elements of time doamin data (with window applied)
   Output: lpc coefficients, excitation energy */
float calcLPC(float[] data, float[] lpci) {
    int n = cast(int)data.length;
    int m = cast(int)lpci.length;
    double[] aut = new double[m + 1];
    double[] lpc = new double[m];
    double error;
    double epsilon;
    int i,j;

    /* autocorrelation, p+1 lag coefficients */
    j=m+1;
    while(j--){
        double d=0; /* double needed for accumulator depth */
        for(i=j; i<n; i++)
            d += cast(double)data[i] * data[i-j];
        aut[j]=d;
    }

    /* Generate lpc coefficients from autocorr values */

    /* set our noise floor to about -100dB */
    error = aut[0] * (1. + 1e-10);
    epsilon = 1e-9*aut[0]+1e-10;

    for(i=0; i<m; i++){
        double r= -aut[i+1];

        if (error < epsilon) {
            lpc[i .. $] = 0;
            break;
        }

        /* Sum up this iteration's reflection coefficient; note that in
        Vorbis we don't save it.  If anyone wants to recycle this code
        and needs reflection coefficients, save the results of 'r' from
        each iteration. */

        for (j=0; j<i; j++)
            r -= lpc[j] * aut[i - j];
        r /= error;

        /* Update LPC coefficients and total error */

        lpc[i]=r;
        for(j=0; j<i/2; j++) {
            double tmp = lpc[j];

            lpc[j] += r * lpc[i-1-j];
            lpc[i-1-j] += r*tmp;
        }
        if(i&1)
            lpc[j]+=lpc[j]*r;

        error *= 1. - r*r;
    }

    /* slightly damp the filter */
    {
        double g = .99;
        double damp = g;
        for(j=0;j<m;j++){
            lpc[j]*=damp;
            damp*=g;
        }
    }

    for(j=0; j<m; j++)
        lpci[j] = cast(float)lpc[j];

    /* we need the error value to know how big an impulse to hit the
    filter with later */

    return error;
}

void applyFirFilterInverse(float[] src, float[] dst, float[] filter) {
    assert(src.length == dst.length);
    applyFirFilter(src, dst, filter);
    int len = cast(int)src.length;
    for(int i = 0; i < len; i++) {
        dst.ptr[i] = src.ptr[i] - dst.ptr[i];
    }
}

void applyFirFilter(float[] src, float[] dst, float[] filter) {
    assert(src.length == dst.length);
    int filterLen = cast(int)filter.length;
    int filterMiddle = filterLen / 2;
    int len = cast(int)src.length;
    for (int x = 0; x < len; x++) {
        double filterSum = 0;
        double resultSum = 0;
        for (int i = 0; i < filterLen; i++) {
            int index = i - filterMiddle + x;
            if (index >= 0 && index < len) {
                float sample = src.ptr[index];
                float flt = filter.ptr[i];
                resultSum += sample * flt;
                filterSum += flt;
            }
        }
        dst.ptr[x] = resultSum / filterSum;
    }
}

// calc parabola coefficients for points (x1, y1), (x1 + 1, y2), (x1 + 2, y3)
void calcParabola(int x1, float y1, float y2, float y3, ref float a, ref float b, ref float c) {
    a = (y3 + y1) / 2 - y2;
    b = y2 - y1 - a * (2 * x1 + 1);
    c = (x1 + 1) *y1 - x1 * y2 + a * x1 * (x1 + 1);
}

float[] makeLowpassBlackmanFirFilter(int N) {
    float[] res = blackmanWindow(N).dup;
    double s = 0;
    foreach(v; res)
        s += v;
    foreach(ref v; res)
        v = -v / s;
    res[N / 2] += 2;


    s = 0;
    foreach(v; res)
        s += v;

    return res;
}

void normalizeFirFilter(float[] coefficients) {
    double s = 0;
    foreach(v; coefficients)
        s += v;
    foreach(ref v; coefficients)
        v /= s;
}

__gshared float[][int] BLACKMAN_WINDOW_CACHE;

// generate blackman window in array [0..N] (value at N/2 == 1)
float[] blackmanWindow(int N) {
    if (auto existing = N in BLACKMAN_WINDOW_CACHE) {
        return *existing;
    }
    import std.math : cos, PI;
    float[] res = new float[N + 1];
    for (int i = 1; i <= N + 1; i++) {
        res[i - 1] = 0.42f - 0.5f * cos(2 * PI * i / (N + 2)) + 0.08 * cos(4 * PI * i  / (N + 2));
    }
    BLACKMAN_WINDOW_CACHE[N] = res;
    return res;
}

void correlation(float[] a, float[] b, float[] res) {
    assert(a.length == b.length);
    assert(res.length >= a.length);
    for (int diff = 0; diff < a.length; diff++) {
        float sum = 0;
        for (int i = 0; i < a.length - diff; i++)
            sum += a[i] * b[i + diff];
        res[diff] = sum;
    }
}

void smoothTimeMarks(ref float[] marks) {
    if (marks.length < 3)
        return;
    float[] tmp = new float[marks.length];
    tmp[0] = marks[0];
    tmp[$ - 1] = marks[$ - 1];
    for (int i = 1; i + 1 < marks.length; i++) {
        tmp[i] = (marks[i] + marks[i - 1] + marks[i + 1]) / 3;
    }
    marks = tmp;
}

void smoothTimeMarksShifted(ref float[] marks, ref float[] negativeMarks) {
    float[] tmpPositive = smoothTimeMarks(marks, negativeMarks);
    float[] tmpNegative = smoothTimeMarks(negativeMarks, marks);
    marks = tmpPositive;
    negativeMarks = tmpNegative;
}

/// smooth phase marks using marks shifted by half period
float[] smoothTimeMarks(float[] marks, float[] marksShifted) {
    if (marks.length < 3 || marksShifted.length < 3)
        return marks;
    int i = 0;
    int i0 = 0;
    if (marks[i + i0] < marksShifted[i]) {
        i = 1;
        i0 = -1;
    }
    float[] tmp = marks.dup;
    for (; i < marks.length &&  i + i0 + 1 < marksShifted.length; i++) {
        if (marks[i] > marksShifted[i + i0] && marks[i] < marksShifted[i + i0 + 1])
            tmp[i] = (marks[i] + marksShifted[i + i0] + marksShifted[i + i0 + 1]) / 3;
    }
    if (i0 == -1) {
        // smooth first item
        tmp[0] = (tmp[0] + tmp[1] - (tmp[2] - tmp[1])) / 2;
    }
    if (tmp.length - 1 + i0 < marksShifted.length - 1) {
        // smooth last item
        tmp[$ - 1] = (tmp[$ - 1] + tmp[$ - 2] + (tmp[$ - 2] - tmp[$ - 3])) / 2;
    }
    return tmp;
}

// generate several periods sin table multiplied by blackman window, with phase 0 at middle point
float[] generateSyncSinTable(int len, int periods) {
    float[] singlePeriod = generateSinTable(len);
    float[] full;
    for (int i = 0; i < periods; i++)
        full ~= singlePeriod;
    float[] window = blackmanWindow(len * periods);
    double s = 0;
    for(int i = 0; i < full.length; i++) {
        full[i] = full[i] * window[i];
        s += full[i];
    }
    s /= full.length;
    for(int i = 0; i < full.length; i++) {
        full[i] -= s;
    }
    return full;
}

// generate several periods sin table multiplied by blackman window, with phase 0 at middle point
float[] generateSyncCosTable(int len, int periods) {
    float[] singlePeriod = generateCosTable(len);
    float[] full;
    for (int i = 0; i < periods; i++)
        full ~= singlePeriod;
    float[] window = blackmanWindow(len * periods);
    double s = 0;
    for(int i = 0; i < full.length; i++) {
        full[i] = full[i] * window[i];
        s += full[i];
    }
    s /= full.length;
    for(int i = 0; i < full.length; i++) {
        full[i] -= s;
    }
    return full;
}

// generate sin table with phase 0 at middle point
float[] generateSinTable(int len) {
    float[] res = new float[len];
    import std.math : sin, cos, PI;
    for (int i = 0; i < len; i++) {
        double x = (i - len / 2) * 2 * PI / len;
        res[i] = sin(x);
    }
    return res;
}

// generate sin table with phase 0 at middle point
float[] generateCosTable(int len) {
    float[] res = new float[len];
    import std.math : sin, cos, PI;
    for (int i = 0; i < len; i++) {
        double x = (i - len / 2) * 2 * PI / len;
        res[i] = cos(x);
    }
    return res;
}

__gshared float[] SIN_TABLE_256;
__gshared float[] COS_TABLE_256;
__gshared float[] SIN_SYNC_TABLE_768;
__gshared float[] COS_SYNC_TABLE_768;

__gshared static this() {
    SIN_TABLE_256 = generateSinTable(256);
    COS_TABLE_256 = generateCosTable(256);
    SIN_SYNC_TABLE_768 = generateSyncSinTable(256, 3);
    COS_SYNC_TABLE_768 = generateSyncCosTable(256, 3);
}
