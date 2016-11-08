module soundtab.audio.audiosource;

enum SampleFormat {
    signed16,
    float32
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
