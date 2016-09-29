module soundtab.audio.utils;

import soundtab.audio.coreaudio;
import core.sys.windows.windows;
import core.sys.windows.objidl;
import core.sys.windows.wtypes;
import dlangui.core.logger;
import std.string;
import core.thread;


wstring getWstringProp(IPropertyStore propStore, const ref PROPERTYKEY key) {
    if (!propStore)
        return null;
    PROPVARIANT var;
    // Initialize container for property value.
    //PropVariantInit(&varName);
    // Get the endpoint's friendly-name property.
    HRESULT hr = propStore.GetValue(key, var);
    if (hr)
        return null; // not found
    if (var.vt == VARENUM.VT_BSTR) {
        return fromWstringz(var.bstrVal);
    }
    if (var.vt == VARENUM.VT_LPWSTR) {
        return fromWstringz(var.pwszVal);
    }
    Log.d("Unknown variant type ", var.vt);
    return null;
}

struct ComAutoPtr(T : IUnknown) {
    T ptr;
    alias ptr this;
    ref ComAutoPtr opAssign(T value) {
        if (ptr)
            clear();
        ptr = value;
        return this;
    }
    ~this() {
        clear();
    }
    @property bool isNull() {
        return !ptr;
    }
    void clear() {
        if (ptr) {
            ptr.Release();
            ptr = null;
        }
    }
}

struct WstrAutoPtr {
    LPWSTR ptr;
    alias ptr this;
    ref WstrAutoPtr opAssign(LPWSTR value) {
        if (value && ptr && value !is ptr)
            CoTaskMemFree(ptr);
        ptr = value;
        return this;
    }
    ~this() {
        if (ptr)
            CoTaskMemFree(ptr);
    }
    @property wstring toWstring() {
        if (!ptr)
            return null;
        return fromWstringz(ptr);
    }
    @property string toString() {
        if (!ptr)
            return null;
        import std.utf : toUTF8;
        return fromWstringz(ptr).toUTF8;
    }
    @property bool isNull() {
        return !ptr;
    }
}

struct PropVariant {
    PROPVARIANT var;
    alias var this;
    ~this() {
        PropVariantClear(&var);
    }
}

string getStringProp(IPropertyStore propStore, const ref PROPERTYKEY key) {
    if (!propStore)
        return null;
    PROPVARIANT var;
    // Initialize container for property value.
    //PropVariantInit(&varName);
    // Get the endpoint's friendly-name property.
    HRESULT hr = propStore.GetValue(key, var);
    if (hr)
        return null; // not found
    import std.utf;
    if (var.vt == VARENUM.VT_BSTR) {
        return fromWstringz(var.bstrVal).toUTF8;
    }
    if (var.vt == VARENUM.VT_LPWSTR) {
        return fromWstringz(var.pwszVal).toUTF8;
    }
    Log.d("Unknown variant type ", var.vt);
    return null;
}

class MMDevice {
    string id;
    string friendlyName;
    string interfaceName;
    string desc;
    uint state;
    bool isDefault;

    override string toString() {
        return (isDefault ? "DEFAULT:" : "") ~ id ~ " : \"" ~ friendlyName ~ "\"";
    }
}

class MMDevices {
    private bool _initialized = false;
    private IMMDeviceEnumerator _pEnum;
    this() {
    }
    @property bool initialized() { return _initialized; }

    /// get endpoint interface for device
    IMMEndpoint getEndpoint(MMDevice dev) {
        return getEndpoint(dev.id);
    }

    /// get endpoint interface by device id
    IMMDevice getDevice(string deviceId) {
        ComAutoPtr!IMMDeviceCollection pDevices;

        HRESULT hr = _pEnum.EnumAudioEndpoints(
                                               /* [in] */ 
                                               EDataFlow.eRender,
                                               /* [in] */ 
                                               DEVICE_STATE_ACTIVE, //DWORD dwStateMask,
                                               /* [out] */ 
                                               pDevices);
        if (hr) {
            Log.e("MMDeviceEnumerator.EnumAudioEndpoints failed");
            return null;
        }

        DWORD count;
        hr = pDevices.GetCount(count);

        for (DWORD i = 0; i < count; i++) {
            ComAutoPtr!IMMDevice pDevice;
            hr = pDevices.Item(i, pDevice);
            if (!hr) {
                WstrAutoPtr pId;
                hr = pDevice.GetId(pId);
                string id = pId.toString;
                if (id == deviceId) {
                    pDevice.AddRef();
                    return pDevice;
                }
            }
        }
        return null;
    }


