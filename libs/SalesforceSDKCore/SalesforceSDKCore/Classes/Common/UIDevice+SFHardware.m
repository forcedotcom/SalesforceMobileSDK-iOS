/*
 Erica Sadun, http://ericasadun.com
 iPhone Developer's Cookbook, 6.x Edition
 BSD License, Use at your own risk
 */

// Thanks to Emanuele Vulcano, Kevin Ballard/Eridius, Ryandjohnson, Matt Brown, etc.
#include <sys/socket.h> // Per msqr
#include <sys/sysctl.h>
#include <net/if.h>
#include <net/if_dl.h>
#import <mach/mach.h>
#import "UIDevice+SFHardware.h"
#import "UIScreen+SFAdditions.h"
#import "SFApplicationHelper.h"

@implementation UIDevice (SFHardware)
/*
 Platforms
 
 iFPGA ->        ??
 
 iPhone1,1 ->    iPhone 1G, M68
 iPhone1,2 ->    iPhone 3G, N82
 
 iPhone2,1 ->    iPhone 3GS, N89/N88?
 
 iPhone3,1 ->    iPhone 4/AT&T, N90
 iPhone3,2 ->    iPhone 4/Other Carrier?, ??
 iPhone3,3 ->    iPhone 4/Verizon, N92
 
 iPhone4,1 ->    iPhone 4S/GSM, N94
 iPhone4,2 ->    iPhone 4S/???, ???
 iPhone4,3 ->    iPhone 4S/???, ???
 
 iPhone5,1 ->    iPhone Next Gen, TBD
 iPhone5,1 ->    iPhone Next Gen, TBD
 iPhone5,1 ->    iPhone Next Gen, TBD
 
 iPod1,1   ->    iPod touch 1G, N45
 iPod2,1   ->    iPod touch 2G, N72
 iPod2,2   ->    Unknown, ??
 iPod3,1   ->    iPod touch 3G, N18
 iPod4,1   ->    iPod touch 4G, N80
 
 // Thanks NSForge
 iPad1,1   ->    iPad 1G, WiFi and 3G, K48
 
 iPad2,1   ->    iPad 2G, WiFi, K93
 iPad2,2   ->    iPad 2G, GSM 3G, K94
 iPad2,3   ->    iPad 2G, CDMA 3G, K95
 iPad2,4   ->    iPad 2G, (Smaller chip set) K93a
 
 iPad2,5   ->    iPad mini, WiFi
 iPad2,6   ->    iPad mini, GSM
 iPad2,7   ->    iPad mini, CDMA
 
 iPad3,1   ->    iPad 3G, WiFi J1
 iPad3,2   ->    iPad 3G, CDMA J2A, ?J2
 iPad3,3   ->    iPad 3G, GSM J33
 
 iPad3,4   ->    (iPad 4G, WiFi)
 iPad3,5   ->    (iPad 4G, GSM)
 iPad3,6   ->    (iPad 4G, CDMA)
 
 iPad4,1   ->    (iPad Air 1G, WiFi)
 iPad4,2   ->    (iPad Air 1G, GSM)
 iPad4,3   ->    (iPad Air 1G, CDMA)
 iPad4,4   ->    (iPad Mini 2G, Wifi)
 iPad4,5   ->    (iPad Mini 2G, Cellular)
 iPad4,6   ->    (iPad Mini 2G, Cellular)
 iPad4,7   ->    (iPad Mini 3G, Wifi)
 iPad4,8   ->    (iPad Mini 3G, Cellular)
 iPad4,9   ->    (iPad Mini 3G, Cellular)
 
 iPad5,3   ->    (iPad Air 2G, Wifi)
 iPad5,4   ->    (iPad Air 2G, Cellular)
 
 
 AppleTV2,1 ->   AppleTV 2, K66
 AppleTV3,1 ->   AppleTV 3, ??
 
 i386, x86_64 -> iPhone Simulator
 
 // Thank Dustin Howett
 */

