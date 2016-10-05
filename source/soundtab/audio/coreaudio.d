module soundtab.audio.coreaudio;

import core.sys.windows.windows;
import core.sys.windows.objidl;
import core.sys.windows.wtypes;
//import core.sys.windows.propsys;
import dlangui.core.logger;
import std.string;

uint AUDCLNT_ERR(uint n)() { return n | 0x88890000; }

enum AUDCLNT_E_NOT_INITIALIZED              =AUDCLNT_ERR!(0x001);
enum AUDCLNT_E_ALREADY_INITIALIZED          =AUDCLNT_ERR!(0x002);
enum AUDCLNT_E_WRONG_ENDPOINT_TYPE          =AUDCLNT_ERR!(0x003);
enum AUDCLNT_E_DEVICE_INVALIDATED           =AUDCLNT_ERR!(0x004);
enum AUDCLNT_E_NOT_STOPPED                  =AUDCLNT_ERR!(0x005);
enum AUDCLNT_E_BUFFER_TOO_LARGE             =AUDCLNT_ERR!(0x006);
enum AUDCLNT_E_OUT_OF_ORDER                 =AUDCLNT_ERR!(0x007);
enum AUDCLNT_E_UNSUPPORTED_FORMAT           =AUDCLNT_ERR!(0x008);
enum AUDCLNT_E_INVALID_SIZE                 =AUDCLNT_ERR!(0x009);
enum AUDCLNT_E_DEVICE_IN_USE                =AUDCLNT_ERR!(0x00a);
enum AUDCLNT_E_BUFFER_OPERATION_PENDING     =AUDCLNT_ERR!(0x00b);
enum AUDCLNT_E_THREAD_NOT_REGISTERED        =AUDCLNT_ERR!(0x00c);
enum AUDCLNT_E_EXCLUSIVE_MODE_NOT_ALLOWED   =AUDCLNT_ERR!(0x00e);
enum AUDCLNT_E_ENDPOINT_CREATE_FAILED       =AUDCLNT_ERR!(0x00f);
enum AUDCLNT_E_SERVICE_NOT_RUNNING          =AUDCLNT_ERR!(0x010);
enum AUDCLNT_E_EVENTHANDLE_NOT_EXPECTED     =AUDCLNT_ERR!(0x011);
enum AUDCLNT_E_EXCLUSIVE_MODE_ONLY          =AUDCLNT_ERR!(0x012);
enum AUDCLNT_E_BUFDURATION_PERIOD_NOT_EQUAL =AUDCLNT_ERR!(0x013);
enum AUDCLNT_E_EVENTHANDLE_NOT_SET          =AUDCLNT_ERR!(0x014);
enum AUDCLNT_E_INCORRECT_BUFFER_SIZE        =AUDCLNT_ERR!(0x015);
enum AUDCLNT_E_BUFFER_SIZE_ERROR            =AUDCLNT_ERR!(0x016);
enum AUDCLNT_E_CPUUSAGE_EXCEEDED            =AUDCLNT_ERR!(0x017);
enum AUDCLNT_E_BUFFER_ERROR                 =AUDCLNT_ERR!(0x018);
enum AUDCLNT_E_BUFFER_SIZE_NOT_ALIGNED      =AUDCLNT_ERR!(0x019);
enum AUDCLNT_E_INVALID_DEVICE_PERIOD        =AUDCLNT_ERR!(0x020);
enum AUDCLNT_E_INVALID_STREAM_FLAG          =AUDCLNT_ERR!(0x021);
enum AUDCLNT_E_ENDPOINT_OFFLOAD_NOT_CAPABLE =AUDCLNT_ERR!(0x022);
enum AUDCLNT_E_OUT_OF_OFFLOAD_RESOURCES     =AUDCLNT_ERR!(0x023);
enum AUDCLNT_E_OFFLOAD_MODE_ONLY            =AUDCLNT_ERR!(0x024);
enum AUDCLNT_E_NONOFFLOAD_MODE_ONLY         =AUDCLNT_ERR!(0x025);
enum AUDCLNT_E_RESOURCES_INVALIDATED        =AUDCLNT_ERR!(0x026);
enum AUDCLNT_E_RAW_MODE_UNSUPPORTED         =AUDCLNT_ERR!(0x027);
enum AUDCLNT_E_ENGINE_PERIODICITY_LOCKED    =AUDCLNT_ERR!(0x028);
enum AUDCLNT_E_ENGINE_FORMAT_LOCKED         =AUDCLNT_ERR!(0x029);


/// Helper function to create GUID from string.
///
/// BCDE0395-E52F-467C-8E3D-C4579291692E -> GUID(0xBCDE0395, 0xE52F, 0x467C, [0x8E, 0x3D, 0xC4, 0x57, 0x92, 0x91, 0x69, 0x2E])
GUID makeGuid(string str)()
{
    static assert(str.length==36, "Guid string must be 36 chars long");
    enum GUIDstring = "GUID(0x" ~ str[0..8] ~ ", 0x" ~ str[9..13] ~ ", 0x" ~ str[14..18] ~
        ", [0x" ~ str[19..21] ~ ", 0x" ~ str[21..23] ~ ", 0x" ~ str[24..26] ~ ", 0x" ~ str[26..28]
        ~ ", 0x" ~ str[28..30] ~ ", 0x" ~ str[30..32] ~ ", 0x" ~ str[32..34] ~ ", 0x" ~ str[34..36] ~ "])";
    return mixin(GUIDstring);
}

extern (Windows):

wstring fromWstringz(wchar * s) {
    if (!s)
        return null;
    int len = 0;
    for(; s[len]; len++) {
    }
    return s[0 .. len].dup;
}

struct PROPERTYKEY
{
    GUID fmtid;
    DWORD pid;
}

alias DEVPROPGUID = GUID;
alias DEVPROPID = ULONG;

alias DEVPROPKEY = PROPERTYKEY;

//#define DEFINE_DEVPROPKEY(name, l, w1, w2, b1, b2, b3, b4, b5, b6, b7, b8, pid) EXTERN_C const DEVPROPKEY DECLSPEC_SELECTANY name = { { l, w1, w2, { b1, b2,  b3,  b4,  b5,  b6,  b7,  b8 } }, pid }

DEVPROPKEY DEFINE_DEVPROPKEY(DWORD l, WORD w1, WORD w2, BYTE b1, BYTE b2, BYTE b3, BYTE b4, BYTE b5, BYTE b6, BYTE b7, BYTE b8, ULONG pid)() {
    DEVPROPKEY a =
        { { l, w1, w2, [ b1, b2,  b3,  b4,  b5,  b6,  b7,  b8 ] }, pid };
    return a;
}

//
// DEVPKEY_NAME
// Common DEVPKEY used to retrieve the display name for an object.
//
const DEVPKEY_NAME = DEFINE_DEVPROPKEY!(0xb725f130, 0x47ef, 0x101a, 0xa5, 0xf1, 0x02, 0x60, 0x8c, 0x9e, 0xeb, 0xac, 10);    // DEVPROP_TYPE_STRING


