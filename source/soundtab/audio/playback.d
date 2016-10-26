module soundtab.audio.playback;

import core.sys.windows.windows;
import core.sys.windows.objidl;
import core.sys.windows.wtypes;
import wasapi.coreaudio;
import wasapi.comutils;
import dlangui.core.logger;
import std.string;
import core.thread;
import soundtab.audio.instruments;

HRESULT GetStreamFormat(AUDCLNT_SHAREMODE mode, IAudioClient _audioClient, ref WAVEFORMATEXTENSIBLE mixFormat) {
    HRESULT hr;
    WAVEFORMATEXTENSIBLE format;
    format.cbSize = WAVEFORMATEXTENSIBLE.sizeof;
    format.wFormatTag = WAVE_FORMAT_EXTENSIBLE;
    format.wBitsPerSample = 32;

    int[] sampleRates = [48000, 96000, 44100, 192000];

    // FLOAT
    format.nChannels = 2;
    format.wValidBitsPerSample = 32;
    format.dwChannelMask = SPEAKER_FRONT_LEFT | SPEAKER_FRONT_RIGHT;
    format.SubFormat = MEDIASUBTYPE_IEEE_FLOAT;
    foreach(rate; sampleRates) {
        format.nSamplesPerSec = rate;
        format.nAvgBytesPerSec = format.nSamplesPerSec * format.nChannels * format.wBitsPerSample / 8;
        format.nBlockAlign = cast(WORD)(format.wBitsPerSample * format.nChannels / 8);
        WAVEFORMATEXTENSIBLE * match;
        hr = _audioClient.IsFormatSupported(mode, cast(WAVEFORMATEX*)&format, cast(WAVEFORMATEX**)&match);
        if (hr == S_OK || hr == S_FALSE) {
            if (!match)
                match = &format;
            if ((*match).wFormatTag == WAVE_FORMAT_EXTENSIBLE) {
                mixFormat = *match;
            } else {
                mixFormat.Format = match.Format;
            }
            Log.d("Found supported FLOAT format: samplesPerSec=", mixFormat.nSamplesPerSec, " nChannels=", mixFormat.nChannels, " bitsPerSample=", mixFormat.wBitsPerSample);
            return S_OK;
        }
    }

    // PCM 32
    format.wValidBitsPerSample = 32;
    format.wBitsPerSample = 32;
    format.dwChannelMask = SPEAKER_FRONT_LEFT | SPEAKER_FRONT_RIGHT;
    format.SubFormat = MEDIASUBTYPE_PCM;
    foreach(rate; sampleRates) {
        format.nSamplesPerSec = rate;
        format.nAvgBytesPerSec = format.nSamplesPerSec * format.nChannels * format.wBitsPerSample / 8;
        format.nBlockAlign = cast(WORD)(format.wBitsPerSample * format.nChannels / 8);
        WAVEFORMATEXTENSIBLE * match;
        hr = _audioClient.IsFormatSupported(mode, cast(WAVEFORMATEX*)&format, cast(WAVEFORMATEX**)&match);
        if (hr == S_OK || hr == S_FALSE) {
            if (!match)
                match = &format;
            if ((*match).wFormatTag == WAVE_FORMAT_EXTENSIBLE) {
                mixFormat = *match;
            } else {
                mixFormat.Format = match.Format;
            }
            Log.d("Found supported PCM32 format: samplesPerSec=", mixFormat.nSamplesPerSec, " nChannels=", mixFormat.nChannels, " bitsPerSample=", mixFormat.wBitsPerSample);
            return S_OK;
        }
    }

    // PCM 24
    format.wValidBitsPerSample = 24;
    format.wBitsPerSample = 32;
    format.dwChannelMask = SPEAKER_FRONT_LEFT | SPEAKER_FRONT_RIGHT;
    format.SubFormat = MEDIASUBTYPE_PCM;
    foreach(rate; sampleRates) {
        format.nSamplesPerSec = rate;
        format.nAvgBytesPerSec = format.nSamplesPerSec * format.nChannels * format.wBitsPerSample / 8;
        format.nBlockAlign = cast(WORD)(format.wBitsPerSample * format.nChannels / 8);
        WAVEFORMATEXTENSIBLE * match;
        hr = _audioClient.IsFormatSupported(mode, cast(WAVEFORMATEX*)&format, cast(WAVEFORMATEX**)&match);
        if (hr == S_OK || hr == S_FALSE) {
            if (!match)
                match = &format;
            if ((*match).wFormatTag == WAVE_FORMAT_EXTENSIBLE) {
                mixFormat = *match;
            } else {
                mixFormat.Format = match.Format;
            }
            Log.d("Found supported PCM24 format: samplesPerSec=", mixFormat.nSamplesPerSec, " nChannels=", mixFormat.nChannels, " bitsPerSample=", mixFormat.wBitsPerSample);
            return S_OK;
        }
    }

    // PCM 16
    format.wValidBitsPerSample = 16;
    format.wBitsPerSample = 16;
    format.dwChannelMask = SPEAKER_FRONT_LEFT | SPEAKER_FRONT_RIGHT;
    format.SubFormat = MEDIASUBTYPE_PCM;
    foreach(rate; sampleRates) {
        format.nSamplesPerSec = rate;
        format.nAvgBytesPerSec = format.nSamplesPerSec * format.nChannels * format.wBitsPerSample / 8;
        format.nBlockAlign = cast(WORD)(format.wBitsPerSample * format.nChannels / 8);
        WAVEFORMATEXTENSIBLE * match;
        hr = _audioClient.IsFormatSupported(mode, cast(WAVEFORMATEX*)&format, cast(WAVEFORMATEX**)&match);
        if (hr == S_OK || hr == S_FALSE) {
            if (!match)
                match = &format;
            if ((*match).wFormatTag == WAVE_FORMAT_EXTENSIBLE) {
                mixFormat = *match;
            } else {
                mixFormat.Format = match.Format;
            }
            Log.d("Found supported PCM16 format: samplesPerSec=", mixFormat.nSamplesPerSec, " nChannels=", mixFormat.nChannels, " bitsPerSample=", mixFormat.wBitsPerSample);
            return S_OK;
        }
    }
    


    format.cbSize = WAVEFORMATEX.sizeof;
    format.wFormatTag = WAVE_FORMAT_PCM;
    format.wBitsPerSample = 16;
    foreach(rate; sampleRates) {
        format.nSamplesPerSec = rate;
        format.nAvgBytesPerSec = format.nSamplesPerSec * format.nChannels * format.wBitsPerSample / 8;
        format.nBlockAlign = cast(WORD)(format.wBitsPerSample * format.nChannels / 8);
        format.SubFormat = MEDIASUBTYPE_IEEE_FLOAT;
        WAVEFORMATEXTENSIBLE * match;
        hr = _audioClient.IsFormatSupported(mode, cast(WAVEFORMATEX*)&format, cast(WAVEFORMATEX**)&match);
        if (hr == S_OK || hr == S_FALSE) {
            if (!match)
                match = &format;
            if ((*match).wFormatTag == WAVE_FORMAT_EXTENSIBLE) {
                mixFormat = *match;
            } else {
                mixFormat.Format = match.Format;
            }
            Log.d("Found supported format: samplesPerSec=", mixFormat.nSamplesPerSec, " nChannels=", mixFormat.nChannels, " bitsPerSample=", mixFormat.wBitsPerSample);
            return S_OK;
        }
    }
    return E_FAIL;
}

