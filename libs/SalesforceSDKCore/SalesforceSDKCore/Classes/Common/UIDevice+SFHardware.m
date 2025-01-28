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

 iFPGA ->        Unknown or Internal Development Platform
 
 // iPhone Models
 iPhone1,1  ->   iPhone 1G (Original iPhone), M68
 iPhone1,2  ->   iPhone 3G, N82

 iPhone2,1  ->   iPhone 3GS, N89/N88

 iPhone3,1  ->   iPhone 4 (AT&T), N90
 iPhone3,2  ->   iPhone 4 (Other Carriers), ??
 iPhone3,3  ->   iPhone 4 (Verizon), N92

 iPhone4,1  ->   iPhone 4S (GSM), N94

 iPhone5,1  ->   iPhone 5 (GSM/LTE, 16-21nm), N41/N42
 iPhone5,2  ->   iPhone 5 (GSM+CDMA, LTE), N42
 iPhone5,3  ->   iPhone 5C (GSM), N48
 iPhone5,4  ->   iPhone 5C (Global), N48

 iPhone6,1  ->   iPhone 5S (GSM), N51
 iPhone6,2  ->   iPhone 5S (Global), N53

 iPhone7,1  ->   iPhone 6 Plus, N56
 iPhone7,2  ->   iPhone 6, N61

 iPhone8,1  ->   iPhone 6S, N71
 iPhone8,2  ->   iPhone 6S Plus, N66
 iPhone8,4  ->   iPhone SE (1st Generation), N69

 iPhone9,1  ->   iPhone 7 (GSM), D10
 iPhone9,3  ->   iPhone 7 (Global), D101
 iPhone9,2  ->   iPhone 7 Plus (GSM), D11
 iPhone9,4  ->   iPhone 7 Plus (Global), D111

 iPhone10,1 ->   iPhone 8 (GSM), D20
 iPhone10,4 ->   iPhone 8 (Global), D201
 iPhone10,2 ->   iPhone 8 Plus (GSM), D21
 iPhone10,5 ->   iPhone 8 Plus (Global), D211
 iPhone10,3 ->   iPhone X (Global), D22
 iPhone10,6 ->   iPhone X (GSM), D221

 iPhone11,2 ->   iPhone XS, D321
 iPhone11,4 ->   iPhone XS Max (China), D331
 iPhone11,6 ->   iPhone XS Max (Global), D332
 iPhone11,8 ->   iPhone XR, D321AP

 iPhone12,1 ->   iPhone 11, N104
 iPhone12,3 ->   iPhone 11 Pro, N104AP
 iPhone12,5 ->   iPhone 11 Pro Max, N104AP2
 iPhone12,8 ->   iPhone SE (2nd Generation), N138

 iPhone13,1 ->   iPhone 12 Mini, D52G
 iPhone13,2 ->   iPhone 12, D53G
 iPhone13,3 ->   iPhone 12 Pro, D53P
 iPhone13,4 ->   iPhone 12 Pro Max, D54P

 iPhone14,4 ->   iPhone 13 Mini, D63G
 iPhone14,5 ->   iPhone 13, D64G
 iPhone14,2 ->   iPhone 13 Pro, D64P
 iPhone14,3 ->   iPhone 13 Pro Max, D65P

 iPhone14,7 ->   iPhone 14, D73G
 iPhone14,8 ->   iPhone 14 Plus, D74G
 iPhone15,2 ->   iPhone 14 Pro, D74P
 iPhone15,3 ->   iPhone 14 Pro Max, D75P

 iPhone15,4 ->   iPhone 15, D83G
 iPhone15,5 ->   iPhone 15 Plus, D84G
 iPhone16,1 ->   iPhone 15 Pro, D84P
 iPhone16,2 ->   iPhone 15 Pro Max, D85P
 
 
 iPhone17,1 ->   iPhone 16 Pro
 iPhone17,2 ->   iPhone 16 Pro Max
 iPhone17,3 ->   iPhone 16
 iPhone17,4 ->   iPhone 16 Plus

 // iPod Models
 iPod1,1   ->    iPod touch 1G, N45
 iPod2,1   ->    iPod touch 2G, N72
 iPod3,1   ->    iPod touch 3G, N18
 iPod4,1   ->    iPod touch 4G, N80
 iPod5,1   ->    iPod touch 5G, N81

 // iPad Models
 iPad1,1   ->    iPad 1G (WiFi and 3G), K48
 iPad2,1   ->    iPad 2 (WiFi), K93
 iPad2,2   ->    iPad 2 (GSM), K94
 iPad2,3   ->    iPad 2 (CDMA), K95
 iPad2,5   ->    iPad mini (1st Generation), P105
 iPad3,1   ->    iPad 3 (WiFi), J1
 iPad3,2   ->    iPad 3 (CDMA), J2A
 iPad3,3   ->    iPad 3 (GSM), J33
 iPad4,1   ->    iPad Air (1st Generation, WiFi), J71
 iPad4,4   ->    iPad mini 2, J85
 iPad5,1   ->    iPad mini 4, J96
 iPad8,1   ->    iPad Pro (11-inch, 1st Gen), D42a
 iPad13,1  ->    iPad Air (4th Gen), J413

 // Apple TVs
 AppleTV2,1 ->   Apple TV 2G, K66
 AppleTV3,1 ->   Apple TV 3G, J33AP
 AppleTV5,3 ->   Apple TV HD, J42d
 AppleTV6,2 ->   Apple TV 4K, J421d

 // Simulator
 i386, x86_64 -> iPhone Simulator
 arm64 ->        iPhone Simulator

 // Notes
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
    
    // Placeholder for unknown platforms or iFPGA (rare and mostly unused)
    if ([platform isEqualToString:@"iFPGA"]) return UIDeviceIFPGA;

    // iPhones (iOS 17 and newer supported)
    if ([platform isEqualToString:@"iPhone12,8"]) return UIDeviceSE2iPhone;           // iPhone SE (2nd generation)
    if ([platform isEqualToString:@"iPhone14,6"]) return UIDeviceSE3iPhone;           // iPhone SE (3rd generation)
    if ([platform isEqualToString:@"iPhone11,8"]) return UIDeviceXRiPhone;            // iPhone XR
    if ([platform isEqualToString:@"iPhone11,2"]) return UIDeviceXsiPhone;            // iPhone XS
    if ([platform isEqualToString:@"iPhone11,4"] || [platform isEqualToString:@"iPhone11,6"]) return UIDeviceXsMaxiPhone; // iPhone XS Max
    if ([platform isEqualToString:@"iPhone12,1"]) return UIDevice11iPhone;           // iPhone 11
    if ([platform isEqualToString:@"iPhone12,3"]) return UIDevice11ProiPhone;        // iPhone 11 Pro
    if ([platform isEqualToString:@"iPhone12,5"]) return UIDevice11ProMaxiPhone;     // iPhone 11 Pro Max
    if ([platform isEqualToString:@"iPhone13,1"]) return UIDevice12MiniiPhone;       // iPhone 12 Mini
    if ([platform isEqualToString:@"iPhone13,2"]) return UIDevice12iPhone;           // iPhone 12
    if ([platform isEqualToString:@"iPhone13,3"]) return UIDevice12ProiPhone;        // iPhone 12 Pro
    if ([platform isEqualToString:@"iPhone13,4"]) return UIDevice12ProMaxiPhone;     // iPhone 12 Pro Max
    if ([platform isEqualToString:@"iPhone14,4"]) return UIDevice13MiniiPhone;       // iPhone 13 Mini
    if ([platform isEqualToString:@"iPhone14,5"]) return UIDevice13iPhone;           // iPhone 13
    if ([platform isEqualToString:@"iPhone14,2"]) return UIDevice13ProiPhone;        // iPhone 13 Pro
    if ([platform isEqualToString:@"iPhone14,3"]) return UIDevice13ProMaxiPhone;     // iPhone 13 Pro Max
    if ([platform isEqualToString:@"iPhone14,7"]) return UIDevice14iPhone;           // iPhone 14
    if ([platform isEqualToString:@"iPhone14,8"]) return UIDevice14PlusiPhone;       // iPhone 14 Plus
    if ([platform isEqualToString:@"iPhone15,2"]) return UIDevice14ProiPhone;        // iPhone 14 Pro
    if ([platform isEqualToString:@"iPhone15,3"]) return UIDevice14ProMaxiPhone;     // iPhone 14 Pro Max
    if ([platform isEqualToString:@"iPhone15,4"]) return UIDevice15iPhone;           // iPhone 15
    if ([platform isEqualToString:@"iPhone15,5"]) return UIDevice15PlusiPhone;       // iPhone 15 Plus
    if ([platform isEqualToString:@"iPhone16,1"]) return UIDevice15ProiPhone;        // iPhone 15 Pro
    if ([platform isEqualToString:@"iPhone16,2"]) return UIDevice15ProMaxiPhone;     // iPhone 15 Pro Max
    if ([platform isEqualToString:@"iPhone17,1"]) return UIDevice16ProiPhone;     // iPhone 16 Pro
    if ([platform isEqualToString:@"iPhone17,2"]) return UIDevice16ProMaxiPhone; // iPhone 16 Pro Max
    if ([platform isEqualToString:@"iPhone17,3"]) return UIDevice16iPhone;       // iPhone 16
    if ([platform isEqualToString:@"iPhone17,4"]) return UIDevice16PlusiPhone;   // iPhone 16 Plus

    // iPads (iOS 17 and newer supported)
    if ([platform isEqualToString:@"iPad7,11"] || [platform isEqualToString:@"iPad7,12"]) return UIDevice7GiPad;    // iPad (7th generation)
    if ([platform isEqualToString:@"iPad8,1"] || [platform isEqualToString:@"iPad8,2"] ||
        [platform isEqualToString:@"iPad8,3"] || [platform isEqualToString:@"iPad8,4"]) return UIDevice11InchiPadPro; // iPad Pro (11-inch, 1st generation)
    if ([platform isEqualToString:@"iPad8,5"] || [platform isEqualToString:@"iPad8,6"] ||
        [platform isEqualToString:@"iPad8,7"] || [platform isEqualToString:@"iPad8,8"]) return UIDevice3G129InchiPadPro; // iPad Pro (12.9-inch, 3rd generation)
    if ([platform isEqualToString:@"iPad8,9"] || [platform isEqualToString:@"iPad8,10"]) return UIDevice11Inch2GiPadPro; // iPad Pro (11-inch, 2nd generation)
    if ([platform isEqualToString:@"iPad8,11"] || [platform isEqualToString:@"iPad8,12"]) return UIDevice4G129InchiPadPro; // 4th generation of the iPad Pro 12.9-inch
    if ([platform isEqualToString:@"iPad11,3"] || [platform isEqualToString:@"iPad11,4"]) return UIDevice3GiPadAir;  // iPad Air (3rd generation)
    if ([platform isEqualToString:@"iPad11,1"] || [platform isEqualToString:@"iPad11,2"]) return UIDevice5GiPadMini; // iPad mini (5th generation)
    if ([platform isEqualToString:@"iPad11,6"] || [platform isEqualToString:@"iPad11,7"]) return UIDevice8GiPad;    // iPad (8th generation)
    if ([platform isEqualToString:@"iPad12,1"] || [platform isEqualToString:@"iPad12,2"]) return UIDevice9GiPad;    // iPad (9th generation)
    if ([platform isEqualToString:@"iPad13,1"] || [platform isEqualToString:@"iPad13,2"]) return UIDevice4GiPadAir;  // iPad Air (4th generation)
    if ([platform isEqualToString:@"iPad13,4"] || [platform isEqualToString:@"iPad13,5"] ||
        [platform isEqualToString:@"iPad13,6"] || [platform isEqualToString:@"iPad13,7"]) return UIDevice11Inch3GiPadPro; // iPad Pro (11-inch, 3rd generation)
    if ([platform isEqualToString:@"iPad13,8"] || [platform isEqualToString:@"iPad13,9"] ||
        [platform isEqualToString:@"iPad13,10"] || [platform isEqualToString:@"iPad13,11"]) return UIDevice5G129InchiPadPro; // iPad Pro (12.9-inch, M1)
    if ([platform isEqualToString:@"iPad13,16"] || [platform isEqualToString:@"iPad13,17"]) return UIDevice5GiPadAir; // iPad Air (5th generation)
    if ([platform isEqualToString:@"iPad13,18"] || [platform isEqualToString:@"iPad13,19"]) return UIDevice10GiPad; // iPad (10th generation)
    if ([platform isEqualToString:@"iPad14,1"] || [platform isEqualToString:@"iPad14,2"]) return UIDevice6GiPadMini; // iPad mini (6th generation)
    if ([platform isEqualToString:@"iPad14,3"] || [platform isEqualToString:@"iPad14,4"]) return UIDevice6G129InchiPadPro; // iPad Pro (12.9-inch, 6th generation)
    if ([platform isEqualToString:@"iPad14,5"] || [platform isEqualToString:@"iPad14,6"]) return UIDevice11Inch4GiPadPro; // iPad Pro (11-inch, 4th generation)
 
    // Apple TVs
    if ([platform isEqualToString:@"AppleTV5,3"]) return UIDeviceAppleTV4; // Apple TV HD
    if ([platform isEqualToString:@"AppleTV6,2"]) return UIDeviceAppleTV4k; // Apple TV 4K (1st generation)
    if ([platform isEqualToString:@"AppleTV11,1"]) return UIDeviceAppleTV4k2G; // Apple TV 4K (2nd generation)
    if ([platform isEqualToString:@"AppleTV14,1"]) return UIDeviceAppleTV4k3G; // Apple TV 4K (3rd generation)

    // Simulators
    #if !TARGET_OS_VISION
    UIDevice *device = [UIDevice currentDevice];
    if (device.userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
        return UIDeviceSimulatoriPhone;
    } else if (device.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        return UIDeviceSimulatoriPad;
    } else {
        return UIDeviceSimulator; // Default case for other types like visionOS
    }
    #endif

    return UIDeviceUnknown;  // Unknown platform fallback
}