//
// Device properties
// These DEVPKEYs correspond to the SetupAPI SPDRP_XXX device properties.
//
const DEVPKEY_Device_DeviceDesc = DEFINE_DEVPROPKEY!(0xa45c254e, 0xdf1c, 0x4efd, 0x80, 0x20, 0x67, 0xd1, 0x46, 0xa8, 0x50, 0xe0, 2);     // DEVPROP_TYPE_STRING
const DEVPKEY_Device_HardwareIds = DEFINE_DEVPROPKEY!(0xa45c254e, 0xdf1c, 0x4efd, 0x80, 0x20, 0x67, 0xd1, 0x46, 0xa8, 0x50, 0xe0, 3);     // DEVPROP_TYPE_STRING_LIST
const DEVPKEY_Device_CompatibleIds = DEFINE_DEVPROPKEY!(0xa45c254e, 0xdf1c, 0x4efd, 0x80, 0x20, 0x67, 0xd1, 0x46, 0xa8, 0x50, 0xe0, 4);     // DEVPROP_TYPE_STRING_LIST
const DEVPKEY_Device_Service = DEFINE_DEVPROPKEY!(0xa45c254e, 0xdf1c, 0x4efd, 0x80, 0x20, 0x67, 0xd1, 0x46, 0xa8, 0x50, 0xe0, 6);     // DEVPROP_TYPE_STRING
const DEVPKEY_Device_Class = DEFINE_DEVPROPKEY!(0xa45c254e, 0xdf1c, 0x4efd, 0x80, 0x20, 0x67, 0xd1, 0x46, 0xa8, 0x50, 0xe0, 9);     // DEVPROP_TYPE_STRING
const DEVPKEY_Device_ClassGuid = DEFINE_DEVPROPKEY!(0xa45c254e, 0xdf1c, 0x4efd, 0x80, 0x20, 0x67, 0xd1, 0x46, 0xa8, 0x50, 0xe0, 10);    // DEVPROP_TYPE_GUID
const DEVPKEY_Device_Driver = DEFINE_DEVPROPKEY!(0xa45c254e, 0xdf1c, 0x4efd, 0x80, 0x20, 0x67, 0xd1, 0x46, 0xa8, 0x50, 0xe0, 11);    // DEVPROP_TYPE_STRING
const DEVPKEY_Device_ConfigFlags = DEFINE_DEVPROPKEY!(0xa45c254e, 0xdf1c, 0x4efd, 0x80, 0x20, 0x67, 0xd1, 0x46, 0xa8, 0x50, 0xe0, 12);    // DEVPROP_TYPE_UINT32
const DEVPKEY_Device_Manufacturer = DEFINE_DEVPROPKEY!(0xa45c254e, 0xdf1c, 0x4efd, 0x80, 0x20, 0x67, 0xd1, 0x46, 0xa8, 0x50, 0xe0, 13);    // DEVPROP_TYPE_STRING
const DEVPKEY_Device_FriendlyName = DEFINE_DEVPROPKEY!(0xa45c254e, 0xdf1c, 0x4efd, 0x80, 0x20, 0x67, 0xd1, 0x46, 0xa8, 0x50, 0xe0, 14);    // DEVPROP_TYPE_STRING
const DEVPKEY_Device_LocationInfo = DEFINE_DEVPROPKEY!(0xa45c254e, 0xdf1c, 0x4efd, 0x80, 0x20, 0x67, 0xd1, 0x46, 0xa8, 0x50, 0xe0, 15);    // DEVPROP_TYPE_STRING
const DEVPKEY_Device_PDOName = DEFINE_DEVPROPKEY!(0xa45c254e, 0xdf1c, 0x4efd, 0x80, 0x20, 0x67, 0xd1, 0x46, 0xa8, 0x50, 0xe0, 16);    // DEVPROP_TYPE_STRING
const DEVPKEY_Device_Capabilities = DEFINE_DEVPROPKEY!(0xa45c254e, 0xdf1c, 0x4efd, 0x80, 0x20, 0x67, 0xd1, 0x46, 0xa8, 0x50, 0xe0, 17);    // DEVPROP_TYPE_UNINT32
const DEVPKEY_Device_UINumber = DEFINE_DEVPROPKEY!(0xa45c254e, 0xdf1c, 0x4efd, 0x80, 0x20, 0x67, 0xd1, 0x46, 0xa8, 0x50, 0xe0, 18);    // DEVPROP_TYPE_STRING
const DEVPKEY_Device_UpperFilters = DEFINE_DEVPROPKEY!(0xa45c254e, 0xdf1c, 0x4efd, 0x80, 0x20, 0x67, 0xd1, 0x46, 0xa8, 0x50, 0xe0, 19);    // DEVPROP_TYPE_STRING_LIST
const DEVPKEY_Device_LowerFilters = DEFINE_DEVPROPKEY!(0xa45c254e, 0xdf1c, 0x4efd, 0x80, 0x20, 0x67, 0xd1, 0x46, 0xa8, 0x50, 0xe0, 20);    // DEVPROP_TYPE_STRING_LIST
const DEVPKEY_Device_BusTypeGuid = DEFINE_DEVPROPKEY!(0xa45c254e, 0xdf1c, 0x4efd, 0x80, 0x20, 0x67, 0xd1, 0x46, 0xa8, 0x50, 0xe0, 21);    // DEVPROP_TYPE_GUID
const DEVPKEY_Device_LegacyBusType = DEFINE_DEVPROPKEY!(0xa45c254e, 0xdf1c, 0x4efd, 0x80, 0x20, 0x67, 0xd1, 0x46, 0xa8, 0x50, 0xe0, 22);    // DEVPROP_TYPE_UINT32
const DEVPKEY_Device_BusNumber = DEFINE_DEVPROPKEY!(0xa45c254e, 0xdf1c, 0x4efd, 0x80, 0x20, 0x67, 0xd1, 0x46, 0xa8, 0x50, 0xe0, 23);    // DEVPROP_TYPE_UINT32
const DEVPKEY_Device_EnumeratorName = DEFINE_DEVPROPKEY!(0xa45c254e, 0xdf1c, 0x4efd, 0x80, 0x20, 0x67, 0xd1, 0x46, 0xa8, 0x50, 0xe0, 24);    // DEVPROP_TYPE_STRING
const DEVPKEY_Device_Security = DEFINE_DEVPROPKEY!(0xa45c254e, 0xdf1c, 0x4efd, 0x80, 0x20, 0x67, 0xd1, 0x46, 0xa8, 0x50, 0xe0, 25);    // DEVPROP_TYPE_SECURITY_DESCRIPTOR
const DEVPKEY_Device_SecuritySDS = DEFINE_DEVPROPKEY!(0xa45c254e, 0xdf1c, 0x4efd, 0x80, 0x20, 0x67, 0xd1, 0x46, 0xa8, 0x50, 0xe0, 26);    // DEVPROP_TYPE_SECURITY_DESCRIPTOR_STRING
const DEVPKEY_Device_DevType = DEFINE_DEVPROPKEY!(0xa45c254e, 0xdf1c, 0x4efd, 0x80, 0x20, 0x67, 0xd1, 0x46, 0xa8, 0x50, 0xe0, 27);    // DEVPROP_TYPE_UINT32
const DEVPKEY_Device_Exclusive = DEFINE_DEVPROPKEY!(0xa45c254e, 0xdf1c, 0x4efd, 0x80, 0x20, 0x67, 0xd1, 0x46, 0xa8, 0x50, 0xe0, 28);    // DEVPROP_TYPE_BOOLEAN
const DEVPKEY_Device_Characteristics = DEFINE_DEVPROPKEY!(0xa45c254e, 0xdf1c, 0x4efd, 0x80, 0x20, 0x67, 0xd1, 0x46, 0xa8, 0x50, 0xe0, 29);    // DEVPROP_TYPE_UINT32
const DEVPKEY_Device_Address = DEFINE_DEVPROPKEY!(0xa45c254e, 0xdf1c, 0x4efd, 0x80, 0x20, 0x67, 0xd1, 0x46, 0xa8, 0x50, 0xe0, 30);    // DEVPROP_TYPE_UINT32
const DEVPKEY_Device_UINumberDescFormat = DEFINE_DEVPROPKEY!(0xa45c254e, 0xdf1c, 0x4efd, 0x80, 0x20, 0x67, 0xd1, 0x46, 0xa8, 0x50, 0xe0, 31);    // DEVPROP_TYPE_STRING
const DEVPKEY_Device_PowerData = DEFINE_DEVPROPKEY!(0xa45c254e, 0xdf1c, 0x4efd, 0x80, 0x20, 0x67, 0xd1, 0x46, 0xa8, 0x50, 0xe0, 32);    // DEVPROP_TYPE_BINARY
const DEVPKEY_Device_RemovalPolicy = DEFINE_DEVPROPKEY!(0xa45c254e, 0xdf1c, 0x4efd, 0x80, 0x20, 0x67, 0xd1, 0x46, 0xa8, 0x50, 0xe0, 33);    // DEVPROP_TYPE_UINT32
const DEVPKEY_Device_RemovalPolicyDefault = DEFINE_DEVPROPKEY!(0xa45c254e, 0xdf1c, 0x4efd, 0x80, 0x20, 0x67, 0xd1, 0x46, 0xa8, 0x50, 0xe0, 34);    // DEVPROP_TYPE_UINT32
const DEVPKEY_Device_RemovalPolicyOverride = DEFINE_DEVPROPKEY!(0xa45c254e, 0xdf1c, 0x4efd, 0x80, 0x20, 0x67, 0xd1, 0x46, 0xa8, 0x50, 0xe0, 35);    // DEVPROP_TYPE_UINT32
const DEVPKEY_Device_InstallState = DEFINE_DEVPROPKEY!(0xa45c254e, 0xdf1c, 0x4efd, 0x80, 0x20, 0x67, 0xd1, 0x46, 0xa8, 0x50, 0xe0, 36);    // DEVPROP_TYPE_UINT32
const DEVPKEY_Device_LocationPaths = DEFINE_DEVPROPKEY!(0xa45c254e, 0xdf1c, 0x4efd, 0x80, 0x20, 0x67, 0xd1, 0x46, 0xa8, 0x50, 0xe0, 37);    // DEVPROP_TYPE_STRING_LIST
const DEVPKEY_Device_BaseContainerId = DEFINE_DEVPROPKEY!(0xa45c254e, 0xdf1c, 0x4efd, 0x80, 0x20, 0x67, 0xd1, 0x46, 0xa8, 0x50, 0xe0, 38);    // DEVPROP_TYPE_GUID!

//
// Device properties
// These DEVPKEYs correspond to a device's status and problem code.
//
const DEVPKEY_Device_DevNodeStatus = DEFINE_DEVPROPKEY!(0x4340a6c5, 0x93fa, 0x4706, 0x97, 0x2c, 0x7b, 0x64, 0x80, 0x08, 0xa5, 0xa7, 2);     // DEVPROP_TYPE_UINT32
const DEVPKEY_Device_ProblemCode = DEFINE_DEVPROPKEY!(0x4340a6c5, 0x93fa, 0x4706, 0x97, 0x2c, 0x7b, 0x64, 0x80, 0x08, 0xa5, 0xa7, 3);     // DEVPROP_TYPE_UINT32

