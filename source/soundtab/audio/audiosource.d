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

class Mixer : AudioSource {
    private AudioSource[] _sources;

    this() {
        _sources.assumeSafeAppend;
        _mixBuffer = new float[4096];
        _mixBuffer.assumeSafeAppend;
        _sourceBuffer = new float[4096];
        _sourceBuffer.assumeSafeAppend;
    }

    private AudioSource[] getSourcesSnapshot() {
        lock();
        scope(exit)unlock();
        AudioSource[] res = _sources.dup();
        return res;
    }

    /// add source to mixer
    void addSource(AudioSource source) {
        lock();
        scope(exit)unlock();
        foreach(s; _sources)
            if (s is source)
                return;
        _sources ~= source;
        setSourceFormat(source);
    }

    /// remove source from mixer
    void removeSource(AudioSource source) {
        lock();
        scope(exit)unlock();
        for (int i = 0; i < _sources.length; i++) {
            if (_sources[i] is source) {
                for (int j = i; j + 1 < _sources.length; j++)
                    _sources[j] = _sources[j + 1];
                _sources[$ - 1] = null;
                _sources.length = _sources.length - 1;
                return;
            }
        }
    }

    /// pass current format to source
    protected void setSourceFormat(AudioSource source) {
        source.setFormat(SampleFormat.float32, channels, samplesPerSecond, 32, 4*channels);
    }

    /// handle format change: pass same format to sources
    override protected void onFormatChanged() {
        // already called from lock
        foreach(source; _sources) {
            setSourceFormat(source);
        }
    }

    private float[] _mixBuffer;
    private float[] _sourceBuffer;
    /// load data into buffer
    override bool loadData(int frameCount, ubyte * buf, ref uint flags) {
        lock();
        scope(exit)unlock();
        flags = 0;
        // silence
        if (_sources.length == 0) {
            generateSilence(frameCount, buf);
            return true;
        }
        int bufSize = frameCount * channels;
        if (_mixBuffer.length < bufSize)
            _mixBuffer.length = bufSize;
        if (_sourceBuffer.length < bufSize)
            _sourceBuffer.length = bufSize;
        uint tmpFlags;
        // load data from first source
        _sources[0].loadData(frameCount, cast(ubyte*)_mixBuffer.ptr, tmpFlags);
        // mix data from rest of sources
        for(int i = 1; i < _sources.length; i++) {
            _sources[i].loadData(frameCount, cast(ubyte*)_sourceBuffer.ptr, tmpFlags);
            for (int j = 0; j < bufSize; j++)
                _mixBuffer[j] += _sourceBuffer[j];
        }
        // put to output
        if (sampleFormat == SampleFormat.float32) {
            // copy as is
            float * ptr = cast(float*)buf;
            ptr[0 .. bufSize] = _mixBuffer[0 .. bufSize];
        } else if (sampleFormat == SampleFormat.signed16) {
            // convert to short
            short * ptr = cast(short*)buf;
            for (int i = 0; i < bufSize; i++) {
                float v = _mixBuffer.ptr[i];
                int sample = cast(int)(v * 32767.0f);
                limitShortRange(sample);
                ptr[i] = cast(short)sample;
            }
        } else {
            // unsupported output format
            generateSilence(frameCount, buf);
        }
        return true;
    }
}
