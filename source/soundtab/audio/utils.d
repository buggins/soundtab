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
        return id ~ " : \"" ~ friendlyName ~ "\"";
    }
}

class MMDevices {
    private bool _initialized = false;
    private IMMDeviceEnumerator _pEnum;
    this() {
    }
    @property bool initialized() { return _initialized; }
    /// read device list
    MMDevice[] getPlaybackDevices() {
        import std.utf : toUTF8;
        if (!_initialized || !_pEnum)
            return null;
        MMDevice[] res;
        ComAutoPtr!IMMDeviceCollection pDevices;
        auto hr = _pEnum.EnumAudioEndpoints(
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
        hr = pDevices.GetCount(&count);

        for (DWORD i = 0; i < count; i++) {
            ComAutoPtr!IMMDevice pDevice;
            hr = pDevices.Item(i, pDevice);
            if (!hr) {
                MMDevice dev = new MMDevice();
                WstrAutoPtr pId;
                hr = pDevice.GetId(pId);
                string id = fromWstringz(pId).toUTF8;
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
                //Log.d("ID: ", id, " state:", state, " friendlyName:", friendlyName, "\nintfName=", interfaceFriendlyName, "\ndesc:", deviceDesc);
                res ~= dev;
            }
        }
        return res;
    }
    bool init() {
        auto hr = CoInitialize(null);
        if (hr)
            Log.e("CoInitialize failed");
        hr = CoCreateInstance(&CLSID_MMDeviceEnumerator, null,
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
}

bool initAudio() {
    MMDevices devices = new MMDevices();
    if (!devices.init())
        return false;
    auto list = devices.getPlaybackDevices();
    if (!list)
        return false;
    Log.d("Device list: ", list);
    return true;
}