//
// Device properties
// These DEVPKEYs correspond to a device's relations.
//
const DEVPKEY_Device_EjectionRelations = DEFINE_DEVPROPKEY!(0x4340a6c5, 0x93fa, 0x4706, 0x97, 0x2c, 0x7b, 0x64, 0x80, 0x08, 0xa5, 0xa7, 4);     // DEVPROP_TYPE_STRING_LIST
const DEVPKEY_Device_RemovalRelations = DEFINE_DEVPROPKEY!(0x4340a6c5, 0x93fa, 0x4706, 0x97, 0x2c, 0x7b, 0x64, 0x80, 0x08, 0xa5, 0xa7, 5);     // DEVPROP_TYPE_STRING_LIST
const DEVPKEY_Device_PowerRelations = DEFINE_DEVPROPKEY!(0x4340a6c5, 0x93fa, 0x4706, 0x97, 0x2c, 0x7b, 0x64, 0x80, 0x08, 0xa5, 0xa7, 6);     // DEVPROP_TYPE_STRING_LIST
const DEVPKEY_Device_BusRelations = DEFINE_DEVPROPKEY!(0x4340a6c5, 0x93fa, 0x4706, 0x97, 0x2c, 0x7b, 0x64, 0x80, 0x08, 0xa5, 0xa7, 7);     // DEVPROP_TYPE_STRING_LIST
const DEVPKEY_Device_Parent = DEFINE_DEVPROPKEY!(0x4340a6c5, 0x93fa, 0x4706, 0x97, 0x2c, 0x7b, 0x64, 0x80, 0x08, 0xa5, 0xa7, 8);     // DEVPROP_TYPE_STRING
const DEVPKEY_Device_Children = DEFINE_DEVPROPKEY!(0x4340a6c5, 0x93fa, 0x4706, 0x97, 0x2c, 0x7b, 0x64, 0x80, 0x08, 0xa5, 0xa7, 9);     // DEVPROP_TYPE_STRING_LIST
const DEVPKEY_Device_Siblings = DEFINE_DEVPROPKEY!(0x4340a6c5, 0x93fa, 0x4706, 0x97, 0x2c, 0x7b, 0x64, 0x80, 0x08, 0xa5, 0xa7, 10);    // DEVPROP_TYPE_STRING_LIST
const DEVPKEY_Device_TransportRelations = DEFINE_DEVPROPKEY!(0x4340a6c5, 0x93fa, 0x4706, 0x97, 0x2c, 0x7b, 0x64, 0x80, 0x08, 0xa5, 0xa7, 11);    // DEVPROP_TYPE_STRING_LIST

//
// Other Device properties
// These DEVPKEYs are set for the corresponding types of root-enumerated devices.     ;comment
//
const DEVPKEY_Device_Reported = DEFINE_DEVPROPKEY!(0x80497100, 0x8c73, 0x48b9, 0xaa, 0xd9, 0xce, 0x38, 0x7e, 0x19, 0xc5, 0x6e, 2);     // DEVPROP_TYPE_BOOLEAN
const DEVPKEY_Device_Legacy = DEFINE_DEVPROPKEY!(0x80497100, 0x8c73, 0x48b9, 0xaa, 0xd9, 0xce, 0x38, 0x7e, 0x19, 0xc5, 0x6e, 3);     // DEVPROP_TYPE_BOOLEAN

//
// Device Instance Id
//
const DEVPKEY_Device_InstanceId = DEFINE_DEVPROPKEY!(0x78c34fc8, 0x104a, 0x4aca, 0x9e, 0xa4, 0x52, 0x4d, 0x52, 0x99, 0x6e, 0x57, 256);   // DEVPROP_TYPE_STRING

//
// Device Container Id
//
const DEVPKEY_Device_ContainerId = DEFINE_DEVPROPKEY!(0x8c7ed206, 0x3f8a, 0x4827, 0xb3, 0xab, 0xae, 0x9e, 0x1f, 0xae, 0xfc, 0x6c, 2);     // DEVPROP_TYPE_GUID

//
// Device Experience related Keys
//
const DEVPKEY_Device_ModelId = DEFINE_DEVPROPKEY!(0x80d81ea6, 0x7473, 0x4b0c, 0x82, 0x16, 0xef, 0xc1, 0x1a, 0x2c, 0x4c, 0x8b, 2);     // DEVPROP_TYPE_GUID
const DEVPKEY_Device_FriendlyNameAttributes = DEFINE_DEVPROPKEY!(0x80d81ea6, 0x7473, 0x4b0c, 0x82, 0x16, 0xef, 0xc1, 0x1a, 0x2c, 0x4c, 0x8b, 3);     // DEVPROP_TYPE_UINT32
const DEVPKEY_Device_ManufacturerAttributes = DEFINE_DEVPROPKEY!(0x80d81ea6, 0x7473, 0x4b0c, 0x82, 0x16, 0xef, 0xc1, 0x1a, 0x2c, 0x4c, 0x8b, 4);     // DEVPROP_TYPE_UINT32
const DEVPKEY_Device_PresenceNotForDevice = DEFINE_DEVPROPKEY!(0x80d81ea6, 0x7473, 0x4b0c, 0x82, 0x16, 0xef, 0xc1, 0x1a, 0x2c, 0x4c, 0x8b, 5);     // DEVPROP_TYPE_BOOLEAN

//
// Other Device properties
//
const DEVPKEY_Numa_Proximity_Domain = DEFINE_DEVPROPKEY!(0x540b947e, 0x8b40, 0x45bc, 0xa8, 0xa2, 0x6a, 0x0b, 0x89, 0x4c, 0xbd, 0xa2, 1);     // DEVPROP_TYPE_UINT32
const DEVPKEY_Device_DHP_Rebalance_Policy = DEFINE_DEVPROPKEY!(0x540b947e, 0x8b40, 0x45bc, 0xa8, 0xa2, 0x6a, 0x0b, 0x89, 0x4c, 0xbd, 0xa2, 2);     // DEVPROP_TYPE_UINT32
const DEVPKEY_Device_Numa_Node = DEFINE_DEVPROPKEY!(0x540b947e, 0x8b40, 0x45bc, 0xa8, 0xa2, 0x6a, 0x0b, 0x89, 0x4c, 0xbd, 0xa2, 3);     // DEVPROP_TYPE_UINT32
const DEVPKEY_Device_BusReportedDeviceDesc = DEFINE_DEVPROPKEY!(0x540b947e, 0x8b40, 0x45bc, 0xa8, 0xa2, 0x6a, 0x0b, 0x89, 0x4c, 0xbd, 0xa2, 4);     // DEVPROP_TYPE_STRING


//
// Device Session Id
//
const DEVPKEY_Device_SessionId = DEFINE_DEVPROPKEY!(0x83da6326, 0x97a6, 0x4088, 0x94, 0x53, 0xa1, 0x92, 0x3f, 0x57, 0x3b, 0x29, 6);     // DEVPROP_TYPE_UINT32

//
// Device activity timestamp properties
//
const DEVPKEY_Device_InstallDate = DEFINE_DEVPROPKEY!(0x83da6326, 0x97a6, 0x4088, 0x94, 0x53, 0xa1, 0x92, 0x3f, 0x57, 0x3b, 0x29, 100);   // DEVPROP_TYPE_FILETIME
const DEVPKEY_Device_FirstInstallDate = DEFINE_DEVPROPKEY!(0x83da6326, 0x97a6, 0x4088, 0x94, 0x53, 0xa1, 0x92, 0x3f, 0x57, 0x3b, 0x29, 101);   // DEVPROP_TYPE_FILETIME

