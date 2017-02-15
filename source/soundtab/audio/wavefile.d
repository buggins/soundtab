module soundtab.audio.wavefile;

class WaveFile {
    string filename;
    int channels;
    int sampleRate;
    int frames;
    float[] data;
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
            for (int i = BATCH_SIZE / 8; i <= BATCH_SIZE * 7 / 8; i++) {
                invBuf[i] = Complex!double(0,0);
            }
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
        float freqPosition = res.frameToTime(res.frames / 2);
        float freqBigRange = res.calcLocalFrequency(freqPosition, 40);
        float freqShortRange = res.calcLocalFrequency(freqPosition, freqBigRange / 4);
        float freqShortestRange = res.calcLocalFrequency(freqPosition, freqBigRange / 2);
        float freqShortestRange2 = res.calcLocalFrequency(freqPosition, freqBigRange);
        Log.d("Frequencies: ", freqBigRange, " ", freqShortRange, " ", freqShortestRange, " ", freqShortestRange2);

        float freqPosition0 = freqPosition - 4/freqBigRange;
        float freqPosition1 = freqPosition + 4/freqBigRange;
        float freqPosition2 = freqPosition - 2/freqBigRange;
        float freqPosition3 = freqPosition + 2/freqBigRange;
        float freqPosition4 = freqPosition - 0.5/freqBigRange;
        float freqPosition5 = freqPosition + 0.5/freqBigRange;

        freqBigRange = res.calcLocalFrequency(freqPosition0, 40);
        freqShortRange = res.calcLocalFrequency(freqPosition0, freqBigRange / 4);
        freqShortestRange = res.calcLocalFrequency(freqPosition0, freqBigRange / 2);
        freqShortestRange2 = res.calcLocalFrequency(freqPosition0, freqBigRange);
        Log.d("Frequencies at -4 periods: ", freqBigRange, " ", freqShortRange, " ", freqShortestRange, " ", freqShortestRange2);
        freqBigRange = res.calcLocalFrequency(freqPosition1, 40);
        freqShortRange = res.calcLocalFrequency(freqPosition1, freqBigRange / 4);
        freqShortestRange = res.calcLocalFrequency(freqPosition1, freqBigRange / 2);
        freqShortestRange2 = res.calcLocalFrequency(freqPosition1, freqBigRange);
        Log.d("Frequencies at +4 periods: ", freqBigRange, " ", freqShortRange, " ", freqShortestRange, " ", freqShortestRange2);

        freqBigRange = res.calcLocalFrequency(freqPosition2, 40);
        freqShortRange = res.calcLocalFrequency(freqPosition2, freqBigRange / 4);
        freqShortestRange = res.calcLocalFrequency(freqPosition2, freqBigRange / 2);
        freqShortestRange2 = res.calcLocalFrequency(freqPosition2, freqBigRange);
        Log.d("Frequencies at -2 periods: ", freqBigRange, " ", freqShortRange, " ", freqShortestRange, " ", freqShortestRange2);
        freqBigRange = res.calcLocalFrequency(freqPosition3, 40);
        freqShortRange = res.calcLocalFrequency(freqPosition3, freqBigRange / 4);
        freqShortestRange = res.calcLocalFrequency(freqPosition3, freqBigRange / 2);
        freqShortestRange2 = res.calcLocalFrequency(freqPosition3, freqBigRange);
        Log.d("Frequencies at +2 periods: ", freqBigRange, " ", freqShortRange, " ", freqShortestRange, " ", freqShortestRange2);

        freqBigRange = res.calcLocalFrequency(freqPosition4, 40);
        freqShortRange = res.calcLocalFrequency(freqPosition4, freqBigRange / 4);
        freqShortestRange = res.calcLocalFrequency(freqPosition4, freqBigRange / 2);
        freqShortestRange2 = res.calcLocalFrequency(freqPosition4, freqBigRange);
        Log.d("Frequencies at -1/2 periods: ", freqBigRange, " ", freqShortRange, " ", freqShortestRange, " ", freqShortestRange2);
        freqBigRange = res.calcLocalFrequency(freqPosition5, 40);
        freqShortRange = res.calcLocalFrequency(freqPosition5, freqBigRange / 4);
        freqShortestRange = res.calcLocalFrequency(freqPosition5, freqBigRange / 2);
        freqShortestRange2 = res.calcLocalFrequency(freqPosition5, freqBigRange);
        Log.d("Frequencies at +1/2 periods: ", freqBigRange, " ", freqShortRange, " ", freqShortestRange, " ", freqShortestRange2);

        return res;
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
}

// calc parabola coefficients for points (x1, y1), (x1 + 1, y2), (x1 + 2, y3)
void calcParabola(int x1, float y1, float y2, float y3, ref float a, ref float b, ref float c) {
    a = (y3 + y1) / 2 - y2;
    b = y2 - y1 - a * (2 * x1 + 1);
    c = (x1 + 1) *y1 - x1 * y2 + a * x1 * (x1 + 1);
}

// generate blackman window in array [0..N] (value at N/2 == 1)
float[] blackmanWindow(int N) {
    import std.math : cos, PI;
    float[] res = new float[N + 1];
    for (int i = 1; i <= N + 1; i++) {
        res[i - 1] = 0.42f - 0.5f * cos(2 * PI * i / (N + 2)) + 0.08 * cos(4 * PI * i  / (N + 2));
    }
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
