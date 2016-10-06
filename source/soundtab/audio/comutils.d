/**
    Helpers for using WASAPI.
*/
module soundtab.audio.comutils;
version(Windows):

import soundtab.audio.coreaudio;
import core.sys.windows.windows;
import core.sys.windows.objidl;
import core.sys.windows.wtypes;

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
    //Log.d("Unknown variant type ", var.vt);
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
    //Log.d("Unknown variant type ", var.vt);
    return null;
}

wstring fromWstringz(wchar * s) {
    if (!s)
        return null;
    int len = 0;
    for(; s[len]; len++) {
    }
    return s[0 .. len].dup;
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
            //Log.e("MMDeviceEnumerator.EnumAudioEndpoints failed");
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
                //Log.e("QueryInterface IID_IMMEndpoint failed for device ", deviceId);
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
                //Log.e("Activate IID_IAudioClient failed for device ", deviceId);
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
        //Log.d("Default device ID=", defDeviceId);

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
            //Log.e("MMDeviceEnumerator.EnumAudioEndpoints failed");
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
            //Log.e("CoCreateInstance for MMDeviceEnumerator is failed");
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
