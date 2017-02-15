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
            buf.ptr[i] = index >= 0 && index < len ? data.ptr[index] : 0.0f;
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

        int reslen = cast(int)fftFrame.length;
        reslen++;
        return res;
    }
}