//
// Device driver properties
//
const DEVPKEY_Device_DriverDate = DEFINE_DEVPROPKEY!(0xa8b865dd, 0x2e3d, 0x4094, 0xad, 0x97, 0xe5, 0x93, 0xa7, 0xc, 0x75, 0xd6, 2);      // DEVPROP_TYPE_FILETIME
const DEVPKEY_Device_DriverVersion = DEFINE_DEVPROPKEY!(0xa8b865dd, 0x2e3d, 0x4094, 0xad, 0x97, 0xe5, 0x93, 0xa7, 0xc, 0x75, 0xd6, 3);      // DEVPROP_TYPE_STRING
const DEVPKEY_Device_DriverDesc = DEFINE_DEVPROPKEY!(0xa8b865dd, 0x2e3d, 0x4094, 0xad, 0x97, 0xe5, 0x93, 0xa7, 0xc, 0x75, 0xd6, 4);      // DEVPROP_TYPE_STRING
const DEVPKEY_Device_DriverInfPath = DEFINE_DEVPROPKEY!(0xa8b865dd, 0x2e3d, 0x4094, 0xad, 0x97, 0xe5, 0x93, 0xa7, 0xc, 0x75, 0xd6, 5);      // DEVPROP_TYPE_STRING
const DEVPKEY_Device_DriverInfSection = DEFINE_DEVPROPKEY!(0xa8b865dd, 0x2e3d, 0x4094, 0xad, 0x97, 0xe5, 0x93, 0xa7, 0xc, 0x75, 0xd6, 6);      // DEVPROP_TYPE_STRING
const DEVPKEY_Device_DriverInfSectionExt = DEFINE_DEVPROPKEY!(0xa8b865dd, 0x2e3d, 0x4094, 0xad, 0x97, 0xe5, 0x93, 0xa7, 0xc, 0x75, 0xd6, 7);      // DEVPROP_TYPE_STRING
const DEVPKEY_Device_MatchingDeviceId = DEFINE_DEVPROPKEY!(0xa8b865dd, 0x2e3d, 0x4094, 0xad, 0x97, 0xe5, 0x93, 0xa7, 0xc, 0x75, 0xd6, 8);      // DEVPROP_TYPE_STRING
const DEVPKEY_Device_DriverProvider = DEFINE_DEVPROPKEY!(0xa8b865dd, 0x2e3d, 0x4094, 0xad, 0x97, 0xe5, 0x93, 0xa7, 0xc, 0x75, 0xd6, 9);      // DEVPROP_TYPE_STRING
const DEVPKEY_Device_DriverPropPageProvider = DEFINE_DEVPROPKEY!(0xa8b865dd, 0x2e3d, 0x4094, 0xad, 0x97, 0xe5, 0x93, 0xa7, 0xc, 0x75, 0xd6, 10);     // DEVPROP_TYPE_STRING
const DEVPKEY_Device_DriverCoInstallers = DEFINE_DEVPROPKEY!(0xa8b865dd, 0x2e3d, 0x4094, 0xad, 0x97, 0xe5, 0x93, 0xa7, 0xc, 0x75, 0xd6, 11);     // DEVPROP_TYPE_STRING_LIST
const DEVPKEY_Device_ResourcePickerTags = DEFINE_DEVPROPKEY!(0xa8b865dd, 0x2e3d, 0x4094, 0xad, 0x97, 0xe5, 0x93, 0xa7, 0xc, 0x75, 0xd6, 12);     // DEVPROP_TYPE_STRING
const DEVPKEY_Device_ResourcePickerExceptions = DEFINE_DEVPROPKEY!(0xa8b865dd, 0x2e3d, 0x4094, 0xad, 0x97, 0xe5, 0x93, 0xa7, 0xc, 0x75, 0xd6, 13);   // DEVPROP_TYPE_STRING
const DEVPKEY_Device_DriverRank = DEFINE_DEVPROPKEY!(0xa8b865dd, 0x2e3d, 0x4094, 0xad, 0x97, 0xe5, 0x93, 0xa7, 0xc, 0x75, 0xd6, 14);     // DEVPROP_TYPE_UINT32
const DEVPKEY_Device_DriverLogoLevel = DEFINE_DEVPROPKEY!(0xa8b865dd, 0x2e3d, 0x4094, 0xad, 0x97, 0xe5, 0x93, 0xa7, 0xc, 0x75, 0xd6, 15);     // DEVPROP_TYPE_UINT32

//
// Device properties
// These DEVPKEYs may be set by the driver package installed for a device.
//
const DEVPKEY_Device_NoConnectSound = DEFINE_DEVPROPKEY!(0xa8b865dd, 0x2e3d, 0x4094, 0xad, 0x97, 0xe5, 0x93, 0xa7, 0xc, 0x75, 0xd6, 17);     // DEVPROP_TYPE_BOOLEAN
const DEVPKEY_Device_GenericDriverInstalled = DEFINE_DEVPROPKEY!(0xa8b865dd, 0x2e3d, 0x4094, 0xad, 0x97, 0xe5, 0x93, 0xa7, 0xc, 0x75, 0xd6, 18);     // DEVPROP_TYPE_BOOLEAN
const DEVPKEY_Device_AdditionalSoftwareRequested = DEFINE_DEVPROPKEY!(0xa8b865dd, 0x2e3d, 0x4094, 0xad, 0x97, 0xe5, 0x93, 0xa7, 0xc, 0x75, 0xd6, 19); //DEVPROP_TYPE_BOOLEAN

//
// Device safe-removal properties
//
const DEVPKEY_Device_SafeRemovalRequired = DEFINE_DEVPROPKEY!(0xafd97640,  0x86a3, 0x4210, 0xb6, 0x7c, 0x28, 0x9c, 0x41, 0xaa, 0xbe, 0x55, 2);    // DEVPROP_TYPE_BOOLEAN
const DEVPKEY_Device_SafeRemovalRequiredOverride = DEFINE_DEVPROPKEY!(0xafd97640,  0x86a3, 0x4210, 0xb6, 0x7c, 0x28, 0x9c, 0x41, 0xaa, 0xbe, 0x55, 3); // DEVPROP_TYPE_BOOLEAN

//
// Device properties
// These DEVPKEYs may be set by the driver package installed for a device.
//
const DEVPKEY_DrvPkg_Model = DEFINE_DEVPROPKEY!(0xcf73bb51, 0x3abf, 0x44a2, 0x85, 0xe0, 0x9a, 0x3d, 0xc7, 0xa1, 0x21, 0x32, 2);     // DEVPROP_TYPE_STRING
const DEVPKEY_DrvPkg_VendorWebSite = DEFINE_DEVPROPKEY!(0xcf73bb51, 0x3abf, 0x44a2, 0x85, 0xe0, 0x9a, 0x3d, 0xc7, 0xa1, 0x21, 0x32, 3);     // DEVPROP_TYPE_STRING
const DEVPKEY_DrvPkg_DetailedDescription = DEFINE_DEVPROPKEY!(0xcf73bb51, 0x3abf, 0x44a2, 0x85, 0xe0, 0x9a, 0x3d, 0xc7, 0xa1, 0x21, 0x32, 4);     // DEVPROP_TYPE_STRING
const DEVPKEY_DrvPkg_DocumentationLink = DEFINE_DEVPROPKEY!(0xcf73bb51, 0x3abf, 0x44a2, 0x85, 0xe0, 0x9a, 0x3d, 0xc7, 0xa1, 0x21, 0x32, 5);     // DEVPROP_TYPE_STRING
const DEVPKEY_DrvPkg_Icon = DEFINE_DEVPROPKEY!(0xcf73bb51, 0x3abf, 0x44a2, 0x85, 0xe0, 0x9a, 0x3d, 0xc7, 0xa1, 0x21, 0x32, 6);     // DEVPROP_TYPE_STRING_LIST
const DEVPKEY_DrvPkg_BrandingIcon = DEFINE_DEVPROPKEY!(0xcf73bb51, 0x3abf, 0x44a2, 0x85, 0xe0, 0x9a, 0x3d, 0xc7, 0xa1, 0x21, 0x32, 7);     // DEVPROP_TYPE_STRING_LIST


//
// Device setup class properties
// These DEVPKEYs correspond to the SetupAPI SPCRP_XXX setup class properties.
//
const DEVPKEY_DeviceClass_UpperFilters = DEFINE_DEVPROPKEY!(0x4321918b, 0xf69e, 0x470d, 0xa5, 0xde, 0x4d, 0x88, 0xc7, 0x5a, 0xd2, 0x4b, 19);    // DEVPROP_TYPE_STRING_LIST
const DEVPKEY_DeviceClass_LowerFilters = DEFINE_DEVPROPKEY!(0x4321918b, 0xf69e, 0x470d, 0xa5, 0xde, 0x4d, 0x88, 0xc7, 0x5a, 0xd2, 0x4b, 20);    // DEVPROP_TYPE_STRING_LIST
const DEVPKEY_DeviceClass_Security = DEFINE_DEVPROPKEY!(0x4321918b, 0xf69e, 0x470d, 0xa5, 0xde, 0x4d, 0x88, 0xc7, 0x5a, 0xd2, 0x4b, 25);    // DEVPROP_TYPE_SECURITY_DESCRIPTOR
const DEVPKEY_DeviceClass_SecuritySDS = DEFINE_DEVPROPKEY!(0x4321918b, 0xf69e, 0x470d, 0xa5, 0xde, 0x4d, 0x88, 0xc7, 0x5a, 0xd2, 0x4b, 26);    // DEVPROP_TYPE_SECURITY_DESCRIPTOR_STRING
const DEVPKEY_DeviceClass_DevType = DEFINE_DEVPROPKEY!(0x4321918b, 0xf69e, 0x470d, 0xa5, 0xde, 0x4d, 0x88, 0xc7, 0x5a, 0xd2, 0x4b, 27);    // DEVPROP_TYPE_UINT32
const DEVPKEY_DeviceClass_Exclusive = DEFINE_DEVPROPKEY!(0x4321918b, 0xf69e, 0x470d, 0xa5, 0xde, 0x4d, 0x88, 0xc7, 0x5a, 0xd2, 0x4b, 28);    // DEVPROP_TYPE_BOOLEAN
const DEVPKEY_DeviceClass_Characteristics = DEFINE_DEVPROPKEY!(0x4321918b, 0xf69e, 0x470d, 0xa5, 0xde, 0x4d, 0x88, 0xc7, 0x5a, 0xd2, 0x4b, 29);    // DEVPROP_TYPE_UINT32