- (BOOL)sfsdk_hasNeuralEngine {
    if (![UIDevice sfsdk_currentDeviceIsIPad] && ![UIDevice sfsdk_currentDeviceIsIPhone]) {
        return NO;
    }
    
    UIDevicePlatform platform = [self sfsdk_platformType];
    switch (platform) {
        // Devices without a Neural Engine
        case UIDeviceSE2iPhone:            // iPhone SE (2nd generation)
        case UIDeviceXRiPhone:            // iPhone XR
        case UIDeviceSE3iPhone:           // iPhone SE (3rd generation)
        case UIDeviceXsiPhone:            // iPhone XS
        case UIDeviceXsMaxiPhone:         // iPhone XS Max
        case UIDevice11iPhone:            // iPhone 11
        case UIDevice11ProiPhone:         // iPhone 11 Pro
        case UIDevice11ProMaxiPhone:      // iPhone 11 Pro Max
        case UIDevice5GiPadMini:          // iPad mini (5th generation)
        case UIDevice3GiPadAir:           // iPad Air (3rd generation)
        case UIDevice7GiPad:              // iPad (7th generation)
        case UIDevice8GiPad:              // iPad (8th generation)
        case UIDevice3G129InchiPadPro:    // iPad Pro (12.9-inch, 3rd generation)
        case UIDevice11Inch2GiPadPro:     // iPad Pro (11-inch, 2nd generation)
            return NO;

        // Devices with a Neural Engine
        case UIDevice12MiniiPhone:        // iPhone 12 Mini
        case UIDevice12iPhone:            // iPhone 12
        case UIDevice12ProiPhone:         // iPhone 12 Pro
        case UIDevice12ProMaxiPhone:      // iPhone 12 Pro Max
        case UIDevice13MiniiPhone:        // iPhone 13 Mini
        case UIDevice13iPhone:            // iPhone 13
        case UIDevice13ProiPhone:         // iPhone 13 Pro
        case UIDevice13ProMaxiPhone:      // iPhone 13 Pro Max
        case UIDevice14iPhone:            // iPhone 14
        case UIDevice14PlusiPhone:        // iPhone 14 Plus
        case UIDevice14ProiPhone:         // iPhone 14 Pro
        case UIDevice14ProMaxiPhone:      // iPhone 14 Pro Max
        case UIDevice15iPhone:            // iPhone 15
        case UIDevice15PlusiPhone:        // iPhone 15 Plus
        case UIDevice15ProiPhone:         // iPhone 15 Pro
        case UIDevice15ProMaxiPhone:      // iPhone 15 Pro Max
        case UIDevice16ProiPhone:         // iPhone 16 Pro
        case UIDevice16ProMaxiPhone:      // iPhone 16 Pro Max
        case UIDevice16iPhone:            // iPhone 16
        case UIDevice16PlusiPhone:        // iPhone 16 Plus
        case UIDevice6GiPadMini:          // iPad mini (6th generation)
        case UIDevice4GiPadAir:           // iPad Air (4th generation)
        case UIDevice5GiPadAir:           // iPad Air (5th generation)
        case UIDevice9GiPad:              // iPad (9th generation)
        case UIDevice10GiPad:             // iPad (10th generation)
        case UIDevice4G129InchiPadPro:    // iPad Pro (12.9-inch, 4th generation)
        case UIDevice5G129InchiPadPro:    // iPad Pro (12.9-inch, 5th generation)
        case UIDevice6G129InchiPadPro:    // iPad Pro (12.9-inch, 6th generation)
        case UIDevice11Inch3GiPadPro:     // iPad Pro (11-inch, 3rd generation)
        case UIDevice11Inch4GiPadPro:     // iPad Pro (11-inch, 4th generation)
            return YES;

        // Default case
        default:
            return NO;
    }
}

