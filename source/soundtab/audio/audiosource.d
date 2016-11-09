module soundtab.audio.audiosource;

enum AUDIO_SOURCE_SILENCE_FLAG = 1;

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

    /// get audio source volume (0 .. 1.0f)
    @property float volume() {
        return _volume;
    }

    /// set audio source volume (0 .. 1.0f)
    @property AudioSource volume(float v) {
        lock();
        scope(exit)unlock();
        if (v < 0.00001) {
            // volume = 0
            _volume = 0;
            _zeroVolume = true;
            _unityVolume = false;
        } else if (v >= 0.999) {
            // volume = 100%
            _volume = 1.0f;
            _zeroVolume = false;
            _unityVolume = true;
        } else {
            // arbitrary volume
            _zeroVolume = false;
            _unityVolume = false;
            _volume = v;
        }
        return this;
    }

    protected float _volume = 1.0f;
    protected bool _zeroVolume = false;
    protected bool _unityVolume = true;
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
            float * floatBuf = cast(float*)buf;
            float sample1f = cast(float)(sample1 / 32768.0f);
            *(floatBuf++) = sample1f;
            if (channels > 1) {
                float sample2f = cast(float)(sample2 / 32768.0f);
                *(floatBuf++) = sample2f;
                if (channels > 2) {
                    *(floatBuf++) = sample1f;
                    if (channels > 3) {
                        *(floatBuf++) = sample2f;
                        if (channels > 4) {
                            *(floatBuf++) = sample1f;
                            if (channels > 5)
                                *(floatBuf++) = sample2f;
                        }
                    }
                }
            }
        } else {
            limitShortRange(sample1);
            limitShortRange(sample2);
            short * shortBuf = cast(short*)buf;
            *(shortBuf++) = cast(short)sample1;
            if (channels > 1)
                *(shortBuf++) = cast(short)sample2;
            if (channels > 2)
                *(shortBuf++) = cast(short)sample1;
            if (channels > 3)
                *(shortBuf++) = cast(short)sample2;
            if (channels > 4)
                *(shortBuf++) = cast(short)sample1;
            if (channels > 5)
                *(shortBuf++) = cast(short)sample2;
        }
    }

    /// put samples in float format
    protected void putSamples(ubyte * buf, float sample1, float sample2) {
        if (sampleFormat == SampleFormat.float32) {
            float * floatBuf = cast(float*)buf;
            *(floatBuf++) = sample1;
            if (channels > 1) {
                *(floatBuf++) = sample2;
                if (channels > 2) {
                    *(floatBuf++) = sample1;
                    if (channels > 3) {
                        *(floatBuf++) = sample2;
                        if (channels > 4) {
                            *(floatBuf++) = sample1;
                            if (channels > 5)
                                *(floatBuf++) = sample2;
                        }
                    }
                }
            }
        } else if (sampleFormat == SampleFormat.signed16) {
            short * shortBuf = cast(short*)buf;
            int sample1i = cast(int)(sample1 * 32767.0f);
            int sample2i = cast(int)(sample2 * 32767.0f);
            limitShortRange(sample1i);
            limitShortRange(sample2i);
            *(shortBuf++) = cast(short)sample1i;
            if (channels > 1)
                *(shortBuf++) = cast(short)sample2i;
            if (channels > 2)
                *(shortBuf++) = cast(short)sample1i;
            if (channels > 3)
                *(shortBuf++) = cast(short)sample2i;
            if (channels > 4)
                *(shortBuf++) = cast(short)sample1i;
            if (channels > 5)
                *(shortBuf++) = cast(short)sample2i;
        } else {
            // unsupported format
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

/// Mixer which can mix several audio sources
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
            flags |= AUDIO_SOURCE_SILENCE_FLAG;
            return true;
        }
        int bufSize = frameCount * channels;
        if (_mixBuffer.length < bufSize)
            _mixBuffer.length = bufSize;
        if (_sourceBuffer.length < bufSize)
            _sourceBuffer.length = bufSize;
        bool hasNonSilent = false;
        uint tmpFlags = 0;
        // load data from first source
        _sources[0].loadData(frameCount, cast(ubyte*)_mixBuffer.ptr, tmpFlags);
        if (!(tmpFlags & AUDIO_SOURCE_SILENCE_FLAG))
            hasNonSilent = true;
        // mix data from rest of sources
        for(int i = 1; i < _sources.length; i++) {
            tmpFlags = 0;
            _sources[i].loadData(frameCount, cast(ubyte*)_sourceBuffer.ptr, tmpFlags);
            if (!(tmpFlags & AUDIO_SOURCE_SILENCE_FLAG)) {
                hasNonSilent = true;
                for (int j = 0; j < bufSize; j++)
                    _mixBuffer[j] += _sourceBuffer[j];
            }
        }
        if (!hasNonSilent) {
            // only silent sources present
            generateSilence(frameCount, buf);
            flags |= AUDIO_SOURCE_SILENCE_FLAG;
            return true;
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