//
// Device setup class properties
//
const DEVPKEY_DeviceClass_Name = DEFINE_DEVPROPKEY!(0x259abffc, 0x50a7, 0x47ce, 0xaf, 0x8, 0x68, 0xc9, 0xa7, 0xd7, 0x33, 0x66, 2);      // DEVPROP_TYPE_STRING
const DEVPKEY_DeviceClass_ClassName = DEFINE_DEVPROPKEY!(0x259abffc, 0x50a7, 0x47ce, 0xaf, 0x8, 0x68, 0xc9, 0xa7, 0xd7, 0x33, 0x66, 3);      // DEVPROP_TYPE_STRING
const DEVPKEY_DeviceClass_Icon = DEFINE_DEVPROPKEY!(0x259abffc, 0x50a7, 0x47ce, 0xaf, 0x8, 0x68, 0xc9, 0xa7, 0xd7, 0x33, 0x66, 4);      // DEVPROP_TYPE_STRING
const DEVPKEY_DeviceClass_ClassInstaller = DEFINE_DEVPROPKEY!(0x259abffc, 0x50a7, 0x47ce, 0xaf, 0x8, 0x68, 0xc9, 0xa7, 0xd7, 0x33, 0x66, 5);      // DEVPROP_TYPE_STRING
const DEVPKEY_DeviceClass_PropPageProvider = DEFINE_DEVPROPKEY!(0x259abffc, 0x50a7, 0x47ce, 0xaf, 0x8, 0x68, 0xc9, 0xa7, 0xd7, 0x33, 0x66, 6);      // DEVPROP_TYPE_STRING
const DEVPKEY_DeviceClass_NoInstallClass = DEFINE_DEVPROPKEY!(0x259abffc, 0x50a7, 0x47ce, 0xaf, 0x8, 0x68, 0xc9, 0xa7, 0xd7, 0x33, 0x66, 7);      // DEVPROP_TYPE_BOOLEAN
const DEVPKEY_DeviceClass_NoDisplayClass = DEFINE_DEVPROPKEY!(0x259abffc, 0x50a7, 0x47ce, 0xaf, 0x8, 0x68, 0xc9, 0xa7, 0xd7, 0x33, 0x66, 8);      // DEVPROP_TYPE_BOOLEAN
const DEVPKEY_DeviceClass_SilentInstall = DEFINE_DEVPROPKEY!(0x259abffc, 0x50a7, 0x47ce, 0xaf, 0x8, 0x68, 0xc9, 0xa7, 0xd7, 0x33, 0x66, 9);      // DEVPROP_TYPE_BOOLEAN
const DEVPKEY_DeviceClass_NoUseClass = DEFINE_DEVPROPKEY!(0x259abffc, 0x50a7, 0x47ce, 0xaf, 0x8, 0x68, 0xc9, 0xa7, 0xd7, 0x33, 0x66, 10);     // DEVPROP_TYPE_BOOLEAN
const DEVPKEY_DeviceClass_DefaultService = DEFINE_DEVPROPKEY!(0x259abffc, 0x50a7, 0x47ce, 0xaf, 0x8, 0x68, 0xc9, 0xa7, 0xd7, 0x33, 0x66, 11);     // DEVPROP_TYPE_STRING
const DEVPKEY_DeviceClass_IconPath = DEFINE_DEVPROPKEY!(0x259abffc, 0x50a7, 0x47ce, 0xaf, 0x8, 0x68, 0xc9, 0xa7, 0xd7, 0x33, 0x66, 12);     // DEVPROP_TYPE_STRING_LIST

const DEVPKEY_DeviceClass_DHPRebalanceOptOut = DEFINE_DEVPROPKEY!(0xd14d3ef3, 0x66cf, 0x4ba2, 0x9d, 0x38, 0x0d, 0xdb, 0x37, 0xab, 0x47, 0x01, 2);    // DEVPROP_TYPE_BOOLEAN

//
// Other Device setup class properties
//
const DEVPKEY_DeviceClass_ClassCoInstallers = DEFINE_DEVPROPKEY!(0x713d1703, 0xa2e2, 0x49f5, 0x92, 0x14, 0x56, 0x47, 0x2e, 0xf3, 0xda, 0x5c, 2);     // DEVPROP_TYPE_STRING_LIST


//
// Device interface properties
//
const DEVPKEY_DeviceInterface_FriendlyName = DEFINE_DEVPROPKEY!(0x026e516e, 0xb814, 0x414b, 0x83, 0xcd, 0x85, 0x6d, 0x6f, 0xef, 0x48, 0x22, 2);     // DEVPROP_TYPE_STRING
const DEVPKEY_DeviceInterface_Enabled = DEFINE_DEVPROPKEY!(0x026e516e, 0xb814, 0x414b, 0x83, 0xcd, 0x85, 0x6d, 0x6f, 0xef, 0x48, 0x22, 3);     // DEVPROP_TYPE_BOOLEAN
const DEVPKEY_DeviceInterface_ClassGuid = DEFINE_DEVPROPKEY!(0x026e516e, 0xb814, 0x414b, 0x83, 0xcd, 0x85, 0x6d, 0x6f, 0xef, 0x48, 0x22, 4);     // DEVPROP_TYPE_GUID


//
// Device interface class properties
//
const DEVPKEY_DeviceInterfaceClass_DefaultInterface = DEFINE_DEVPROPKEY!(0x14c83a99, 0x0b3f, 0x44b7, 0xbe, 0x4c, 0xa1, 0x78, 0xd3, 0x99, 0x05, 0x64, 2); // DEVPROP_TYPE_STRING

//
// DeviceDisplay properties that can be set on a devnode
//
const DEVPKEY_DeviceDisplay_IsShowInDisconnectedState = DEFINE_DEVPROPKEY!(0x78c34fc8, 0x104a, 0x4aca, 0x9e, 0xa4, 0x52, 0x4d, 0x52, 0x99, 0x6e, 0x57, 0x44); // DEVPROP_TYPE_BOOLEAN
const DEVPKEY_DeviceDisplay_IsNotInterestingForDisplay = DEFINE_DEVPROPKEY!(0x78c34fc8, 0x104a, 0x4aca, 0x9e, 0xa4, 0x52, 0x4d, 0x52, 0x99, 0x6e, 0x57, 0x4a); // DEVPROP_TYPE_BOOLEAN
const DEVPKEY_DeviceDisplay_Category = DEFINE_DEVPROPKEY!(0x78c34fc8, 0x104a, 0x4aca, 0x9e, 0xa4, 0x52, 0x4d, 0x52, 0x99, 0x6e, 0x57, 0x5a); // DEVPROP_TYPE_STRING_LIST
const DEVPKEY_DeviceDisplay_UnpairUninstall = DEFINE_DEVPROPKEY!(0x78c34fc8, 0x104a, 0x4aca, 0x9e, 0xa4, 0x52, 0x4d, 0x52, 0x99, 0x6e, 0x57, 0x62); // DEVPROP_TYPE_BOOLEAN
const DEVPKEY_DeviceDisplay_RequiresUninstallElevation = DEFINE_DEVPROPKEY!(0x78c34fc8, 0x104a, 0x4aca, 0x9e, 0xa4, 0x52, 0x4d, 0x52, 0x99, 0x6e, 0x57, 0x63); // DEVPROP_TYPE_BOOLEAN
const DEVPKEY_DeviceDisplay_AlwaysShowDeviceAsConnected = DEFINE_DEVPROPKEY!(0x78c34fc8, 0x104a, 0x4aca, 0x9e, 0xa4, 0x52, 0x4d, 0x52, 0x99, 0x6e, 0x57, 0x65); // DEVPROP_TYPE_BOOLEAN

alias REFPROPERTYKEY = ref const(PROPERTYKEY);
alias REFPROPVARIANT = ref PROPVARIANT;

enum ERole //__MIDL___MIDL_itf_mmdeviceapi_0000_0000_0002
{	
    eConsole	= 0,
    eMultimedia	= ( eConsole + 1 ) ,
    eCommunications	= ( eMultimedia + 1 ) ,
    ERole_enum_count	= ( eCommunications + 1 ) 
}

enum EDataFlow //__MIDL___MIDL_itf_mmdeviceapi_0000_0000_0001
{	
    eRender	= 0,
    eCapture	= ( eRender + 1 ) ,
    eAll	= ( eCapture + 1 ) ,
    EDataFlow_enum_count	= ( eAll + 1 ) 
}

enum DEVICE_STATE_ACTIVE      = 0x00000001;
enum DEVICE_STATE_DISABLED    = 0x00000002;
enum DEVICE_STATE_NOTPRESENT  = 0x00000004;
enum DEVICE_STATE_UNPLUGGED   = 0x00000008;
enum DEVICE_STATEMASK_ALL     = 0x0000000f;

const IID IID_IPropertyStore = makeGuid!"886d8eeb-8cf2-4446-8d02-cdba1dbdcf99";
interface IPropertyStore : IUnknown {
    HRESULT GetCount( 
            /* [out] */ DWORD *cProps);

    HRESULT GetAt( 
            /* [in] */ DWORD iProp,
            /* [out] */ PROPERTYKEY *pkey);

    HRESULT GetValue( 
            /* [in] */ const ref PROPERTYKEY key,
            /* [out] */ ref PROPVARIANT pv);

    HRESULT SetValue( 
            /* [in] */ const ref PROPERTYKEY key,
            /* [in] */ ref PROPVARIANT propvar);

    HRESULT Commit();
}

const IID IID_IMMDeviceCollection = makeGuid!"0BD7A1BE-7A1A-44DB-8397-CC5392387B5E";
interface IMMDeviceCollection : IUnknown {
    HRESULT GetCount( 
            /* [out] */ 
            ref UINT pcDevices);

    HRESULT Item( 
            /* [in] */ 
            UINT nDevice,
            /* [out] */ 
            ref IMMDevice ppDevice);
}

const IID IID_IMMDevice = makeGuid!"D666063F-1587-4E43-81F1-B948E807363F";
interface IMMDevice : IUnknown {
    HRESULT Activate( 
            /* [in] */ 
            const ref IID iid,
            /* [in] */ 
            DWORD dwClsCtx,
            /* [unique][in] */ 
            PROPVARIANT *pActivationParams,
            /* [iid_is][out] */ 
            void **ppInterface);