#pragma mark sysctlbyname utils
- (NSString *)getSysInfoByName:(char *)typeSpecifier
{
    size_t size;
    sysctlbyname(typeSpecifier, NULL, &size, NULL, 0);
    
    char *answer = malloc(size);
    sysctlbyname(typeSpecifier, answer, &size, NULL, 0);
    
    NSString *results = [NSString stringWithCString:answer encoding: NSUTF8StringEncoding];

    free(answer);
    return results;
}

- (NSString *)sfsdk_platform {
    static NSString *result = nil;
    if (!result) {
        result = [self getSysInfoByName:"hw.machine"];
    }
    return result;
}

- (double)sfsdk_systemVersionNumber {
    static double version = 0;
    if (version == 0) {
        version = [[self systemVersion] doubleValue];
    }

    return version;
}

#pragma mark sysctl utils
- (NSUInteger)getSysInfo: (uint) typeSpecifier {
    size_t size = sizeof(int);
    int results;
    int mib[2] = {CTL_HW, typeSpecifier};
    sysctl(mib, 2, &results, &size, NULL, 0);
    return (NSUInteger) results;
}

- (NSUInteger)sfsdk_totalMemory {
    return [self getSysInfo:HW_PHYSMEM];
}

- (NSUInteger)sfsdk_userMemory {
    return [self getSysInfo:HW_USERMEM];
}

- (NSUInteger)sfsdk_applicationMemory {
    struct mach_task_basic_info info;
    mach_msg_type_number_t size = MACH_TASK_BASIC_INFO_COUNT;
    kern_return_t kerr = task_info(mach_task_self(),
                                   MACH_TASK_BASIC_INFO,
                                   (task_info_t)&info,
                                   &size);
    
    return (kerr == KERN_SUCCESS) ? info.resident_size : 0;
}

/**Free VM page space available to application*/
- (NSUInteger)sfsdk_freeMemory {
    mach_port_t host_port = mach_host_self();
    mach_msg_type_number_t host_size = sizeof(vm_statistics_data_t) / sizeof(integer_t);
    vm_size_t pagesize;
    vm_statistics_data_t vm_stat;
    
    host_page_size(host_port, &pagesize);
    
    if (host_statistics(host_port,
                        HOST_VM_INFO,
                        (host_info_t)&vm_stat,
                        &host_size) != KERN_SUCCESS) {
        return 0.0;
    }
    
    return vm_stat.free_count * (uint) pagesize;
}

- (NSUInteger)maxSocketBufferSize {
    return [self getSysInfo:KIPC_MAXSOCKBUF];
}

#pragma mark file system -- Thanks Joachim Bean!

- (NSNumber *)sfsdk_totalDiskSpace {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSDictionary *fattributes = [fileManager attributesOfFileSystemForPath:NSHomeDirectory() error:nil];
    return [fattributes objectForKey:NSFileSystemSize];
}

- (NSNumber *)sfsdk_freeDiskSpace {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSDictionary *fattributes = [fileManager attributesOfFileSystemForPath:NSHomeDirectory() error:nil];
    return [fattributes objectForKey:NSFileSystemFreeSize];
}

#pragma mark platform type and name utils