    /// get endpoint interface by device id
    IMMEndpoint getEndpoint(string deviceId) {
        ComAutoPtr!IMMDevice pDevice;
        pDevice = getDevice(deviceId);
        if (!pDevice.isNull) {
            IMMEndpoint res;
            HRESULT hr = pDevice.QueryInterface(&IID_IMMEndpoint, cast(void**)(&res));
            if (hr) {
                Log.e("QueryInterface IID_IMMEndpoint failed for device ", deviceId);
                return null;
            }
            // FOUND!
            return res;
        }
        return null;
    }

    IAudioClient getAudioClient(string deviceId) {
        ComAutoPtr!IMMDevice pDevice;
        pDevice = getDevice(deviceId);
        if (!pDevice.isNull) {
            IAudioClient pAudioClient;
            HRESULT hr = pDevice.Activate(
                IID_IAudioClient, CLSCTX_ALL,
                null, cast(void**)&pAudioClient);
            if (hr) {
                Log.e("Activate IID_IAudioClient failed for device ", deviceId);
                return null;
            }
            return pAudioClient;
        }
        return null;
    }

    /// read device list
    MMDevice[] getPlaybackDevices() {
        import std.utf : toUTF8;
        if (!_initialized || !_pEnum)
            return null;

        HRESULT hr;
        string defDeviceId;
        {
            ComAutoPtr!IMMDevice defDevice;
            hr = _pEnum.GetDefaultAudioEndpoint( 
                    /* [in] */ 
                    EDataFlow.eRender,
                    /* [in] */ 
                    ERole.eMultimedia,
                    /* [out] */ 
                    defDevice);
            if (!hr) {
                WstrAutoPtr pId;
                hr = defDevice.GetId(pId);
                defDeviceId = pId.toString;
            }
        }
        Log.d("Default device ID=", defDeviceId);

        MMDevice[] res;
        ComAutoPtr!IMMDeviceCollection pDevices;
        hr = _pEnum.EnumAudioEndpoints(
                /* [in] */ 
                EDataFlow.eRender,
                /* [in] */ 
                DEVICE_STATE_ACTIVE, //DWORD dwStateMask,
                /* [out] */ 
                pDevices);
        if (hr) {
            Log.e("MMDeviceEnumerator.EnumAudioEndpoints failed");
            return null;
        }


        DWORD count;
        hr = pDevices.GetCount(count);

        int defaultIndex = -1;
        for (DWORD i = 0; i < count; i++) {
            ComAutoPtr!IMMDevice pDevice;
            hr = pDevices.Item(i, pDevice);
            if (!hr) {
                MMDevice dev = new MMDevice();
                WstrAutoPtr pId;
                hr = pDevice.GetId(pId);
                string id = pId.toString;
                DWORD state;
                hr = pDevice.GetState(state);

                dev.id = id;
                dev.state = state;

                ComAutoPtr!IPropertyStore propStore;
                hr = pDevice.OpenPropertyStore(STGM_READ, propStore);
                if (!hr) {
                    dev.friendlyName = propStore.getStringProp(DEVPKEY_Device_FriendlyName);
                    dev.interfaceName = propStore.getStringProp(DEVPKEY_DeviceInterface_FriendlyName);
                    dev.desc = propStore.getStringProp(DEVPKEY_Device_DeviceDesc);
                }
                dev.isDefault = dev.id == defDeviceId;
                if (dev.isDefault)
                    defaultIndex = i;
                //Log.d("ID: ", id, " state:", state, " friendlyName:", friendlyName, "\nintfName=", interfaceFriendlyName, "\ndesc:", deviceDesc);
                res ~= dev;
            }
        }
        // move default to top
        if (defaultIndex > 0) {
            // swap
            MMDevice tmp = res[0];
            res[0] = res[defaultIndex];
            res[defaultIndex] = tmp;
        }
        return res;
    }
    bool init() {
        HRESULT hr = CoCreateInstance(&CLSID_MMDeviceEnumerator, null,
                              CLSCTX_ALL, 
                              &IID_IMMDeviceEnumerator,
                              cast(void**)&_pEnum);
        if (hr) {
            Log.e("CoCreateInstance for MMDeviceEnumerator is failed");
            return false;
        }
        _initialized = true;
        return true;
    }
    void uninit() {
        if (_pEnum) {
            _pEnum.Release();
            _pEnum = null;
        }
    }
    ~this() {
        uninit();
    }
}

enum SampleFormat {
    signed16,
    float32
}

immutable WAVETABLE_SIZE_BITS = 14;
immutable WAVETABLE_SIZE = 1 << WAVETABLE_SIZE_BITS;
immutable WAVETABLE_SIZE_MASK = WAVETABLE_SIZE - 1;
immutable WAVETABLE_SIZE_MASK_MUL_256 = (1 << (WAVETABLE_SIZE_BITS + 8)) - 1;
immutable WAVETABLE_SCALE_BITS = 14;
immutable WAVETABLE_SCALE = (1 << WAVETABLE_SCALE_BITS);