/// audio playback thread
/// call start() to enable thread
/// use paused property to pause thread
class AudioPlayback : Thread {

    import core.sync.mutex;
    private Mutex _mutex;
    void lock() { _mutex.lock(); }
    void unlock() { _mutex.unlock(); }

    this() {
        super(&run);
        _mutex = new Mutex();
        _devices = new MMDevices();
        _devices.init();
        //MMDevice[] devices = getDevices();
        //if (devices.length > 0)
        //    setDevice(devices[0]);
    }
    ~this() {
        stop();
        if (_devices) {
            destroy(_devices);
            _devices = null;
        }
    }
    private MyAudioSource _synth;
    private MMDevices _devices;
    void setSynth(MyAudioSource synth) {
        lockedPausedAction({
            _synth = synth;
        });
    }

    private bool _running;
    private bool _paused;
    private bool _stopped;

    private string _stateString = "No device selected";
    @property string stateString() {
        lock();
        scope(exit)unlock();
        return _stateString;
    }

    private MMDevice _requestedDevice;
    private bool _requestedExclusive;
    private int _requestedMinFrameMillis;

    private void lockedPausedAction(void delegate() action) {
        bool oldPaused = _paused;
        {
            lock();
            scope(exit)unlock();
            action();
        }
        if (running) {
            _paused = true;
            // pause to apply changed settings
            sleep(dur!"msecs"(20));
            _paused = oldPaused;
        }
    }

