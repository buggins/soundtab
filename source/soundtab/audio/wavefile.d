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

    WaveFile upsample4x() {
        import std.numeric;
        import std.complex;
        immutable int BATCH_SIZE = 1024;
        Fft fft = new Fft(BATCH_SIZE);
        Fft ifft = new Fft(BATCH_SIZE);
        WaveFile res = new WaveFile();
        res.channels = 1;
        res.sampleRate = sampleRate * 4;
        res.frames = frames * 4;
        res.data = new float[res.frames];
        res.data[0..$] = 0;
        float[] srcBuf = new float[BATCH_SIZE];
        Complex!double[] invBuf = new Complex!double[BATCH_SIZE];
        
        for (int x = -BATCH_SIZE / 4 / 4; x < frames; x += BATCH_SIZE / 2 / 4) {
            getSamplesZpad4(x, 0, srcBuf);
            Complex!double[] fftFrame = fft.fft(srcBuf);
            static if (false) {
                invBuf[0 .. BATCH_SIZE / 2] = fftFrame[0 .. BATCH_SIZE / 2];
                invBuf[$ - BATCH_SIZE / 2 .. $] = fftFrame[BATCH_SIZE / 2 .. $];
                invBuf[BATCH_SIZE / 2 .. $ - BATCH_SIZE / 2] = Complex!double(0, 0);
            } else {
                invBuf[0 .. BATCH_SIZE] = fftFrame[0 .. BATCH_SIZE];
                invBuf[BATCH_SIZE .. $] = Complex!double(0, 0);
            }
            Complex!double[] upsampledFrame = ifft.inverseFft(invBuf);
            for (int i = 0; i < BATCH_SIZE * 2; i++) {
                int index = x * 4 + i  + BATCH_SIZE;
                if (index >= 0 && index < res.frames)
                    res.data.ptr[index] = upsampledFrame[i + BATCH_SIZE].re;
            }
            int reslen = cast(int)fftFrame.length;
            reslen++;
        }
        return res;
    }
}