int[] genWaveTableSin() {
    import std.math;
    int[] res;
    res.length = WAVETABLE_SIZE;
    for (int i = 0; i < WAVETABLE_SIZE; i++) {
        double f = i * 2 * PI / WAVETABLE_SIZE;
        double v = sin(f);
        res[i] = cast(int)(v * WAVETABLE_SCALE);
    }
    return res;
}

class MyAudioSource {

    void setSynthParams(double pitch, double gain, double controller1) {
        if (pitch < 16)
            pitch = 16;
        if (pitch > 12000)
            pitch = 12000;
        if (gain < 0)
            gain = 0;
        if (gain > 1)
            gain = 1;
        if (controller1 < 0)
            controller1 = 0;
        if (controller1 > 1)
            controller1 = 1;
        _targetPitch = pitch;
        _targetGain = gain;
        //_target
    }

    double _targetPitch = 1000; // Hz
    double _targetGain = 0; // 0..1
    double _currentPitch = 0; // Hz
    double _currentGain = 0; // 0..1

    int samplesPerSecond = 44100;
    int channels = 2;
    int bitsPerSample = 16;
    int blockAlign = 4;

    SampleFormat sampleFormat = SampleFormat.float32;

    int[] _wavetable;

    int _phase_mul_256 = 0;

    int _step_mul_256 = 0; // step*256 inside wavetable to generate requested frequency
    int _gain_mul_65536 = 0;


    this() {
        _wavetable = genWaveTableSin();
    }

    WAVEFORMATEXTENSIBLE _format;
    HRESULT SetFormat(WAVEFORMATEX * fmt) {
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
        _phase_mul_256 = 0;
        calcParams();
        return S_OK;
    }
    void calcParams() {
        _currentPitch = _targetPitch;
        _currentGain = _targetGain;
        double onePeriodSamples = samplesPerSecond / _currentPitch;
        double step = WAVETABLE_SIZE / onePeriodSamples;
        _step_mul_256 = cast(int)(step * 256);
        _gain_mul_65536 = cast(int)(_currentGain * 0x10000);
    }

    static union ShortConv {
        short value;
        byte[2] bytes;
    }

    static union FloatConv {
        float value;
        byte[4] bytes;
    }


    //int durationCounter = 100;

    HRESULT LoadData(DWORD frameCount, BYTE * buf, ref DWORD flags) {
        calcParams();
        Log.d("LoadData frameCount=", frameCount);
        ShortConv shortConv;
        FloatConv floatConv;

        for (int i = 0; i < frameCount; i++) {
            /// one step
            _phase_mul_256 = (_phase_mul_256 + _step_mul_256) & WAVETABLE_SIZE_MASK_MUL_256;
            int wt_value = _wavetable.ptr[_phase_mul_256 >> 8] * 2 / 3;
            int wt_value2 = _wavetable.ptr[((_phase_mul_256 * 2)&WAVETABLE_SIZE_MASK_MUL_256) >> 8] / 4;
            int wt_value3 = _wavetable.ptr[((_phase_mul_256 * 3)&WAVETABLE_SIZE_MASK_MUL_256) >> 8] / 5;
            wt_value += wt_value2 + wt_value3;
            int sample = (wt_value * _gain_mul_65536) >> 16;
            if (sampleFormat == SampleFormat.float32) {
                floatConv.value = cast(float)(sample / 65536.0);
                buf[0] = floatConv.bytes.ptr[0];
                buf[1] = floatConv.bytes.ptr[1];
                buf[2] = floatConv.bytes.ptr[2];
                buf[3] = floatConv.bytes.ptr[3];
                if (channels > 1) {
                    buf[4] = floatConv.bytes.ptr[4];
                    buf[5] = floatConv.bytes.ptr[5];
                    buf[6] = floatConv.bytes.ptr[6];
                    buf[7] = floatConv.bytes.ptr[7];
                }
                // TODO: more channels
            } else {
                shortConv.value = cast(short)(sample);
                buf[0] = floatConv.bytes.ptr[0];
                buf[1] = floatConv.bytes.ptr[1];
                if (channels > 1) {
                    buf[2] = floatConv.bytes.ptr[2];
                    buf[3] = floatConv.bytes.ptr[3];
                }
            }
            buf += blockAlign;
        }

        // TODO
        //durationCounter--;
        flags = 0; //durationCounter <= 0 ? AUDCLNT_BUFFERFLAGS.AUDCLNT_BUFFERFLAGS_SILENT : 0;
        return S_OK;
    }
}