    private void updateStateString(string deviceName, bool paused, bool exclusive, int bufferMillis) {
        char[] res;
        if (deviceName.length) {
            res ~= deviceName;
            if (paused) {
                res ~= " [paused]";
            } else {
                if (exclusive)
                    res ~= " [exclusive mode] ";
                else
                    res ~= " [shared mode] ";
                if (bufferMillis) {
                    import std.conv : to;
                    res ~= "buffer:";
                    res ~= to!string(bufferMillis);
                    res ~= "ms";
                }
            }
        } else {
            res ~= "[no playback device selected]";
        }
        lock();
        scope(exit)unlock();
        _stateString = res.dup;
    }

    /// sets active device
    public void setDevice(MMDevice device, bool exclusive = true, int minFrameMillis = 3) {
        lockedPausedAction({
            _requestedDevice = device;
            _requestedExclusive = exclusive;
            _requestedMinFrameMillis = minFrameMillis;
        });
    }
    private MMDevice _currentDevice;

    /// returns list of available devices, default is first
    MMDevice[] getDevices() {
        return _devices.getPlaybackDevices();
    }

    /// returns true if playback thread is running
    @property bool running() { return _running; }
    /// get pause status
    @property bool paused() { return _paused; }
    /// play/stop
    @property void paused(bool pausedFlag) {
        if (_paused != pausedFlag) {
            _paused = pausedFlag;
            sleep(dur!"msecs"(10));
        }
    }

    void stop() {
        if (_running) {
            _stopped = true;
            while (_running)
                sleep(dur!"msecs"(10));
            join(false);
            _running = false;
        }
    }

    private ComAutoPtr!IAudioClient _audioClient;


    /// returns true if hr is error
    private bool checkError(HRESULT hr, string msg = "AUDIO ERROR") {
        if (hr) {
            Log.e(msg, " hresult=", "%08x".format(hr), " lastError=", GetLastError());
            return true;
        }
        return false;
    }

    WAVEFORMATEXTENSIBLE _format;
    HRESULT SetFormat(AudioSource pMySource, WAVEFORMATEX * fmt) {
        SampleFormat sampleFormat = SampleFormat.float32;
        int samplesPerSecond = 44100;
        int channels = 2;
        int bitsPerSample = 16;
        int blockAlign = 4;
        if (fmt.wFormatTag == WAVE_FORMAT_EXTENSIBLE) {
            WAVEFORMATEXTENSIBLE * formatEx = cast(WAVEFORMATEXTENSIBLE*)fmt;
            _format = *formatEx;
            sampleFormat = (_format.SubFormat == MEDIASUBTYPE_IEEE_FLOAT) ? SampleFormat.float32 : SampleFormat.signed16;
            channels = _format.nChannels;
            samplesPerSecond = _format.nSamplesPerSec;
            bitsPerSample = _format.wBitsPerSample;
            blockAlign = _format.nBlockAlign;
        } else {
            _format = *fmt;
            sampleFormat = (_format.wFormatTag == WAVE_FORMAT_IEEE_FLOAT) ? SampleFormat.float32 : SampleFormat.signed16;
            channels = _format.nChannels;
            samplesPerSecond = _format.nSamplesPerSec;
            bitsPerSample = _format.wBitsPerSample;
            blockAlign = _format.nBlockAlign;
        }
        if (pMySource)
            pMySource.setFormat(sampleFormat, channels, samplesPerSecond, bitsPerSample, blockAlign);
        return S_OK;
    }

