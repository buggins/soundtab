module soundtab.audio.loader;

import derelict.mpg123;
import dlangui.core.logger;
public import soundtab.audio.wavefile;;

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

float[] shortToFloat(short[] buf, int step = 1) {
    float[] res = new float[buf.length / step];
    for(size_t i  = 0; i < res.length; i++) {
        res[i] = buf[i * step] / 32768.0f;
    }
    return res;
}

WaveFile loadSoundFileMP3(string filename, bool forceMono = false) {
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

private uint decodeUint(ubyte[] buf, int pos) {
    if (pos + 4 > buf.length)
        return 0;
    return cast(uint)buf[pos] | (cast(uint)buf[pos + 1] << 8) | (cast(uint)buf[pos + 2] << 16) | (cast(uint)buf[pos + 3] << 24);
}

private ushort decodeUshort(ubyte[] buf, int pos) {
    if (pos + 2 > buf.length)
        return 0;
    return cast(ushort)buf[pos] | (cast(uint)buf[pos + 1] << 8);
}

float decode24bitSample(ubyte[] buf, size_t pos) {
    uint v = cast(uint)buf[pos] | (cast(uint)buf[pos + 1] << 8) | (cast(uint)buf[pos + 2] << 16);
    if (v & 0x800000) // sign extension
        v |= 0xFF000000;
    return (cast(int)v) / cast(float)(0x800000);
}



struct RIFFChunkIterator {
    ubyte[] content;
    uint pos;
    ubyte[] chunkName;
    uint chunkSize;
    ubyte[] chunkData;
    bool init(ubyte[] data) {
        content = data;
        if (!content)
            return false;
        if (content.length < 100)
            return false;
        if (content[0..4] != ['R', 'I', 'F', 'F'])
            return false;
        if (content[8..12] != ['W', 'A', 'V', 'E'])
            return false;
        uint sz = decodeUint(content, 4);
        if (sz + 8 != content.length)
            return false;
        return nextChunk(12);
    }
    bool nextChunk(uint chunkFileOffset) {
        pos = chunkFileOffset;
        if (pos + 8 > content.length)
            return false;
        chunkName = content[pos .. pos + 4];
        chunkSize = decodeUint(content, pos + 4);
        if (pos + 8 + chunkSize > content.length)
            return false; // invalid chunk size
        chunkData = content[pos + 8 .. pos + 8 + chunkSize];
        return true;
    }
    bool nextChunk() {
        return nextChunk(pos + 8 + chunkSize);
    }
}

WaveFile loadSoundFileWAV(string filename, bool forceMono = false) {
    immutable ushort FORMAT_PCM = 1;
    immutable ushort FORMAT_FLOAT = 3;
    import std.file : read;
    import std.string : toStringz;
    ubyte[] content;
    try {
        content = cast(ubyte[])read(filename);
    } catch (Exception e) {
        //
    }
    RIFFChunkIterator riff;
    if (!riff.init(content)) {
        Log.e("Invalid RIFF file header in file ", filename);
        return null;
    }
    ubyte[] formatData;
    ubyte[] data;
    do {
        if (riff.chunkName == ['f', 'm', 't', ' ']) {
            formatData = riff.chunkData;
        } else if (riff.chunkName == ['d', 'a', 't', 'a']) {
            data = riff.chunkData;
        }
    } while (riff.nextChunk());

    if (!formatData) {
        Log.e("fmt chunk not found in file ", filename);
        return null;
    }
    if (!data) {
        Log.e("data chunk not found in file ", filename);
        return null;
    }
    if (formatData.length < 16 || formatData.length > 100)
        return null;
    ushort audioFormat = decodeUshort(formatData, 0);
    if (audioFormat != FORMAT_PCM && audioFormat != FORMAT_FLOAT)
        return null; // not a PCM nor float
    ushort nChannels = decodeUshort(formatData, 2);
    uint sampleRate = decodeUint(formatData, 4);
    uint byteRate = decodeUint(formatData, 8);
    ushort nAlign = decodeUshort(formatData, 12);
    ushort nBitsPerSample = decodeUshort(formatData, 14);
    if ((nBitsPerSample != 16 && nBitsPerSample != 24 && audioFormat == FORMAT_PCM) || (nBitsPerSample != 32 && audioFormat == FORMAT_FLOAT))
        return null;
    if (sampleRate < 11025 || sampleRate > 96000)
        return null;
    if (nAlign != nChannels * nBitsPerSample / 8)
        return null; // invalid align

    uint dataSize = cast(uint)data.length;
    uint nSamples = dataSize / nAlign;
    if (nSamples < 100)
        return null;
    WaveFile res = new WaveFile();
    res.filename = filename;
    res.frames = nSamples;
    res.sampleRate = sampleRate;
    res.channels = nChannels;
    int dstchannels = (forceMono ? 1 : nChannels);
    res.data = new float[dstchannels * nSamples];
    for (int i = 0; i < nSamples; i++) {
        for (int channel = 0; channel < nChannels; channel++) {
            if (channel >= dstchannels)
                break;
            int index = i * nChannels + channel;
            int dstindex = i * dstchannels + channel;
            float dst = 0;
            if (audioFormat == FORMAT_PCM) {
                if (nBitsPerSample == 24) {
                    dst = decode24bitSample(data, index * 3);
                } else {
                    ushort src = decodeUshort(data, (index * ushort.sizeof));
                    dst = (cast(short)src) / 32767.0f;
                }
            } else {
                // IEEE float format
                union convertUnion {
                    uint intvalue;
                    float floatvalue;
                }
                convertUnion tmp;

                tmp.intvalue = decodeUint(data, (index * uint.sizeof));
                dst = tmp.floatvalue;
            }
            res.data[dstindex] = dst;
        }
    }
    bool loaded = true;
    Log.i("Loaded sound file ", res.filename, " : sampleRate=", res.sampleRate, ", channels=", res.channels, " frames=", res.frames);
    return res;
}

WaveFile loadSoundFile(string filename, bool forceMono = false) {
    import std.algorithm : endsWith;
    if (filename.endsWith(".wav") || filename.endsWith(".WAV")) {
        WaveFile res = loadSoundFileWAV(filename, forceMono);
        if (!res)
            res = loadSoundFileMP3(filename, forceMono); // it could be MP3 inside WAV
        return res;
    }
    if (filename.endsWith(".mp3") || filename.endsWith(".MP3")) {
        return loadSoundFileMP3(filename, forceMono);
    }
    return null;
}