/// audio playback thread
/// call start() to enable thread
/// use paused property to pause thread
class AudioPlayback : Thread {
    this() {
        super(&run);
        _devices = new MMDevices();
        _devices.init();
        MMDevice[] devices = getDevices();
        if (devices.length > 0)
            setDevice(devices[0]);
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
        _synth = synth;
    }
    private bool _running;
    private bool _paused;
    private bool _stopped;

    private MMDevice _requestedDevice;
    /// sets active device
    private void setDevice(MMDevice device) {
        _requestedDevice = device;
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

    private void playbackForDevice(MMDevice dev) {
        Log.d("playbackForDevice ", dev);
        MyAudioSource pMySource = _synth;
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
        hr = _audioClient.GetMixFormat(mixFormat);
        const REFTIMES_PER_SEC = 10000000; //10000000;
        const REFTIMES_PER_MILLISEC = REFTIMES_PER_SEC / 1000;
        //REFERENCE_TIME hnsRequestedDuration = REFTIMES_PER_SEC;
        hr = _audioClient.GetDevicePeriod(defaultDevicePeriod, minimumDevicePeriod);
        Log.d("defPeriod=", defaultDevicePeriod, " minPeriod=", minimumDevicePeriod);
        hr = _audioClient.Initialize(
                AUDCLNT_SHAREMODE.AUDCLNT_SHAREMODE_SHARED,
                0,
                minimumDevicePeriod, //hnsRequestedDuration,
                0, //hnsRequestedDuration, // 0
                mixFormat,
                null);
        if (checkError(hr, "AudioClient.Initialize failed")) return;

        UINT32 bufferFrameCount;

        hr = pMySource.SetFormat(mixFormat);

        hr = _audioClient.GetBufferSize(bufferFrameCount);
        if (checkError(hr, "AudioClient.GetBufferSize failed")) return;
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
        hr = pMySource.LoadData(bufferFrameCount, pData, flags);
        hr = pRenderClient.ReleaseBuffer(bufferFrameCount, flags);
        if (checkError(hr, "pRenderClient.ReleaseBuffer failed")) return;
        // Calculate the actual duration of the allocated buffer.
        REFERENCE_TIME hnsActualDuration;
        hnsActualDuration = cast(long)REFTIMES_PER_SEC * bufferFrameCount / mixFormat.nSamplesPerSec;
        hr = _audioClient.Start();  // Start playing.
        if (checkError(hr, "audioClient.Start() failed")) return;
        // Each loop fills about half of the shared buffer.
        while (flags != AUDCLNT_BUFFERFLAGS.AUDCLNT_BUFFERFLAGS_SILENT)
        {
            if (_paused || _stopped)
                break;
            UINT32 numFramesAvailable;
            UINT32 numFramesPadding;
            // Sleep for half the buffer duration.
            Sleep(cast(DWORD)(hnsActualDuration/REFTIMES_PER_MILLISEC/2));

            // See how much buffer space is available.
            hr = _audioClient.GetCurrentPadding(numFramesPadding);
            if (checkError(hr, "audioClient.GetCurrentPadding() failed")) break;

            numFramesAvailable = bufferFrameCount - numFramesPadding;

            // Grab all the available space in the shared buffer.
            hr = pRenderClient.GetBuffer(numFramesAvailable, pData);
            if (checkError(hr, "RenderClient.GetBuffer() failed")) break;

            // Get next 1/2-second of data from the audio source.
            hr = pMySource.LoadData(numFramesAvailable, pData, flags);

            hr = pRenderClient.ReleaseBuffer(numFramesAvailable, flags);
            if (checkError(hr, "RenderClient.ReleaseBuffer() failed")) break;
        }
        // Wait for last data in buffer to play before stopping.
        Sleep(cast(DWORD)(hnsActualDuration/REFTIMES_PER_MILLISEC/2));
        hr = _audioClient.Stop();
        if (checkError(hr, "audioClient.Stop() failed")) return;
    }

    private void run() {
        _running = true;
        auto hr = CoInitialize(null);
        try {
            while (!_stopped) {
                MMDevice dev;
                while (!dev && !_stopped) {
                    dev = _requestedDevice;
                    if (dev)
                        break;
                    // waiting for device is set
                    sleep(dur!"msecs"(10));
                }
                if (_paused) {
                    sleep(dur!"msecs"(10));
                    continue;
                }
                if (_stopped)
                    break;
                playbackForDevice(dev);
                _audioClient.clear();
            }
        } catch (Exception e) {
            Log.e("Exception in playback thread");
        }
        _running = false;
    }
}