    HRESULT OpenPropertyStore( 
            /* [in] */ 
            DWORD stgmAccess,
            /* [out] */ 
            ref IPropertyStore ppProperties);

    HRESULT GetId( 
            /* [out] */ 
            ref LPWSTR ppstrId);

    HRESULT GetState( 
            /* [out] */ 
            ref DWORD pdwState);
}


const IID IID_IMMNotificationClient = makeGuid!"7991EEC9-7E89-4D85-8390-6C703CEC60C0";
interface IMMNotificationClient : IUnknown {
    HRESULT OnDeviceStateChanged( 
            /* [annotation][in] */ 
            LPCWSTR pwstrDeviceId,
            /* [annotation][in] */ 
            DWORD dwNewState);

    HRESULT OnDeviceAdded( 
            /* [annotation][in] */ 
            LPCWSTR pwstrDeviceId);

    HRESULT OnDeviceRemoved( 
            /* [annotation][in] */ 
            LPCWSTR pwstrDeviceId);

    HRESULT OnDefaultDeviceChanged( 
            /* [annotation][in] */ 
            EDataFlow flow,
            /* [annotation][in] */ 
            ERole role,
            /* [annotation][in] */ 
            LPCWSTR pwstrDefaultDeviceId);

    HRESULT OnPropertyValueChanged( 
            /* [annotation][in] */ 
            LPCWSTR pwstrDeviceId,
            /* [annotation][in] */ 
            const PROPERTYKEY key);
}

const IID IID_IMMEndpoint = makeGuid!"1BE09788-6894-4089-8586-9A2A6C265AC5";
interface IMMEndpoint : IUnknown {
    HRESULT GetDataFlow( 
        /* [annotation][out] */ 
        ref EDataFlow pDataFlow);
}

alias REFERENCE_TIME = long;

enum AUDCLNT_SHAREMODE
{
    AUDCLNT_SHAREMODE_SHARED,
    AUDCLNT_SHAREMODE_EXCLUSIVE
}

enum AUDCLNT_STREAMFLAGS_CROSSPROCESS             = 0x00010000;
enum AUDCLNT_STREAMFLAGS_LOOPBACK                 = 0x00020000;
enum AUDCLNT_STREAMFLAGS_EVENTCALLBACK            = 0x00040000;
enum AUDCLNT_STREAMFLAGS_NOPERSIST                = 0x00080000;
enum AUDCLNT_STREAMFLAGS_RATEADJUST               = 0x00100000;

const IID IID_IAudioClient = makeGuid!"1CB9AD4C-DBFA-4c32-B178-C2F568A703B2";
interface IAudioClient : IUnknown {
    HRESULT Initialize( 
            /* [annotation][in] */ 
            AUDCLNT_SHAREMODE ShareMode,
            /* [annotation][in] */ 
            DWORD StreamFlags,
            /* [annotation][in] */ 
            REFERENCE_TIME hnsBufferDuration,
            /* [annotation][in] */ 
            REFERENCE_TIME hnsPeriodicity,
            /* [annotation][in] */ 
            const WAVEFORMATEX *pFormat,
            /* [annotation][in] */ 
            LPCGUID AudioSessionGuid);

    HRESULT GetBufferSize( 
            /* [annotation][out] */ 
            ref UINT32 pNumBufferFrames);

    HRESULT GetStreamLatency( 
            /* [annotation][out] */ 
            ref REFERENCE_TIME phnsLatency);

    HRESULT GetCurrentPadding( 
            /* [annotation][out] */ 
            ref UINT32 pNumPaddingFrames);

    HRESULT IsFormatSupported( 
            /* [annotation][in] */ 
            AUDCLNT_SHAREMODE ShareMode,
            /* [annotation][in] */ 
            const WAVEFORMATEX *pFormat,
            /* [unique][annotation][out] */ 
            WAVEFORMATEX **ppClosestMatch);

    HRESULT GetMixFormat( 
            /* [annotation][out] */ 
            ref WAVEFORMATEX *ppDeviceFormat);

    HRESULT GetDevicePeriod( 
            /* [annotation][out] */ 
            ref REFERENCE_TIME phnsDefaultDevicePeriod,
            /* [annotation][out] */ 
            ref REFERENCE_TIME phnsMinimumDevicePeriod);

    HRESULT Start();

    HRESULT Stop();

    HRESULT Reset();

    HRESULT SetEventHandle( /* [in] */ HANDLE eventHandle);

    HRESULT GetService( 
            /* [annotation][in] */ 
            const ref IID riid,
            /* [annotation][iid_is][out] */ 
            void **ppv);
}

enum AUDIO_STREAM_CATEGORY
{
    AudioCategory_Other = 0,
    AudioCategory_ForegroundOnlyMedia = 1,
    AudioCategory_BackgroundCapableMedia = 2,
    AudioCategory_Communications = 3,
    AudioCategory_Alerts = 4,
    AudioCategory_SoundEffects = 5,
    AudioCategory_GameEffects = 6,
    AudioCategory_GameMedia = 7,
    AudioCategory_GameChat = 8,
    AudioCategory_Speech = 9,
    AudioCategory_Movie = 10,
    AudioCategory_Media = 11,
}

enum AUDCLNT_BUFFERFLAGS
{
    AUDCLNT_BUFFERFLAGS_DATA_DISCONTINUITY	= 0x1,
    AUDCLNT_BUFFERFLAGS_SILENT	= 0x2,
    AUDCLNT_BUFFERFLAGS_TIMESTAMP_ERROR	= 0x4
}

struct AudioClientProperties
{
    UINT32 cbSize;
    BOOL bIsOffload;
    AUDIO_STREAM_CATEGORY eCategory;
    AUDCLNT_STREAMOPTIONS Options;
}

enum AUDCLNT_STREAMOPTIONS
{
    AUDCLNT_STREAMOPTIONS_NONE	= 0,
    AUDCLNT_STREAMOPTIONS_RAW	= 0x1,
    AUDCLNT_STREAMOPTIONS_MATCH_FORMAT	= 0x2
}

//AvSetMmThreadCharacteristics
extern HANDLE AvSetMmThreadCharacteristicsA (
                               immutable (char) * TaskName,
                               ref DWORD TaskIndex
                               );
extern BOOL AvRevertMmThreadCharacteristics (
                                 HANDLE AvrtHandle
                                 );


const IID IID_IAudioClient2 = makeGuid!"726778CD-F60A-4eda-82DE-E47610CD78AA";
interface IAudioClient2 : IAudioClient {
    HRESULT IsOffloadCapable( 
            /* [annotation][in] */ 
            AUDIO_STREAM_CATEGORY Category,
            /* [annotation][out] */ 
            ref BOOL pbOffloadCapable);

    HRESULT SetClientProperties( 
            /* [annotation][in] */ 
            const ref AudioClientProperties pProperties);

    HRESULT GetBufferSizeLimits( 
            /* [annotation][in] */ 
            const WAVEFORMATEX *pFormat,
            /* [annotation][in] */ 
            BOOL bEventDriven,
            /* [annotation][out] */ 
            ref REFERENCE_TIME phnsMinBufferDuration,
            /* [annotation][out] */ 
            ref REFERENCE_TIME phnsMaxBufferDuration);
}

const IID IID_IAudioClient3 = makeGuid!"7ED4EE07-8E67-4CD4-8C1A-2B7A5987AD42";
interface IAudioClient3 : IAudioClient2 {
    HRESULT GetSharedModeEnginePeriod( 
            /* [annotation][in] */ 
            const WAVEFORMATEX *pFormat,
            /* [annotation][out] */ 
            ref UINT32 pDefaultPeriodInFrames,
            /* [annotation][out] */ 
            ref UINT32 pFundamentalPeriodInFrames,
            /* [annotation][out] */ 
            ref UINT32 pMinPeriodInFrames,
            /* [annotation][out] */ 
            ref UINT32 pMaxPeriodInFrames);

    HRESULT GetCurrentSharedModeEnginePeriod( 
            /* [unique][annotation][out] */ 
            ref WAVEFORMATEX *ppFormat,
            /* [annotation][out] */ 
            ref UINT32 pCurrentPeriodInFrames);

    HRESULT InitializeSharedAudioStream( 
            /* [annotation][in] */ 
            DWORD StreamFlags,
            /* [annotation][in] */ 
            UINT32 PeriodInFrames,
            /* [annotation][in] */ 
            const WAVEFORMATEX *pFormat,
            /* [annotation][in] */ 
            LPCGUID AudioSessionGuid);
}

const IID IID_IAudioRenderClient = makeGuid!"F294ACFC-3146-4483-A7BF-ADDCA7C260E2";
interface IAudioRenderClient : IUnknown {
    HRESULT GetBuffer( 
            /* [annotation][in] */ 
            UINT32 NumFramesRequested,
            /* [annotation][out] */ //_Outptr_result_buffer_(_Inexpressible_("NumFramesRequested * pFormat->nBlockAlign"))  
            ref BYTE *ppData);

    HRESULT ReleaseBuffer( 
            /* [annotation][in] */ 
            UINT32 NumFramesWritten,
            /* [annotation][in] */ 
            DWORD dwFlags);
}

