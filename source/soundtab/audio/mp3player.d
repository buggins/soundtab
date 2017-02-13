module soundtab.audio.mp3player;

import soundtab.audio.audiosource;
public import soundtab.audio.loader;
import dlangui.core.logger;
import derelict.mpg123;

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
    private int _sourcePosition;
    private int _sourceFrames;
    protected int _loopStart;
    protected int _loopEnd;
    private bool _paused = true;
    private bool _ownWave;

    private WaveFile _file;

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
        return PlayPosition(_sourcePosition / cast(float)_file.sampleRate, _file.frames / cast(float)_file.sampleRate);
    }

    /// set current play position (seconds)
    @property void position(float positionSeconds) {
        lock();
        scope(exit)unlock();
        if (!_loaded)
            return;
        int newPosition = cast(int)(positionSeconds * _file.sampleRate);
        if (newPosition < 0)
            newPosition = 0;
        if (newPosition > _sourceFrames)
            newPosition = _sourceFrames;
        _sourcePosition = newPosition;
    }

    @property float loopStart() { return _file ? _file.frameToTime(_loopStart) : 0; }
    @property float loopEnd() { return _file ? _file.frameToTime(_loopEnd) : 0; }
    void removeLoop() {
        setLoop(0, 0);
    }
    void setLoop(float startSeconds, float endSeconds) {
        lock();
        scope(exit)unlock();
        if (!_loaded)
            return;
        int start = cast(int)(startSeconds * _file.sampleRate);
        int end = cast(int)(endSeconds * _file.sampleRate);
        _file.limitFrameIndex(start);
        _file.limitFrameIndex(end);
        if (start + 50 < end) {
            _loopStart = start;
            _loopEnd = end;
            _sourcePosition = _loopStart;
        } else {
            _loopStart = _loopEnd = 0;
        }
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


    protected void clear() {
        {
            lock();
            scope(exit)unlock();
            _loaded = false;
            _sourcePosition = 0;
            _paused = true;
            _filename = null;
            if (_file && _ownWave) {
                destroy(_file);
                _file = null;
            }
        }
    }

    // set loaded MP3 file
    bool setWave(WaveFile wave, bool ownWave = false) {
        if (_file is wave)
            return _loaded;
        import std.string : toStringz;
        clear();
        if (wave && wave.frames) {
            lock();
            scope(exit)unlock();
            _file = wave;
            _loaded = true;
            _ownWave = ownWave;
            _filename = wave.filename;
            _sourcePosition = 0;
            _sourceFrames = _file.frames;
        } else {
            // no file
        }
        return _loaded;
    }

    /// load MP3 file
    bool loadFromFile(string filename) {
        import std.string : toStringz;
        if (filename == _filename) {
            lock();
            scope(exit)unlock();
            // opening the same file as already opened - just move to start
            _sourcePosition = 0;
            _paused = true;
            return _loaded;
        }
        clear();
        WaveFile f = loadSoundFile(filename, false);
        if (f) {
            lock();
            scope(exit)unlock();
            _file = f;
            _ownWave = true;
            _loaded = true;
            _filename = filename;
            _sourcePosition = 0;
            _sourceFrames = _file.frames;
            Log.e("File is loaded");
        } else {
            Log.e("Load error");
        }
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
        int srcpos = _sourcePosition * _file.channels;
        bool inLoop = (_loopStart < _loopEnd && _sourcePosition >= _loopStart && _sourcePosition <= _loopEnd);
        if (_file.sampleRate != samplesPerSecond) {
            // need resampling
            // simple get-nearest-frame resampler
            float sampleTime = 1.0f / samplesPerSecond;
            float time = _file.frameToTime(_sourcePosition);
            for (; i < frameCount; i++) {
                float sample1 = _file.getSampleInterpolated(time, 0);
                float sample2 = _file.getSampleInterpolated(time, 1);
                if (!_unityVolume) {
                    sample1 *= _volume;
                    sample2 *= _volume;
                }
                putSamples(buf, sample1, sample2);
                buf += blockAlign;
                time += sampleTime;
                _sourcePosition = _file.timeToFrame(time);
                if (inLoop && _sourcePosition >= _loopEnd) {
                    _sourcePosition = _loopStart;
                    time = _file.frameToTime(_sourcePosition);
                }
            }
            if (_sourcePosition > _sourceFrames)
                _sourcePosition = _sourceFrames;
        } else {
            // no resampling
            for (; i < frameCount; i++) {
                float sample1 = _file.data.ptr[srcpos++];
                float sample2 = _file.channels > 1 ? _file.data.ptr[srcpos++] : sample1;
                if (!_unityVolume) {
                    sample1 *= _volume;
                    sample2 *= _volume;
                }
                putSamples(buf, sample1, sample2);
                buf += blockAlign;
                if (inLoop && _sourcePosition == _loopEnd)
                    _sourcePosition = _loopStart;
                else
                    _sourcePosition++;
                if (_sourcePosition >= _sourceFrames)
                    break;
            }
            for (; i < frameCount; i++) {
                putSamples(buf, 0.0f, 0.0f);
                buf += blockAlign;
            }
        }
        return true;
    }
}
