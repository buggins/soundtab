module soundtab.audio.mp3player;

import soundtab.audio.audiosource;
import dlangui.core.logger;
import derelict.mpg123;

private __gshared bool mpg123Loaded;
private __gshared bool mpg123Error;

private bool loadMPG123() {
    if (mpg123Loaded)
        return true;
    if (mpg123Error)
        return false;
    try {
        DerelictMPG123.load();
        Log.i("libmpg123 shared library is loaded ok");
        mpg123Loaded = true;
        mpg123_init();
    } catch (Exception e) {
        Log.e("Cannot load libmpg123 shared library", e);
        mpg123Error = true;
    }
    return mpg123Loaded;
}

void uninitMP3Decoder() {
    if (mpg123Loaded)
        mpg123_exit();
}

struct PlayPosition {
    /// current playback position, seconds
    float currentPosition;
    /// total length, seconds
    float length;

    /// returns current position as percent*100 : 0..10000
    @property int positionPercent() {
        if (length < 0.1)
            return 0;
        int res = cast(int)(10000 * currentPosition / length);
        if (res < 0)
            res = 0;
        if (res > 10000)
            res = 10000;
        return res;
    }

    float percentToSeconds(int percent) {
        return percent * length / 10000;
    }
}

class Mp3Player : AudioSource {
    private string _filename;
    private bool _loaded;
    private int _sourceChannels = 2;
    private int _sourceEncoding;
    private int _sourceRate;
    private short[] _sourceData;
    private int _sourcePosition;
    private int _sourceFrames;
    private bool _paused = true;

    @property bool paused() { return _paused; }
    @property Mp3Player paused(bool pauseFlag) {
        _paused = pauseFlag;
        return this;
    }

    /// returns current filename
    @property string filename() {
        lock();
        scope(exit)unlock();
        return _filename;
    }

    /// set current filename and load MP3 file; returns true if successful
    @property bool filename(string filename) {
        return loadFromFile(filename);
    }

    /// get current play position and total track length (seconds)
    @property PlayPosition position() {
        lock();
        scope(exit)unlock();
        if (!_loaded)
            return PlayPosition(0, 0);
        return PlayPosition(_sourcePosition / cast(float)_sourceRate, _sourceFrames / cast(float)_sourceRate);
    }

    /// set current play position (seconds)
    @property void position(float positionSeconds) {
        lock();
        scope(exit)unlock();
        if (!_loaded)
            return;
        int newPosition = cast(int)(positionSeconds * _sourceRate);
        if (newPosition < 0)
            newPosition = 0;
        if (newPosition > _sourceFrames)
            newPosition = _sourceFrames;
        _sourcePosition = newPosition;
    }

    @property bool loaded() { return _loaded; }
    /// returns playback position frame number
    @property int sourcePosition() { 
        lock();
        scope(exit)unlock();
        return _loaded ? _sourcePosition : 0; 
    }
    /// sets playback position frame number
    @property void sourcePosition(int newPosition) { 
        lock();
        scope(exit)unlock();
        if (newPosition < 0)
            newPosition = 0;
        if (newPosition > _sourceFrames)
            newPosition = _sourceFrames;
        _sourcePosition = newPosition;
    }

    /// load MP3 file
    bool loadFromFile(string filename) {
        import std.string : toStringz;
        {
            lock();
            scope(exit)unlock();
            _loaded = false;
            _sourcePosition = 0;
            _paused = true;
            if (_filename == filename) {
                // opening the same file as already opened - just move to start
                return true;
            }
            _filename = null;
            _sourceData = null;
            _sourceFrames = 0;
        }
        if (!loadMPG123()) {
            Log.e("No MPG123 library found - cannot decode MP3");
            return false;
        }
        int error = 0;
        mpg123_handle * mh = mpg123_new(null, &error);
        int res = mpg123_open(mh, filename.toStringz);
        if (res == MPG123_OK) {
            res =  mpg123_getformat(mh, &_sourceRate, &_sourceChannels, &_sourceEncoding);
            if (res == MPG123_OK) {
                Log.d("mp3 file rate=", _sourceRate, " channels=", _sourceChannels, " enc=", _sourceEncoding);
                int bufferSize = cast(int)mpg123_outblock(mh);
                Log.d("buffer size=", bufferSize);
                bufferSize *= 4;
                ubyte[] buffer = new ubyte[bufferSize];
                short[] outbuffer;
                short * pbuf = cast(short*)buffer.ptr;
                outbuffer.assumeSafeAppend;
                size_t done = 0;
                size_t bytesRead = 0;
                for (;;) {
                    res = mpg123_read(mh, buffer.ptr, bufferSize, &done);
                    if (res != MPG123_OK) {
                        Log.d("Error while decoding: ", res);
                        break;
                    }
                    bytesRead += bufferSize;
                    if (!done) {
                        break;
                    }
                    outbuffer ~= pbuf[0 .. done/2];
                }
                Log.d("Bytes decoded: ", bytesRead, " outBufferLength=", outbuffer.length);
                if (_sourceChannels >= 1 && outbuffer.length > 0) {
                    lock();
                    scope(exit)unlock();
                    _sourceData = outbuffer;
                    _loaded = true;
                    _filename = filename;
                    _sourcePosition = 0;
                    _sourceFrames = cast(int)(_sourceData.length / _sourceChannels);
                }
            }

            mpg123_close(mh);
        }

        mpg123_delete(mh);

        return _loaded;
    }

    /// load data into buffer
    override bool loadData(int frameCount, ubyte * buf, ref uint flags) {
        lock();
        scope(exit)unlock();
        flags = 0;
        // silence
        if (!_loaded || _paused || !_sourceFrames || _zeroVolume || _sourcePosition >= _sourceFrames) {
            generateSilence(frameCount, buf);
            flags |= AUDIO_SOURCE_SILENCE_FLAG;
            return true;
        }
        int i = 0;
        int srcpos = _sourcePosition * _sourceChannels;
        if (_sourceRate != samplesPerSecond) {
            // need resampling
            // simple get-nearest-frame resampler
            int srcFrames = cast(int)(cast(long)frameCount * _sourceRate / samplesPerSecond);
            //Log.d("Resampling ", srcFrames, " -> ", frameCount, " (", _sourceRate, "->", samplesPerSecond, ")");
            for (; i < frameCount; i++) {
                int index = (i * srcFrames / frameCount + _sourcePosition) * _sourceChannels;
                if (index + _sourceChannels - 1 < _sourceData.length) {
                    float sample1 = _sourceData.ptr[index] / 32768.0f;
                    float sample2 = _sourceChannels > 1 ? _sourceData.ptr[index + 1] / 32768.0f : sample1;
                    if (!_unityVolume) {
                        sample1 *= _volume;
                        sample2 *= _volume;
                    }
                    putSamples(buf, sample1, sample2);
                } else {
                    putSamples(buf, 0.0f, 0.0f);
                }
                buf += blockAlign;
            }
            _sourcePosition += srcFrames;
            if (_sourcePosition > _sourceFrames)
                _sourcePosition = _sourceFrames;
        } else {
            // no resampling
            for (; i < frameCount; i++) {
                float sample1 = _sourceData.ptr[srcpos++] / 32768.0f;
                float sample2 = _sourceChannels > 1 ? _sourceData.ptr[srcpos++] / 32768.0f : sample1;
                putSamples(buf, sample1, sample2);
                _sourcePosition++;
                if (_sourcePosition >= _sourceFrames)
                    break;
            }
            for (; i < frameCount; i++) {
                putSamples(buf, 0.0f, 0.0f);
            }
        }
        return true;
    }
}
