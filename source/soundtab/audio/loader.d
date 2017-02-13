module soundtab.audio.loader;

import derelict.mpg123;
import dlangui.core.logger;

private __gshared bool mpg123Loaded;
private __gshared bool mpg123Error;

bool loadMPG123() {
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
}

float[] shortToFloat(short[] buf, int step = 1) {
    float[] res = new float[buf.length / step];
    for(size_t i  = 0; i < res.length; i++) {
        res[i] = buf[i * step] / 32768.0f;
    }
    return res;
}

WaveFile loadSoundFile(string filename, bool forceMono = false) {
    import std.string : toStringz;
    WaveFile res = new WaveFile();
    bool loaded = true;
    if (!loadMPG123()) {
        Log.e("No MPG123 library found - cannot decode MP3");
        return null;
    }
    int error = 0;
    mpg123_handle * mh = mpg123_new(null, &error);
    int status = mpg123_open(mh, filename.toStringz);
    if (status == MPG123_OK) {
        int sourceEncoding;
        status =  mpg123_getformat(mh, &res.sampleRate, &res.channels, &sourceEncoding);
        if (status == MPG123_OK) {
            Log.d("mp3 file rate=", res.sampleRate, " channels=", res.channels, " enc=", sourceEncoding);
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
                status = mpg123_read(mh, buffer.ptr, bufferSize, &done);
                if (status != MPG123_OK) {
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
            if (res.channels >= 1 && outbuffer.length > 0) {
                int step = 1;
                if (forceMono) {
                    step = res.channels;
                    res.channels = 1;
                    Log.d("Forcing MONO");
                }
                res.data = shortToFloat(outbuffer, step);
                loaded = true;
                res.filename = filename;
                res.frames = cast(int)(res.data.length / res.channels);
                if (res.data.length % res.channels)
                    res.data.length = res.data.length - res.data.length % res.channels;
            }
        }

        mpg123_close(mh);
    }

    mpg123_delete(mh);
    if (loaded) {
        Log.i("Loaded sound file ", res.filename, " : sampleRate=", res.sampleRate, ", channels=", res.channels, " frames=", res.frames);
        return res; // loaded ok
    }
    // failed
    if (res)
        destroy(res);
    return null;
}