- (UIDevicePlatform)sfsdk_platformType {
    NSString *platform = [self sfsdk_platform];
    
    // The ever mysterious iFPGA
    if ([platform isEqualToString:@"iFPGA"])            return UIDeviceIFPGA;
    
    // iPhone
    if ([platform isEqualToString:@"iPhone1,1"])        return UIDevice1GiPhone;
    if ([platform isEqualToString:@"iPhone1,2"])        return UIDevice3GiPhone;
    if ([platform hasPrefix:@"iPhone2"])                return UIDevice3GSiPhone;
    if ([platform hasPrefix:@"iPhone3"])                return UIDevice4iPhone;
    if ([platform hasPrefix:@"iPhone4"])                return UIDevice4SiPhone;
    if ([platform isEqualToString:@"iPhone5,1"] ||
        [platform isEqualToString:@"iPhone5,2"])        return UIDevice5iPhone;
    if ([platform isEqualToString:@"iPhone5,3"] ||
        [platform isEqualToString:@"iPhone5,4"])        return UIDevice5CiPhone;
    if ([platform hasPrefix:@"iPhone6"] ||
        [platform hasPrefix:@"iPhone6,1"] ||
        [platform hasPrefix:@"iPhone6,2"])              return UIDevice5SiPhone;
    if ([platform isEqualToString:@"iPhone7,1"])        return UIDevice6PlusiPhone;
    if ([platform isEqualToString:@"iPhone7,2"])        return UIDevice6iPhone;
    if ([platform isEqualToString:@"iPhone8,1"])        return UIDevice6siPhone;
    if ([platform isEqualToString:@"iPhone8,2"])        return UIDevice6sPlusiPhone;
    if ([platform isEqualToString:@"iPhone8,4"])        return UIDeviceSEiPhone;
    if ([platform isEqualToString:@"iPhone9,1"] ||
        [platform hasPrefix:@"iPhone9,3"])              return UIDevice7iPhone;
    if ([platform isEqualToString:@"iPhone9,2"] ||
        [platform isEqualToString:@"iPhone9,4"])        return UIDevice7PlusiPhone;
    if ([platform isEqualToString:@"iPhone10,1"] ||
        [platform isEqualToString:@"iPhone10,4"])       return UIDevice8iPhone;
    if ([platform isEqualToString:@"iPhone10,2"] ||
        [platform isEqualToString:@"iPhone10,5"])       return UIDevice8PlusiPhone;
    if ([platform isEqualToString:@"iPhone10,3"] ||
        [platform isEqualToString:@"iPhone10,6"])       return UIDevice8iPhone;
    // iPod
    if ([platform hasPrefix:@"iPod1"])                  return UIDevice1GiPod;
    if ([platform hasPrefix:@"iPod2"])                  return UIDevice2GiPod;
    if ([platform hasPrefix:@"iPod3"])                  return UIDevice3GiPod;
    if ([platform hasPrefix:@"iPod4"])                  return UIDevice4GiPod;
    if ([platform hasPrefix:@"iPod5,1"])                return UIDevice5GiPod;
    if ([platform hasPrefix:@"iPod7,1"])                return UIDevice6GiPod;
    
    
    // iPad
    if ([platform isEqualToString:@"iPad1,1"])          return UIDevice1GiPad;
    if ([platform isEqualToString:@"iPad2,1"])          return UIDevice2GiPad;
    if ([platform isEqualToString:@"iPad2,2"])          return UIDevice2GiPad;
    if ([platform isEqualToString:@"iPad2,3"])          return UIDevice2GiPad;
    if ([platform isEqualToString:@"iPad2,4"])          return UIDevice2GiPad;
    if ([platform isEqualToString:@"iPad2,5"])          return UIDevice1GiPadMini;
    if ([platform isEqualToString:@"iPad2,6"])          return UIDevice1GiPadMini;
    if ([platform isEqualToString:@"iPad2,7"])          return UIDevice1GiPadMini;
    if ([platform isEqualToString:@"iPad3,1"])          return UIDevice3GiPad;
    if ([platform isEqualToString:@"iPad3,2"])          return UIDevice3GiPad;
    if ([platform isEqualToString:@"iPad3,3"])          return UIDevice3GiPad;
    if ([platform isEqualToString:@"iPad3,4"])          return UIDevice4GiPad;
    if ([platform isEqualToString:@"iPad3,5"])          return UIDevice4GiPad;
    if ([platform isEqualToString:@"iPad3,6"])          return UIDevice4GiPad;
    if ([platform isEqualToString:@"iPad4,1"] ||
        [platform isEqualToString:@"iPad4,2"] ||
        [platform isEqualToString:@"iPad4,3"])          return UIDevice1GiPadAir;
    if ([platform isEqualToString:@"iPad4,4"] ||
        [platform isEqualToString:@"iPad4,5"] ||
        [platform isEqualToString:@"iPad4,6"])          return UIDevice2GiPadMini;
    if ([platform isEqualToString:@"iPad4,7"] ||
        [platform isEqualToString:@"iPad4,8"] ||
        [platform isEqualToString:@"iPad4,9"])          return UIDevice3GiPadMini;
    if ([platform isEqualToString:@"iPad5,1"] ||
        [platform isEqualToString:@"iPad5,2"])          return UIDevice4GiPadMini;
    if ([platform isEqualToString:@"iPad5,3"] ||
        [platform isEqualToString:@"iPad5,4"])          return UIDevice2GiPadAir;
    if ([platform isEqualToString:@"iPad6,3"] ||
        [platform isEqualToString:@"iPad6,4"])          return UIDevice97InchiPadPro;
    if ([platform isEqualToString:@"iPad6,7"] ||
        [platform isEqualToString:@"iPad6,8"])          return UIDevice129InchiPadPro;
    if ([platform isEqualToString:@"iPad6,11"] ||
        [platform isEqualToString:@"iPad6,12"])          return UIDevice5GiPad;
    if ([platform isEqualToString:@"iPad7,1"] ||
        [platform isEqualToString:@"iPad7,2"])          return UIDevice2G129InchiPadPro;
    if ([platform isEqualToString:@"iPad7,3"] ||
        [platform isEqualToString:@"iPad7,4"])          return UIDevice105InchIpadPro;
    if ([platform isEqualToString:@"iPad7,5"] ||
        [platform isEqualToString:@"iPad7,6"])          return UIDevice6GiPad;
    if ([platform isEqualToString:@"iPad8,1"] ||
        [platform isEqualToString:@"iPad8,2"] ||
        [platform isEqualToString:@"iPad8,3"] ||
        [platform isEqualToString:@"iPad8,4"])          return UIDevice11InchIpadPro;
    if ([platform isEqualToString:@"iPad8,5"] ||
        [platform isEqualToString:@"iPad8,6"] ||
        [platform isEqualToString:@"iPad8,7"] ||
        [platform isEqualToString:@"iPad8,8"])          return UIDevice3G129InchiPadPro;
    
    
    // Apple TV
    if ([platform hasPrefix:@"AppleTV2"])               return UIDeviceAppleTV2;
    if ([platform hasPrefix:@"AppleTV3"])               return UIDeviceAppleTV3;
    if ([platform hasPrefix:@"AppleTV5,3"])             return UIDeviceAppleTV4;
    if ([platform hasPrefix:@"AppleTV6,2"])             return UIDeviceAppleTV4k;
    
    if ([platform hasPrefix:@"iPhone"]) {
        return UIDeviceUnknowniPhone;
    }
    
    if ([platform hasPrefix:@"iPod"])                   return UIDeviceUnknowniPod;
    if ([platform hasPrefix:@"iPad"])                   return UIDeviceUnknowniPad;
    if ([platform hasPrefix:@"AppleTV"])                return UIDeviceUnknownAppleTV;
    
    // Simulator thanks Jordan Breeding
    #if !TARGET_OS_VISION
        if ([platform hasSuffix:@"86"] || [platform isEqual:@"x86_64"]) {
            BOOL smallerScreen = [[UIScreen mainScreen] bounds].size.width < 768;
            return smallerScreen ? UIDeviceSimulatoriPhone : UIDeviceSimulatoriPad;
        }
    #endif

    return UIDeviceUnknown;
}

