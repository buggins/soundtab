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

class Mp3Player : AudioSource {
    private string _filename;
    private bool _loaded;
    private int _sourceChannels;
    private int _sourceEncoding;
    private int _sourceRate;
    private short[] _sourceData;
    private int _sourcePosition;

    @property bool loaded() { return _loaded; }
    /// returns playback position frame number
    @property int sourcePosition() { 
        lock();
        scope(exit)unlock();
        return _loaded ? _sourcePosition / _sourceChannels : 0; 
    }

    bool loadFromFile(string filename) {
        {
            lock();
            scope(exit)unlock();
            _loaded = false;
            _filename = null;
            _sourceData = null;
            _sourcePosition = 0;
        }
        if (!loadMPG123()) {
            Log.e("No MPG123 library found - cannot decode MP3");
            return false;
        }
        int error = 0;
        mpg123_handle * mh = mpg123_new(null, &error);
        int res = mpg123_open(mh, "jmj-chronologie3.mp3");
        if (res == MPG123_OK) {
            res =  mpg123_getformat(mh, &_sourceRate, &_sourceChannels, &_sourceEncoding);
            if (res == MPG123_OK) {
                Log.d("mp3 file rate=", _sourceRate, " channels=", _sourceChannels, " enc=", _sourceEncoding);
                int bufferSize = mpg123_outblock(mh);
                Log.d("buffer size=", bufferSize);
                ubyte[] buffer = new ubyte[bufferSize];
                short[] outbuffer;
                short * pbuf = cast(short*)buffer.ptr;
                outbuffer.assumeSafeAppend;
                uint done = 0;
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
                {
                    lock();
                    scope(exit)unlock();
                    _sourceData = outbuffer;
                    _loaded = true;
                    _filename = filename;
                    _sourcePosition = 0;
                }
            }

            mpg123_close(mh);
        }

        mpg123_delete(mh);

        return _loaded;
    }
}