const IID IID_IMMDeviceEnumerator = makeGuid!"A95664D2-9614-4F35-A746-DE8DB63617E6";
const CLSID CLSID_MMDeviceEnumerator = makeGuid!"BCDE0395-E52F-467C-8E3D-C4579291692E";
interface IMMDeviceEnumerator : IUnknown {
    HRESULT EnumAudioEndpoints( 
            /* [in] */ 
            EDataFlow dataFlow,
            /* [in] */ 
            DWORD dwStateMask,
            /* [out] */ 
            ref IMMDeviceCollection ppDevices);
    
    HRESULT GetDefaultAudioEndpoint( 
            /* [in] */ 
            EDataFlow dataFlow,
            /* [in] */ 
            ERole role,
            /* [out] */ 
            ref IMMDevice ppEndpoint);
    
    HRESULT GetDevice( 
            /*  */ 
            LPCWSTR pwstrId,
            /* [out] */ 
            IMMDevice *ppDevice);
    
    HRESULT RegisterEndpointNotificationCallback( 
            /* [in] */ 
            IMMNotificationClient pClient);
    
    HRESULT UnregisterEndpointNotificationCallback( 
            /* [in] */ 
            IMMNotificationClient pClient);
}

extern HRESULT PropVariantClear(PROPVARIANT* pvar);

extern HRESULT FreePropVariantArray(
                                    ULONG cVariants,
                                    PROPVARIANT* rgvars);