- (BOOL)sfsdk_hasNeuralEngine {
    if (![UIDevice sfsdk_currentDeviceIsIPad] && ![UIDevice sfsdk_currentDeviceIsIPhone]) {
        return NO;
    }
    
    UIDevicePlatform platform = [self sfsdk_platformType];
    switch (platform) {
        case UIDevice1GiPhone:
        case UIDevice3GiPhone:
        case UIDevice3GSiPhone:
        case UIDevice4iPhone:
        case UIDevice4SiPhone:
        case UIDevice5iPhone:
        case UIDevice5CiPhone:
        case UIDevice5SiPhone:
        case UIDevice6PlusiPhone:
        case UIDevice6iPhone:
        case UIDevice6siPhone:
        case UIDevice6sPlusiPhone:
        case UIDeviceSEiPhone:
        case UIDevice7iPhone:
        case UIDevice7PlusiPhone:
        case UIDevice1GiPad:
        case UIDevice2GiPad:
        case UIDevice3GiPad:
        case UIDevice4GiPad:
        case UIDevice5GiPad:
        case UIDevice6GiPad:
        case UIDevice1GiPadAir:
        case UIDevice2GiPadAir:
        case UIDevice1GiPadMini:
        case UIDevice2GiPadMini:
        case UIDevice3GiPadMini:
        case UIDevice4GiPadMini:
        case UIDevice97InchiPadPro:
        case UIDevice129InchiPadPro:
        case UIDevice2G129InchiPadPro:
        case UIDevice105InchIpadPro:
        case UIDeviceUnknown:
        case UIDeviceIFPGA:
            return NO;
            
        default:
            return YES;
    }
}

