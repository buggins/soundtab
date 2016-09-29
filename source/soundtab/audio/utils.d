module soundtab.audio.utils;

import soundtab.audio.coreaudio;
import core.sys.windows.windows;
import core.sys.windows.objidl;
import core.sys.windows.wtypes;
import dlangui.core.logger;
import std.string;


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
        ptr = value;
        return this;
    }
    ~this() {
        if (ptr)
            ptr.Release();
    }
    @property bool isNull() {
        return !ptr;
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

    double _targetPitch = 1000; // Hz
    double _targetGain = 0.5; // 0..1
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


    int durationCounter = 100;

    HRESULT LoadData(DWORD frameCount, BYTE * buf, ref DWORD flags) {
        calcParams();
        Log.d("LoadData frameCount=", frameCount);
        ShortConv shortConv;
        FloatConv floatConv;

        for (int i = 0; i < frameCount; i++) {
            /// one step
            _phase_mul_256 = (_phase_mul_256 + _step_mul_256) & WAVETABLE_SIZE_MASK_MUL_256;
            int wt_value = _wavetable.ptr[_phase_mul_256 >> 8];
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
        durationCounter--;
        flags = durationCounter <= 0 ? AUDCLNT_BUFFERFLAGS.AUDCLNT_BUFFERFLAGS_SILENT : 0;
        return S_OK;
    }
}

bool initAudio() {
    HRESULT hr;
    MMDevices devices = new MMDevices();
    if (!devices.init())
        return false;
    scope(exit) destroy(devices);

    auto list = devices.getPlaybackDevices();
    if (!list)
        return false;
    Log.d("Device list: ", list);

    MyAudioSource pMySource = new MyAudioSource();

    if (list.length > 0) {
        ComAutoPtr!IMMEndpoint endpoint;
        endpoint = devices.getEndpoint(list[0]);
        if (endpoint) {
            EDataFlow flow;
            hr = endpoint.GetDataFlow(flow);
            Log.d("Found endpoint with flow: ", flow);
        }
        ComAutoPtr!IAudioClient audioClient;
        audioClient = devices.getAudioClient(list[0].id);
        if (audioClient) {
            UINT32 bufferSize;
            REFERENCE_TIME streamLatency;
            WAVEFORMATEX * mixFormat;
            WAVEFORMATEXTENSIBLE * mixFormatEx;
            hr = audioClient.GetMixFormat(mixFormat);
            REFERENCE_TIME defaultDevicePeriod, minimumDevicePeriod;
            if (mixFormat) {
                Log.d("Mix format tag=", mixFormat.wFormatTag, " channels=", mixFormat.nChannels, " nSamplesPerSec=", mixFormat.nSamplesPerSec, " bitsPerSample=", mixFormat.wBitsPerSample);
                if (mixFormat.wFormatTag == WAVE_FORMAT_EXTENSIBLE) {
                    mixFormatEx = cast(WAVEFORMATEXTENSIBLE*)mixFormat;
                    Log.d("Extensible format, guid = ", mixFormatEx.SubFormat);
                    if (mixFormatEx.SubFormat == MEDIASUBTYPE_IEEE_FLOAT)
                        Log.d("This is IEEE_FLOAT format!");
                }
                //WAVE_FORMAT_PCM WAVE_FORMAT_IEEE_FLOAT WAVE_FORMAT_EXTENSIBLE
                //WAVE_FORMAT_IEEE_FLOAT;
            }
            const REFTIMES_PER_SEC = 100000000; //10000000;
            const REFTIMES_PER_MILLISEC = REFTIMES_PER_SEC / 1000;
            REFERENCE_TIME hnsRequestedDuration = REFTIMES_PER_SEC;
            hr = audioClient.GetDevicePeriod(defaultDevicePeriod, minimumDevicePeriod);
            Log.d("defPeriod=", defaultDevicePeriod, " minPeriod=", minimumDevicePeriod);
            hr = audioClient.Initialize(
                AUDCLNT_SHAREMODE.AUDCLNT_SHAREMODE_SHARED,
                //AUDCLNT_SHAREMODE.AUDCLNT_SHAREMODE_EXCLUSIVE,
                0,
                minimumDevicePeriod, //hnsRequestedDuration,
                0, //hnsRequestedDuration, // 0
                mixFormat,
                null);

            UINT32 bufferFrameCount;

            hr = pMySource.SetFormat(mixFormat);


            hr = audioClient.GetBufferSize(bufferFrameCount);
            Log.d("Buffer frame count: ", bufferFrameCount);
            hr = audioClient.GetStreamLatency(streamLatency);
            hr = audioClient.GetDevicePeriod(defaultDevicePeriod, minimumDevicePeriod);
            Log.d("Found audio client with bufferSize=", bufferFrameCount, " latency=", streamLatency, " defPeriod=", defaultDevicePeriod, " minPeriod=", minimumDevicePeriod);
            ComAutoPtr!IAudioRenderClient pRenderClient;
            hr = audioClient.GetService(
                IID_IAudioRenderClient,
                cast(void**)&pRenderClient.ptr);
            // Grab the entire buffer for the initial fill operation.
            BYTE *pData;
            DWORD flags;
            hr = pRenderClient.GetBuffer(bufferFrameCount, pData);
            hr = pMySource.LoadData(bufferFrameCount, pData, flags);
            hr = pRenderClient.ReleaseBuffer(bufferFrameCount, flags);
            // Calculate the actual duration of the allocated buffer.
            REFERENCE_TIME hnsActualDuration;
            hnsActualDuration = cast(long)REFTIMES_PER_SEC * bufferFrameCount / mixFormat.nSamplesPerSec;
            hr = audioClient.Start();  // Start playing.
            // Each loop fills about half of the shared buffer.
            while (flags != AUDCLNT_BUFFERFLAGS.AUDCLNT_BUFFERFLAGS_SILENT)
            {
                UINT32 numFramesAvailable;
                UINT32 numFramesPadding;
                // Sleep for half the buffer duration.
                Sleep(cast(DWORD)(hnsActualDuration/REFTIMES_PER_MILLISEC/2));

                // See how much buffer space is available.
                hr = audioClient.GetCurrentPadding(numFramesPadding);

                numFramesAvailable = bufferFrameCount - numFramesPadding;

                // Grab all the available space in the shared buffer.
                hr = pRenderClient.GetBuffer(numFramesAvailable, pData);

                // Get next 1/2-second of data from the audio source.
                hr = pMySource.LoadData(numFramesAvailable, pData, flags);

                hr = pRenderClient.ReleaseBuffer(numFramesAvailable, flags);
            }
            // Wait for last data in buffer to play before stopping.
            Sleep(cast(DWORD)(hnsActualDuration/REFTIMES_PER_MILLISEC/2));
            hr = audioClient.Stop();

        }
    }

    return true;
}
