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
    private bool _paused = true;

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
            if (_file) {
                destroy(_file);
                _file = null;
            }
        }
        WaveFile f = loadSoundFile(filename, false);
        if (f) {
            lock();
            scope(exit)unlock();
            _file = f;
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
        if (_file.sampleRate != samplesPerSecond) {
            // need resampling
            // simple get-nearest-frame resampler
            int srcFrames = cast(int)(cast(long)frameCount * _file.sampleRate / samplesPerSecond);
            //Log.d("Resampling ", srcFrames, " -> ", frameCount, " (", _file.sampleRate, "->", samplesPerSecond, ")");
            for (; i < frameCount; i++) {
                int index = (i * srcFrames / frameCount + _sourcePosition) * _file.channels;
                if (index + _file.channels - 1 < _file.data.length) {
                    float sample1 = _file.data.ptr[index];
                    float sample2 = _file.channels > 1 ? _file.data.ptr[index + 1] : sample1;
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
                float sample1 = _file.data.ptr[srcpos++];
                float sample2 = _file.channels > 1 ? _file.data.ptr[srcpos++] : sample1;
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