- (NSString *)sfsdk_platformString {
    switch ([self sfsdk_platformType])
    {
        case UIDevice1GiPhone: return IPHONE_1G_NAMESTRING;
        case UIDevice3GiPhone: return IPHONE_3G_NAMESTRING;
        case UIDevice3GSiPhone: return IPHONE_3GS_NAMESTRING;
        case UIDevice4iPhone: return IPHONE_4_NAMESTRING;
        case UIDevice4SiPhone: return IPHONE_4S_NAMESTRING;
        case UIDevice5iPhone: return IPHONE_5_NAMESTRING;
        case UIDevice5CiPhone: return IPHONE_5C_NAMESTRING;
        case UIDevice5SiPhone: return IPHONE_5S_NAMESTRING;
        case UIDevice6iPhone: return IPHONE_6_NAMESTRING;
        case UIDevice6PlusiPhone: return IPHONE_6P_NAMESTRING;
        case UIDevice6siPhone: return IPHONE_6s_NAMESTRING;
        case UIDevice6sPlusiPhone: return IPHONE_6sP_NAMESTRING;
        case UIDeviceSEiPhone: return IPHONE_SE_NAMESTRING;
        case UIDevice7iPhone: return IPHONE_7_NAMESTRING;
        case UIDevice7PlusiPhone: return IPHONE_7P_NAMESTRING;
        case UIDevice8iPhone: return IPHONE_8_NAMESTRING;
        case UIDevice8PlusiPhone: return IPHONE_8P_NAMESTRING;
        case UIDeviceXiPhone: return IPHONE_X_NAMESTRING;
        case UIDeviceXsiPhone: return IPHONE_XS_NAMESTRING;
        case UIDeviceXsMaxiPhone: return IPHONE_XSMAX_NAMESTRING;
        case UIDeviceXRiPhone: return IPHONE_XR_NAMESTRING;
            
        case UIDeviceUnknowniPhone: return IPHONE_UNKNOWN_NAMESTRING;
            
        case UIDevice1GiPod: return IPOD_1G_NAMESTRING;
        case UIDevice2GiPod: return IPOD_2G_NAMESTRING;
        case UIDevice3GiPod: return IPOD_3G_NAMESTRING;
        case UIDevice4GiPod: return IPOD_4G_NAMESTRING;
        case UIDevice5GiPod: return IPOD_5G_NAMESTRING;
        case UIDevice6GiPod: return IPOD_6G_NAMESTRING;
        case UIDeviceUnknowniPod: return IPOD_UNKNOWN_NAMESTRING;
            
        case UIDevice1GiPad: return IPAD_1G_NAMESTRING;
        case UIDevice2GiPad: return IPAD_2G_NAMESTRING;
        case UIDevice3GiPad: return IPAD_3G_NAMESTRING;
        case UIDevice4GiPad: return IPAD_4G_NAMESTRING;
        case UIDevice5GiPad: return IPAD_5G_NAMESTRING;
        case UIDevice6GiPad: return IPAD_6G_NAMESTRING;
        case UIDevice1GiPadAir: return IPAD_AIR_1G_NAMESTRING;
        case UIDevice2GiPadAir: return IPAD_AIR_2G_NAMESTRING;
        case UIDevice1GiPadMini: return  IPAD_MINI_1G_NAMESTRING;
        case UIDevice2GiPadMini: return  IPAD_MINI_2G_NAMESTRING;
        case UIDevice3GiPadMini: return  IPAD_MINI_3G_NAMESTRING;
        case UIDevice4GiPadMini: return IPAD_MINI_4G_NAMESTRING;
        case UIDevice97InchiPadPro: return  IPAD_PRO_9_7_INCH_NAMESTRING;
        case UIDevice129InchiPadPro: return  IPAD_PRO_12_9_INCH_NAMESTRING;
        case UIDevice2G129InchiPadPro: return IPAD_PRO_12_9_2G_INCH_NAMESTRING;
        case UIDevice3G129InchiPadPro: return IPAD_PRO_12_9_3G_INCH_NAMESTRING;
        case UIDevice105InchIpadPro: return IPAD_PRO_10_5_INCH_NAMESTRING;
        case UIDevice11InchIpadPro: return IPAD_PRO_11_INCH_NAMESTRING;
            
        case UIDeviceUnknowniPad : return IPAD_UNKNOWN_NAMESTRING;
            
        case UIDeviceAppleTV2: return APPLETV_2G_NAMESTRING;
        case UIDeviceAppleTV3: return APPLETV_3G_NAMESTRING;
        case UIDeviceAppleTV4: return APPLETV_4G_NAMESTRING;
        case UIDeviceAppleTV4k: return APPLETV_4K_NAMESTRING;
        case UIDeviceUnknownAppleTV: return APPLETV_UNKNOWN_NAMESTRING;
            
        case UIDeviceSimulator: return SIMULATOR_NAMESTRING;
        case UIDeviceSimulatoriPhone: return SIMULATOR_IPHONE_NAMESTRING;
        case UIDeviceSimulatoriPad: return SIMULATOR_IPAD_NAMESTRING;
        case UIDeviceSimulatorAppleTV: return SIMULATOR_APPLETV_NAMESTRING;
            
        case UIDeviceIFPGA: return IFPGA_NAMESTRING;
            
        default: return IOS_FAMILY_UNKNOWN_DEVICE;
    }
}