- (NSString *)sfsdk_platformString {
    switch ([self sfsdk_platformType])
    {
        case UIDeviceSE2iPhone: return IPHONE_SE_2G_NAMESTRING;
        case UIDeviceSE3iPhone: return IPHONE_SE_3G_NAMESTRING;
        case UIDeviceXsiPhone: return IPHONE_XS_NAMESTRING;
        case UIDeviceXsMaxiPhone: return IPHONE_XSMAX_NAMESTRING;
        case UIDeviceXRiPhone: return IPHONE_XR_NAMESTRING;
        case UIDevice11iPhone: return IPHONE_11_NAMESTRING;
        case UIDevice11ProiPhone: return IPHONE_11_PRO_NAMESTRING;
        case UIDevice11ProMaxiPhone: return IPHONE_11_PRO_MAX_NAMESTRING;
        case UIDevice12MiniiPhone: return IPHONE_12_MINI_NAMESTRING;
        case UIDevice12iPhone: return IPHONE_12_NAMESTRING;
        case UIDevice12ProiPhone: return IPHONE_12_PRO_NAMESTRING;
        case UIDevice12ProMaxiPhone: return IPHONE_12_PRO_MAX_NAMESTRING;
        case UIDevice13MiniiPhone: return IPHONE_13_MINI_NAMESTRING;
        case UIDevice13iPhone: return IPHONE_13_NAMESTRING;
        case UIDevice13ProiPhone: return IPHONE_13_PRO_NAMESTRING;
        case UIDevice13ProMaxiPhone: return IPHONE_13_PRO_MAX_NAMESTRING;
        case UIDevice14iPhone: return IPHONE_14_NAMESTRING;
        case UIDevice14PlusiPhone: return IPHONE_14_PLUS_NAMESTRING;
        case UIDevice14ProiPhone: return IPHONE_14_PRO_NAMESTRING;
        case UIDevice14ProMaxiPhone: return IPHONE_14_PRO_MAX_NAMESTRING;
        case UIDevice15iPhone: return IPHONE_15_NAMESTRING;
        case UIDevice15PlusiPhone: return IPHONE_15_PLUS_NAMESTRING;
        case UIDevice15ProiPhone: return IPHONE_15_PRO_NAMESTRING;
        case UIDevice15ProMaxiPhone: return IPHONE_15_PRO_MAX_NAMESTRING;
        case UIDevice16ProiPhone: return IPHONE_16_PRO_NAMESTRING;   // iPhone 16 Pro
        case UIDevice16ProMaxiPhone: return IPHONE_16_PRO_MAX_NAMESTRING;   // iPhone 16 Pro Max
        case UIDevice16iPhone: return IPHONE_16_NAMESTRING;  // iPhone 16
        case UIDevice16PlusiPhone: return IPHONE_16_PLUS_NAMESTRING;  // iPhone 16 Plus

        case UIDeviceUnknowniPhone: return IPHONE_UNKNOWN_NAMESTRING;

        case UIDevice5GiPadMini: return IPAD_MINI_5G_NAMESTRING;
        case UIDevice6GiPadMini: return IPAD_MINI_6G_NAMESTRING;
        case UIDevice3GiPadAir: return IPAD_AIR_3G_NAMESTRING;
        case UIDevice4GiPadAir: return IPAD_AIR_4G_NAMESTRING;
        case UIDevice5GiPadAir: return IPAD_AIR_5G_NAMESTRING;
        case UIDevice7GiPad: return IPAD_7G_NAMESTRING;
        case UIDevice8GiPad: return IPAD_8G_NAMESTRING;
        case UIDevice9GiPad: return IPAD_9G_NAMESTRING;
        case UIDevice10GiPad: return IPAD_10G_NAMESTRING;
        case UIDevice3G129InchiPadPro: return IPAD_PRO_12_9_3G_NAMESTRING;
        case UIDevice4G129InchiPadPro: return IPAD_PRO_12_9_4G_NAMESTRING;
        case UIDevice5G129InchiPadPro: return IPAD_PRO_12_9_5G_NAMESTRING;
        case UIDevice6G129InchiPadPro: return IPAD_PRO_12_9_6G_NAMESTRING;
        case UIDevice11Inch2GiPadPro: return IPAD_PRO_11_2G_NAMESTRING;
        case UIDevice11Inch3GiPadPro: return IPAD_PRO_11_3G_NAMESTRING;
        case UIDevice11Inch4GiPadPro: return IPAD_PRO_11_4G_NAMESTRING;

        case UIDeviceUnknowniPad: return IPAD_UNKNOWN_NAMESTRING;

        case UIDeviceAppleTV4: return APPLETV_4G_NAMESTRING;
        case UIDeviceAppleTV4k: return APPLETV_4K_NAMESTRING;
        case UIDeviceAppleTV4k2G: return APPLETV_4K_2G_NAMESTRING;
        case UIDeviceAppleTV4k3G: return APPLETV_4K_3G_NAMESTRING;

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
        UIWindowScene *windowScene = (UIWindowScene *)[[[SFApplicationHelper sharedApplication] connectedScenes] anyObject];
        if ([windowScene isKindOfClass:[UIWindowScene class]]) {
            orientation = windowScene.interfaceOrientation;
        } else {
            orientation = UIInterfaceOrientationUnknown;
        }
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