enum WAVE_FORMAT_UNKNOWN                    =0x0000; /* Microsoft Corporation */
enum WAVE_FORMAT_ADPCM                      =0x0002; /* Microsoft Corporation */
enum WAVE_FORMAT_IEEE_FLOAT                 =0x0003; /* Microsoft Corporation */
enum WAVE_FORMAT_VSELP                      =0x0004; /* Compaq Computer Corp. */
enum WAVE_FORMAT_IBM_CVSD                   =0x0005; /* IBM Corporation */
enum WAVE_FORMAT_ALAW                       =0x0006; /* Microsoft Corporation */
enum WAVE_FORMAT_MULAW                      =0x0007; /* Microsoft Corporation */
enum WAVE_FORMAT_DTS                        =0x0008; /* Microsoft Corporation */
enum WAVE_FORMAT_DRM                        =0x0009; /* Microsoft Corporation */
enum WAVE_FORMAT_WMAVOICE9                  =0x000A; /* Microsoft Corporation */
enum WAVE_FORMAT_WMAVOICE10                 =0x000B; /* Microsoft Corporation */
enum WAVE_FORMAT_OKI_ADPCM                  =0x0010; /* OKI */
enum WAVE_FORMAT_DVI_ADPCM                  =0x0011; /* Intel Corporation */
enum WAVE_FORMAT_IMA_ADPCM                  =(WAVE_FORMAT_DVI_ADPCM); /*  Intel Corporation */
enum WAVE_FORMAT_MEDIASPACE_ADPCM           =0x0012; /* Videologic */
enum WAVE_FORMAT_SIERRA_ADPCM               =0x0013; /* Sierra Semiconductor Corp */
enum WAVE_FORMAT_G723_ADPCM                 =0x0014; /* Antex Electronics Corporation */
enum WAVE_FORMAT_DIGISTD                    =0x0015; /* DSP Solutions, Inc. */
enum WAVE_FORMAT_DIGIFIX                    =0x0016; /* DSP Solutions, Inc. */
enum WAVE_FORMAT_DIALOGIC_OKI_ADPCM         =0x0017; /* Dialogic Corporation */
enum WAVE_FORMAT_MEDIAVISION_ADPCM          =0x0018; /* Media Vision, Inc. */
enum WAVE_FORMAT_CU_CODEC                   =0x0019; /* Hewlett-Packard Company */
enum WAVE_FORMAT_YAMAHA_ADPCM               =0x0020; /* Yamaha Corporation of America */
enum WAVE_FORMAT_SONARC                     =0x0021; /* Speech Compression */
enum WAVE_FORMAT_DSPGROUP_TRUESPEECH        =0x0022; /* DSP Group, Inc */
enum WAVE_FORMAT_ECHOSC1                    =0x0023; /* Echo Speech Corporation */
enum WAVE_FORMAT_AUDIOFILE_AF36             =0x0024; /* Virtual Music, Inc. */
enum WAVE_FORMAT_APTX                       =0x0025; /* Audio Processing Technology */
enum WAVE_FORMAT_AUDIOFILE_AF10             =0x0026; /* Virtual Music, Inc. */
enum WAVE_FORMAT_PROSODY_1612               =0x0027; /* Aculab plc */
enum WAVE_FORMAT_LRC                        =0x0028; /* Merging Technologies S.A. */
enum WAVE_FORMAT_DOLBY_AC2                  =0x0030; /* Dolby Laboratories */
enum WAVE_FORMAT_GSM610                     =0x0031; /* Microsoft Corporation */
enum WAVE_FORMAT_MSNAUDIO                   =0x0032; /* Microsoft Corporation */
enum WAVE_FORMAT_ANTEX_ADPCME               =0x0033; /* Antex Electronics Corporation */
enum WAVE_FORMAT_CONTROL_RES_VQLPC          =0x0034; /* Control Resources Limited */
enum WAVE_FORMAT_DIGIREAL                   =0x0035; /* DSP Solutions, Inc. */
enum WAVE_FORMAT_DIGIADPCM                  =0x0036; /* DSP Solutions, Inc. */
enum WAVE_FORMAT_CONTROL_RES_CR10           =0x0037; /* Control Resources Limited */
enum WAVE_FORMAT_NMS_VBXADPCM               =0x0038; /* Natural MicroSystems */
enum WAVE_FORMAT_CS_IMAADPCM                =0x0039; /* Crystal Semiconductor IMA ADPCM */
enum WAVE_FORMAT_ECHOSC3                    =0x003A; /* Echo Speech Corporation */
enum WAVE_FORMAT_ROCKWELL_ADPCM             =0x003B; /* Rockwell International */
enum WAVE_FORMAT_ROCKWELL_DIGITALK          =0x003C; /* Rockwell International */
enum WAVE_FORMAT_XEBEC                      =0x003D; /* Xebec Multimedia Solutions Limited */
enum WAVE_FORMAT_G721_ADPCM                 =0x0040; /* Antex Electronics Corporation */
enum WAVE_FORMAT_G728_CELP                  =0x0041; /* Antex Electronics Corporation */
enum WAVE_FORMAT_MSG723                     =0x0042; /* Microsoft Corporation */
enum WAVE_FORMAT_MPEG                       =0x0050; /* Microsoft Corporation */
enum WAVE_FORMAT_RT24                       =0x0052; /* InSoft, Inc. */
enum WAVE_FORMAT_PAC                        =0x0053; /* InSoft, Inc. */
enum WAVE_FORMAT_MPEGLAYER3                 =0x0055; /* ISO/MPEG Layer3 Format Tag */
enum WAVE_FORMAT_LUCENT_G723                =0x0059; /* Lucent Technologies */
enum WAVE_FORMAT_CIRRUS                     =0x0060; /* Cirrus Logic */
enum WAVE_FORMAT_ESPCM                      =0x0061; /* ESS Technology */
enum WAVE_FORMAT_VOXWARE                    =0x0062; /* Voxware Inc */
enum WAVE_FORMAT_CANOPUS_ATRAC              =0x0063; /* Canopus, co., Ltd. */
enum WAVE_FORMAT_G726_ADPCM                 =0x0064; /* APICOM */
enum WAVE_FORMAT_G722_ADPCM                 =0x0065; /* APICOM */
enum WAVE_FORMAT_DSAT_DISPLAY               =0x0067; /* Microsoft Corporation */
enum WAVE_FORMAT_VOXWARE_BYTE_ALIGNED       =0x0069; /* Voxware Inc */
enum WAVE_FORMAT_VOXWARE_AC8                =0x0070; /* Voxware Inc */
enum WAVE_FORMAT_VOXWARE_AC10               =0x0071; /* Voxware Inc */
enum WAVE_FORMAT_VOXWARE_AC16               =0x0072; /* Voxware Inc */
enum WAVE_FORMAT_VOXWARE_AC20               =0x0073; /* Voxware Inc */
enum WAVE_FORMAT_VOXWARE_RT24               =0x0074; /* Voxware Inc */
enum WAVE_FORMAT_VOXWARE_RT29               =0x0075; /* Voxware Inc */
enum WAVE_FORMAT_VOXWARE_RT29HW             =0x0076; /* Voxware Inc */
enum WAVE_FORMAT_VOXWARE_VR12               =0x0077; /* Voxware Inc */
enum WAVE_FORMAT_VOXWARE_VR18               =0x0078; /* Voxware Inc */
enum WAVE_FORMAT_VOXWARE_TQ40               =0x0079; /* Voxware Inc */
enum WAVE_FORMAT_SOFTSOUND                  =0x0080; /* Softsound, Ltd. */
enum WAVE_FORMAT_VOXWARE_TQ60               =0x0081; /* Voxware Inc */
enum WAVE_FORMAT_MSRT24                     =0x0082; /* Microsoft Corporation */
enum WAVE_FORMAT_G729A                      =0x0083; /* AT&T Labs, Inc. */
enum WAVE_FORMAT_MVI_MVI2                   =0x0084; /* Motion Pixels */
enum WAVE_FORMAT_DF_G726                    =0x0085; /* DataFusion Systems (Pty) (Ltd) */
enum WAVE_FORMAT_DF_GSM610                  =0x0086; /* DataFusion Systems (Pty) (Ltd) */
enum WAVE_FORMAT_ISIAUDIO                   =0x0088; /* Iterated Systems, Inc. */
enum WAVE_FORMAT_ONLIVE                     =0x0089; /* OnLive! Technologies, Inc. */
enum WAVE_FORMAT_SBC24                      =0x0091; /* Siemens Business Communications Sys */
enum WAVE_FORMAT_DOLBY_AC3_SPDIF            =0x0092; /* Sonic Foundry */
enum WAVE_FORMAT_MEDIASONIC_G723            =0x0093; /* MediaSonic */
enum WAVE_FORMAT_PROSODY_8KBPS              =0x0094; /* Aculab plc */
enum WAVE_FORMAT_ZYXEL_ADPCM                =0x0097; /* ZyXEL Communications, Inc. */
enum WAVE_FORMAT_PHILIPS_LPCBB              =0x0098; /* Philips Speech Processing */
enum WAVE_FORMAT_PACKED                     =0x0099; /* Studer Professional Audio AG */
enum WAVE_FORMAT_MALDEN_PHONYTALK           =0x00A0; /* Malden Electronics Ltd. */
enum WAVE_FORMAT_RAW_AAC1                   =0x00FF; /* For Raw AAC, with format block AudioSpecificConfig() (as defined by MPEG-4), that follows WAVEFORMATEX */
enum WAVE_FORMAT_RHETOREX_ADPCM             =0x0100; /* Rhetorex Inc. */
enum WAVE_FORMAT_IRAT                       =0x0101; /* BeCubed Software Inc. */
enum WAVE_FORMAT_VIVO_G723                  =0x0111; /* Vivo Software */
enum WAVE_FORMAT_VIVO_SIREN                 =0x0112; /* Vivo Software */
enum WAVE_FORMAT_DIGITAL_G723               =0x0123; /* Digital Equipment Corporation */
enum WAVE_FORMAT_SANYO_LD_ADPCM             =0x0125; /* Sanyo Electric Co., Ltd. */
enum WAVE_FORMAT_SIPROLAB_ACEPLNET          =0x0130; /* Sipro Lab Telecom Inc. */
enum WAVE_FORMAT_SIPROLAB_ACELP4800         =0x0131; /* Sipro Lab Telecom Inc. */
enum WAVE_FORMAT_SIPROLAB_ACELP8V3          =0x0132; /* Sipro Lab Telecom Inc. */
enum WAVE_FORMAT_SIPROLAB_G729              =0x0133; /* Sipro Lab Telecom Inc. */
enum WAVE_FORMAT_SIPROLAB_G729A             =0x0134; /* Sipro Lab Telecom Inc. */
enum WAVE_FORMAT_SIPROLAB_KELVIN            =0x0135; /* Sipro Lab Telecom Inc. */
enum WAVE_FORMAT_G726ADPCM                  =0x0140; /* Dictaphone Corporation */
enum WAVE_FORMAT_QUALCOMM_PUREVOICE         =0x0150; /* Qualcomm, Inc. */
enum WAVE_FORMAT_QUALCOMM_HALFRATE          =0x0151; /* Qualcomm, Inc. */
enum WAVE_FORMAT_TUBGSM                     =0x0155; /* Ring Zero Systems, Inc. */
enum WAVE_FORMAT_MSAUDIO1                   =0x0160; /* Microsoft Corporation */
enum WAVE_FORMAT_WMAUDIO2                   =0x0161; /* Microsoft Corporation */
enum WAVE_FORMAT_WMAUDIO3                   =0x0162; /* Microsoft Corporation */
enum WAVE_FORMAT_WMAUDIO_LOSSLESS           =0x0163; /* Microsoft Corporation */
enum WAVE_FORMAT_WMASPDIF                   =0x0164; /* Microsoft Corporation */
enum WAVE_FORMAT_UNISYS_NAP_ADPCM           =0x0170; /* Unisys Corp. */
enum WAVE_FORMAT_UNISYS_NAP_ULAW            =0x0171; /* Unisys Corp. */
enum WAVE_FORMAT_UNISYS_NAP_ALAW            =0x0172; /* Unisys Corp. */
enum WAVE_FORMAT_UNISYS_NAP_16K             =0x0173; /* Unisys Corp. */
enum WAVE_FORMAT_CREATIVE_ADPCM             =0x0200; /* Creative Labs, Inc */
enum WAVE_FORMAT_CREATIVE_FASTSPEECH8       =0x0202; /* Creative Labs, Inc */
enum WAVE_FORMAT_CREATIVE_FASTSPEECH10      =0x0203; /* Creative Labs, Inc */
enum WAVE_FORMAT_UHER_ADPCM                 =0x0210; /* UHER informatic GmbH */
enum WAVE_FORMAT_QUARTERDECK                =0x0220; /* Quarterdeck Corporation */
enum WAVE_FORMAT_ILINK_VC                   =0x0230; /* I-link Worldwide */
enum WAVE_FORMAT_RAW_SPORT                  =0x0240; /* Aureal Semiconductor */
enum WAVE_FORMAT_ESST_AC3                   =0x0241; /* ESS Technology, Inc. */
enum WAVE_FORMAT_GENERIC_PASSTHRU           =0x0249;
enum WAVE_FORMAT_IPI_HSX                    =0x0250; /* Interactive Products, Inc. */
enum WAVE_FORMAT_IPI_RPELP                  =0x0251; /* Interactive Products, Inc. */
enum WAVE_FORMAT_CS2                        =0x0260; /* Consistent Software */
enum WAVE_FORMAT_SONY_SCX                   =0x0270; /* Sony Corp. */
enum WAVE_FORMAT_FM_TOWNS_SND               =0x0300; /* Fujitsu Corp. */
enum WAVE_FORMAT_BTV_DIGITAL                =0x0400; /* Brooktree Corporation */
enum WAVE_FORMAT_QDESIGN_MUSIC              =0x0450; /* QDesign Corporation */
enum WAVE_FORMAT_VME_VMPCM                  =0x0680; /* AT&T Labs, Inc. */
enum WAVE_FORMAT_TPC                        =0x0681; /* AT&T Labs, Inc. */
enum WAVE_FORMAT_OLIGSM                     =0x1000; /* Ing C. Olivetti & C., S.p.A. */
enum WAVE_FORMAT_OLIADPCM                   =0x1001; /* Ing C. Olivetti & C., S.p.A. */
enum WAVE_FORMAT_OLICELP                    =0x1002; /* Ing C. Olivetti & C., S.p.A. */
enum WAVE_FORMAT_OLISBC                     =0x1003; /* Ing C. Olivetti & C., S.p.A. */
enum WAVE_FORMAT_OLIOPR                     =0x1004; /* Ing C. Olivetti & C., S.p.A. */
enum WAVE_FORMAT_LH_CODEC                   =0x1100; /* Lernout & Hauspie */
enum WAVE_FORMAT_NORRIS                     =0x1400; /* Norris Communications, Inc. */
enum WAVE_FORMAT_SOUNDSPACE_MUSICOMPRESS    =0x1500; /* AT&T Labs, Inc. */
enum WAVE_FORMAT_MPEG_ADTS_AAC              =0x1600; /* Microsoft Corporation */
enum WAVE_FORMAT_MPEG_RAW_AAC               =0x1601; /* Microsoft Corporation */
enum WAVE_FORMAT_MPEG_LOAS                  =0x1602; /* Microsoft Corporation (MPEG-4 Audio Transport Streams (LOAS/LATM) */
enum WAVE_FORMAT_NOKIA_MPEG_ADTS_AAC        =0x1608; /* Microsoft Corporation */
enum WAVE_FORMAT_NOKIA_MPEG_RAW_AAC         =0x1609; /* Microsoft Corporation */
enum WAVE_FORMAT_VODAFONE_MPEG_ADTS_AAC     =0x160A; /* Microsoft Corporation */
enum WAVE_FORMAT_VODAFONE_MPEG_RAW_AAC      =0x160B; /* Microsoft Corporation */
enum WAVE_FORMAT_MPEG_HEAAC                 =0x1610; /* Microsoft Corporation (MPEG-2 AAC or MPEG-4 HE-AAC v1/v2 streams with any payload (ADTS, ADIF, LOAS/LATM, RAW). Format block includes MP4 AudioSpecificConfig() -- see HEAACWAVEFORMAT below */
enum WAVE_FORMAT_DVM                        =0x2000; /* FAST Multimedia AG */
enum WAVE_FORMAT_DTS2                       =0x2001;
enum WAVE_FORMAT_EXTENSIBLE                 =0xFFFE; /* Microsoft */

struct WAVEFORMATEXTENSIBLE {
    WAVEFORMATEX    Format;
    alias Format this;
    union {
        WORD wValidBitsPerSample;       /* bits of precision  */
        WORD wSamplesPerBlock;          /* valid if wBitsPerSample==0 */
        WORD wReserved;                 /* If neither applies, set to zero. */
    }
    DWORD           dwChannelMask;      /* which channels are */
    /* present in stream  */
    GUID            SubFormat;
}


const GUID MEDIASUBTYPE_IEEE_FLOAT = {0x00000003, 0x0000, 0x0010, [0x80, 0x00, 0x00, 0xaa, 0x00, 0x38, 0x9b, 0x71]};