- (UIDeviceFamily)sfsdk_deviceFamily {
    NSString *platform = [self sfsdk_platform];
    if ([platform hasPrefix:@"iPhone"]) return UIDeviceFamilyiPhone;
    if ([platform hasPrefix:@"iPod"]) return UIDeviceFamilyiPod;
    if ([platform hasPrefix:@"iPad"]) return UIDeviceFamilyiPad;
    if ([platform hasPrefix:@"AppleTV"]) return UIDeviceFamilyAppleTV;
    
    return UIDeviceFamilyUnknown;
}

- (UIInterfaceOrientation)sfsdk_interfaceOrientation {
    UIDeviceOrientation deviceOrientation = UIDevice.currentDevice.orientation;
    UIInterfaceOrientation orientation = (UIInterfaceOrientation)deviceOrientation;
    if (!UIDeviceOrientationIsValidInterfaceOrientation(deviceOrientation)) {
        orientation = [SFApplicationHelper sharedApplication].windows.firstObject.windowScene.interfaceOrientation;
    }
    return orientation;
}

+ (BOOL)sfsdk_currentDeviceIsIPad {
    return (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad);
}

+ (BOOL)sfsdk_currentDeviceIsIPhone {
    return (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPhone);
}

- (BOOL)sfsdk_isSimulator {
    #if TARGET_OS_SIMULATOR
    return YES;
    #else
    return NO;
    #endif
}

@end