    private void playbackForDevice(MMDevice dev, bool exclusive, int minFrameMillis) {
        Log.d("playbackForDevice ", dev);
        MyAudioSource pMySource = _synth;
        HANDLE hEvent, hTask;
        if (!pMySource)
            return;
        if (!_currentDevice || _currentDevice.id != dev.id || _audioClient.isNull) {
            // setting new device
            _audioClient = _devices.getAudioClient(dev.id);
            if (_audioClient.isNull) {
                sleep(dur!"msecs"(10));
                return;
            }
            _currentDevice = dev;
        }
        if (_audioClient.isNull || _paused || _stopped)
            return;
        // current device is selected
        UINT32 bufferSize;
        REFERENCE_TIME defaultDevicePeriod, minimumDevicePeriod;
        REFERENCE_TIME streamLatency;
        WAVEFORMATEX * mixFormat;
        HRESULT hr;
        if(exclusive) {
            // Call a helper function to negotiate with the audio
            // device for an exclusive-mode stream format.
            hr = GetStreamFormat(AUDCLNT_SHAREMODE.AUDCLNT_SHAREMODE_EXCLUSIVE, _audioClient, _format);
            if (hr) {
                return;
            }
            mixFormat = cast(WAVEFORMATEX*)&_format;
        } else {
            hr = _audioClient.GetMixFormat(mixFormat);
        }
        const REFTIMES_PER_SEC = 10000000; //10000000;
        const REFTIMES_PER_MILLISEC = REFTIMES_PER_SEC / 1000;
        //REFERENCE_TIME hnsRequestedDuration = REFTIMES_PER_SEC;
        hr = _audioClient.GetDevicePeriod(defaultDevicePeriod, minimumDevicePeriod);
        Log.d("defPeriod=", defaultDevicePeriod, " minPeriod=", minimumDevicePeriod);
        if (exclusive) {
            REFERENCE_TIME requestedPeriod = minimumDevicePeriod;
            for(int n = 1; n < 10; n++) {
                requestedPeriod = minimumDevicePeriod * n;
                if (requestedPeriod >= minFrameMillis * 10000)
                    break;
            }
            Log.d("exclusive mode, requested period=", requestedPeriod);
            hr = _audioClient.Initialize(
                    AUDCLNT_SHAREMODE.AUDCLNT_SHAREMODE_EXCLUSIVE,
                    AUDCLNT_STREAMFLAGS_EVENTCALLBACK,
                    requestedPeriod, //minimumDevicePeriod, //hnsRequestedDuration,
                    requestedPeriod, //hnsRequestedDuration, // 0
                    mixFormat,
                    null);
            //updateStateString(dev.friendlyName, false, exclusive, cast(int)(requestedPeriod / 10000));
        } else {
            hr = _audioClient.Initialize(
                    AUDCLNT_SHAREMODE.AUDCLNT_SHAREMODE_SHARED,
                    0,
                    defaultDevicePeriod, //minimumDevicePeriod, //hnsRequestedDuration,
                    0, //hnsRequestedDuration, // 0
                    mixFormat,
                    null);
        }
        if (checkError(hr, "AudioClient.Initialize failed")) return;

        UINT32 bufferFrameCount;

        hr = SetFormat(pMySource, mixFormat);
        if (exclusive) {
            hEvent = CreateEvent(NULL, FALSE, FALSE, NULL);
            hr = _audioClient.SetEventHandle(hEvent);
            if (checkError(hr, "AudioClient.SetEventHandle failed")) return;
        }

        hr = _audioClient.GetBufferSize(bufferFrameCount);
        if (checkError(hr, "AudioClient.GetBufferSize failed")) return;
        //if (!exclusive) {
            int millis = cast(int)(1000 * bufferFrameCount / mixFormat.nSamplesPerSec);
            updateStateString(dev.friendlyName, false, exclusive, millis);
        //}
        Log.d("Buffer frame count: ", bufferFrameCount);
        hr = _audioClient.GetStreamLatency(streamLatency);
        if (checkError(hr, "AudioClient.GetStreamLatency failed")) return;
        hr = _audioClient.GetDevicePeriod(defaultDevicePeriod, minimumDevicePeriod);
        if (checkError(hr, "AudioClient.GetDevicePeriod failed")) return;
        Log.d("Found audio client with bufferSize=", bufferFrameCount, " latency=", streamLatency, " defPeriod=", defaultDevicePeriod, " minPeriod=", minimumDevicePeriod);
        ComAutoPtr!IAudioRenderClient pRenderClient;
        hr = _audioClient.GetService(
                IID_IAudioRenderClient,
                cast(void**)&pRenderClient.ptr);
        if (checkError(hr, "AudioClient.GetService failed")) return;
        // Grab the entire buffer for the initial fill operation.
        BYTE *pData;
        DWORD flags;
        hr = pRenderClient.GetBuffer(bufferFrameCount, pData);
        if (checkError(hr, "RenderClient.GetBuffer failed")) return;
        pMySource.loadData(bufferFrameCount, pData, flags);
        hr = pRenderClient.ReleaseBuffer(bufferFrameCount, flags);
        if (checkError(hr, "pRenderClient.ReleaseBuffer failed")) return;
        // Calculate the actual duration of the allocated buffer.
        REFERENCE_TIME hnsActualDuration;
        hnsActualDuration = cast(long)REFTIMES_PER_SEC * bufferFrameCount / mixFormat.nSamplesPerSec;


        // Ask MMCSS to temporarily boost the thread priority
        // to reduce glitches while the low-latency stream plays.
        if (exclusive) {
            hTask = setHighThreadPriority();
            //hTask = cast(void*)1; //AvSetMmThreadCharacteristicsA("Pro Audio".ptr, taskIndex);
            if (!hTask) {
                hr = E_FAIL;
                if (checkError(hr, "AvSetMmThreadCharacteristics() failed")) return;
            }
        }

        hr = _audioClient.Start();  // Start playing.
        if (checkError(hr, "audioClient.Start() failed")) return;
        // Each loop fills about half of the shared buffer.
        while (flags != AUDCLNT_BUFFERFLAGS.AUDCLNT_BUFFERFLAGS_SILENT)
        {
            if (_paused || _stopped)
                break;
            UINT32 numFramesAvailable;
            UINT32 numFramesPadding;

            if (exclusive) {
                // Wait for next buffer event to be signaled.
                DWORD retval = WaitForSingleObject(hEvent, 1000);
                if (retval != WAIT_OBJECT_0)
                {
                    // Event handle timed out after a 2-second wait.
                    break;
                }
                numFramesAvailable = bufferFrameCount;
            } else {

                // Sleep for half the buffer duration.
                Sleep(cast(DWORD)(hnsActualDuration/REFTIMES_PER_MILLISEC/2));

                // See how much buffer space is available.
                hr = _audioClient.GetCurrentPadding(numFramesPadding);
                if (checkError(hr, "audioClient.GetCurrentPadding() failed")) break;

                numFramesAvailable = bufferFrameCount - numFramesPadding;
            }


            // Grab all the available space in the shared buffer.
            hr = pRenderClient.GetBuffer(numFramesAvailable, pData);
            if (checkError(hr, "RenderClient.GetBuffer() failed")) break;

            // Get next 1/2-second of data from the audio source.
            hr = pMySource.loadData(numFramesAvailable, pData, flags);

            hr = pRenderClient.ReleaseBuffer(numFramesAvailable, flags);
            if (checkError(hr, "RenderClient.ReleaseBuffer() failed")) break;
        }
        // Wait for last data in buffer to play before stopping.
        Sleep(cast(DWORD)(hnsActualDuration/REFTIMES_PER_MILLISEC/2));
        hr = _audioClient.Stop();
        if (hEvent)
        {
            CloseHandle(hEvent);
        }
        restoreThreadPriority(hTask);
        if (checkError(hr, "audioClient.Stop() failed")) return;
    }

    private void run() {
        _running = true;
        auto hr = CoInitialize(null);
        priority = PRIORITY_MAX;
        try {
            while (!_stopped) {
                MMDevice dev;
                bool exclusive;
                int minFrame;
                {
                    lock();
                    scope(exit)unlock();
                    dev = _requestedDevice;
                    exclusive = _requestedExclusive;
                    minFrame = _requestedMinFrameMillis;
                }
                if (!dev) {
                    // waiting for device is set
                    sleep(dur!"msecs"(10));
                    continue;
                }
                if (_paused) {
                    updateStateString(dev ? dev.friendlyName : null, true, exclusive, 0);
                    sleep(dur!"msecs"(10));
                    continue;
                }
                if (_stopped)
                    break;
                playbackForDevice(dev, exclusive, minFrame);
                _audioClient.clear();
            }
        } catch (Exception e) {
            Log.e("Exception in playback thread");
        }
        _running = false;
    }
}
