module soundtab.audio.coreaudio;

import core.sys.windows.windows;
import core.sys.windows.objidl;
import core.sys.windows.wtypes;
//import core.sys.windows.propsys;
import dlangui.core.logger;
import std.string;

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
            UINT *pcDevices);

    HRESULT Item( 
            /* [in] */ 
            UINT nDevice,
            /* [out] */ 
            IMMDevice * ppDevice);
}

const IID IID_IMMDevice = makeGuid!"D666063F-1587-4E43-81F1-B948E807363F";
interface IMMDevice : IUnknown {
    HRESULT Activate( 
            /* [in] */ 
            REFIID iid,
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
            IPropertyStore *ppProperties);

    HRESULT GetId( 
            /* [out] */ 
            LPWSTR *ppstrId);

    HRESULT GetState( 
            /* [out] */ 
            DWORD *pdwState);
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

const IID IID_IMMDeviceEnumerator = makeGuid!"A95664D2-9614-4F35-A746-DE8DB63617E6";
const CLSID CLSID_MMDeviceEnumerator = makeGuid!"BCDE0395-E52F-467C-8E3D-C4579291692E";
interface IMMDeviceEnumerator : IUnknown {
    HRESULT EnumAudioEndpoints( 
            /* [in] */ 
            EDataFlow dataFlow,
            /* [in] */ 
            DWORD dwStateMask,
            /* [out] */ 
            IMMDeviceCollection *ppDevices);
    
    HRESULT GetDefaultAudioEndpoint( 
            /* [in] */ 
            EDataFlow dataFlow,
            /* [in] */ 
            ERole role,
            /* [out] */ 
            IMMDevice *ppEndpoint);
    
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

