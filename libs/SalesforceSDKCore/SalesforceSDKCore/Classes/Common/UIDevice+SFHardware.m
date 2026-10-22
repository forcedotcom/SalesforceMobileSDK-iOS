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
// Hardware identifiers are mapped in sfsdk_platformType below.


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
    
    // Simulators
    if ([self sfsdk_isSimulator]) {
        UIDevice *device = [UIDevice currentDevice];
        
        switch (device.userInterfaceIdiom) {
            case UIUserInterfaceIdiomPhone:
                return UIDeviceSimulatoriPhone;
            case UIUserInterfaceIdiomPad:
                return UIDeviceSimulatoriPad;
            default:
                return UIDeviceSimulator;
        }
    }
    
    // iPhones (iOS 18 and newer supported)
    NSDictionary *iphoneIdentifiers = @{
        @"iPhone12,8": @(UIDeviceSE2iPhone),           // iPhone SE (2nd generation)
        @"iPhone14,6": @(UIDeviceSE3iPhone),           // iPhone SE (3rd generation)
        @"iPhone11,8": @(UIDeviceXRiPhone),            // iPhone XR
        @"iPhone11,2": @(UIDeviceXsiPhone),            // iPhone XS
        @"iPhone11,4": @(UIDeviceXsMaxiPhone),         // iPhone XS Max (China)
        @"iPhone11,6": @(UIDeviceXsMaxiPhone),         // iPhone XS Max (Global)
        @"iPhone12,1": @(UIDevice11iPhone),           // iPhone 11
        @"iPhone12,3": @(UIDevice11ProiPhone),        // iPhone 11 Pro
        @"iPhone12,5": @(UIDevice11ProMaxiPhone),     // iPhone 11 Pro Max
        @"iPhone13,1": @(UIDevice12MiniiPhone),       // iPhone 12 Mini
        @"iPhone13,2": @(UIDevice12iPhone),           // iPhone 12
        @"iPhone13,3": @(UIDevice12ProiPhone),        // iPhone 12 Pro
        @"iPhone13,4": @(UIDevice12ProMaxiPhone),     // iPhone 12 Pro Max
        @"iPhone14,4": @(UIDevice13MiniiPhone),       // iPhone 13 Mini
        @"iPhone14,5": @(UIDevice13iPhone),           // iPhone 13
        @"iPhone14,2": @(UIDevice13ProiPhone),        // iPhone 13 Pro
        @"iPhone14,3": @(UIDevice13ProMaxiPhone),     // iPhone 13 Pro Max
        @"iPhone14,7": @(UIDevice14iPhone),           // iPhone 14
        @"iPhone14,8": @(UIDevice14PlusiPhone),       // iPhone 14 Plus
        @"iPhone15,2": @(UIDevice14ProiPhone),        // iPhone 14 Pro
        @"iPhone15,3": @(UIDevice14ProMaxiPhone),     // iPhone 14 Pro Max
        @"iPhone15,4": @(UIDevice15iPhone),           // iPhone 15
        @"iPhone15,5": @(UIDevice15PlusiPhone),       // iPhone 15 Plus
        @"iPhone16,1": @(UIDevice15ProiPhone),        // iPhone 15 Pro
        @"iPhone16,2": @(UIDevice15ProMaxiPhone),     // iPhone 15 Pro Max
        @"iPhone17,1": @(UIDevice16ProiPhone),        // iPhone 16 Pro
        @"iPhone17,2": @(UIDevice16ProMaxiPhone),     // iPhone 16 Pro Max
        @"iPhone17,3": @(UIDevice16iPhone),           // iPhone 16
        @"iPhone17,4": @(UIDevice16PlusiPhone),       // iPhone 16 Plus
        @"iPhone17,5": @(UIDevice16eiPhone), // iPhone 16e
        @"iPhone18,3": @(UIDevice17iPhone), // iPhone 17
        @"iPhone18,1": @(UIDevice17ProiPhone), // iPhone 17 Pro
        @"iPhone18,2": @(UIDevice17ProMaxiPhone), // iPhone 17 Pro Max
        @"iPhone18,4": @(UIDeviceAiriPhone), // iPhone Air
        @"iPhone18,5": @(UIDevice17eiPhone), // iPhone 17e
        @"iPhone19,2": @(UIDevice18ProiPhone), // iPhone 18 Pro
        @"iPhone19,3": @(UIDevice18ProMaxiPhone), // iPhone 18 Pro Max
        @"iPhone19,7": @(UIDevice18ProMaxiPhone), // iPhone 18 Pro Max
    };
    NSNumber *iphoneType = iphoneIdentifiers[platform];
    if (iphoneType) return iphoneType.integerValue;
    
    // iPads (iOS 18 and newer supported)
    NSDictionary *ipadIdentifiers = @{
        @"iPad7,11": @(UIDevice7GiPad),              // iPad (7th generation)
        @"iPad7,12": @(UIDevice7GiPad),              // iPad (7th generation)
        @"iPad8,1":  @(UIDevice11InchiPadPro),        // iPad Pro (11-inch, 1st generation)
        @"iPad8,2":  @(UIDevice11InchiPadPro),        // iPad Pro (11-inch, 1st generation)
        @"iPad8,3":  @(UIDevice11InchiPadPro),        // iPad Pro (11-inch, 1st generation)
        @"iPad8,4":  @(UIDevice11InchiPadPro),        // iPad Pro (11-inch, 1st generation)
        @"iPad8,5":  @(UIDevice3G129InchiPadPro),     // iPad Pro (12.9-inch, 3rd generation)
        @"iPad8,6":  @(UIDevice3G129InchiPadPro),     // iPad Pro (12.9-inch, 3rd generation)
        @"iPad8,7":  @(UIDevice3G129InchiPadPro),     // iPad Pro (12.9-inch, 3rd generation)
        @"iPad8,8":  @(UIDevice3G129InchiPadPro),     // iPad Pro (12.9-inch, 3rd generation)
        @"iPad8,9":  @(UIDevice11Inch2GiPadPro),      // iPad Pro (11-inch, 2nd generation)
        @"iPad8,10": @(UIDevice11Inch2GiPadPro),      // iPad Pro (11-inch, 2nd generation)
        @"iPad8,11": @(UIDevice4G129InchiPadPro),     // 4th generation of the iPad Pro 12.9-inch
        @"iPad8,12": @(UIDevice4G129InchiPadPro),     // 4th generation of the iPad Pro 12.9-inch
        @"iPad11,3": @(UIDevice3GiPadAir),          // iPad Air (3rd generation)
        @"iPad11,4": @(UIDevice3GiPadAir),          // iPad Air (3rd generation)
        @"iPad11,1": @(UIDevice5GiPadMini),         // iPad mini (5th generation)
        @"iPad11,2": @(UIDevice5GiPadMini),         // iPad mini (5th generation)
        @"iPad11,6": @(UIDevice8GiPad),             // iPad (8th generation)
        @"iPad11,7": @(UIDevice8GiPad),             // iPad (8th generation)
        @"iPad12,1": @(UIDevice9GiPad),             // iPad (9th generation)
        @"iPad12,2": @(UIDevice9GiPad),             // iPad (9th generation)
        @"iPad13,1": @(UIDevice4GiPadAir),          // iPad Air (4th generation)
        @"iPad13,2": @(UIDevice4GiPadAir),          // iPad Air (4th generation)
        @"iPad13,4": @(UIDevice11Inch3GiPadPro),    // iPad Pro (11-inch, 3rd generation)
        @"iPad13,5": @(UIDevice11Inch3GiPadPro),    // iPad Pro (11-inch, 3rd generation)
        @"iPad13,6": @(UIDevice11Inch3GiPadPro),    // iPad Pro (11-inch, 3rd generation)
        @"iPad13,7": @(UIDevice11Inch3GiPadPro),    // iPad Pro (11-inch, 3rd generation)
        @"iPad13,8": @(UIDevice5G129InchiPadPro),   // iPad Pro (12.9-inch, M1)
        @"iPad13,9": @(UIDevice5G129InchiPadPro),   // iPad Pro (12.9-inch, M1)
        @"iPad13,10": @(UIDevice5G129InchiPadPro),  // iPad Pro (12.9-inch, M1)
        @"iPad13,11": @(UIDevice5G129InchiPadPro),  // iPad Pro (12.9-inch, M1)
        @"iPad13,16": @(UIDevice5GiPadAir),         // iPad Air (5th generation)
        @"iPad13,17": @(UIDevice5GiPadAir),         // iPad Air (5th generation)
        @"iPad13,18": @(UIDevice10GiPad),           // iPad (10th generation)
        @"iPad13,19": @(UIDevice10GiPad),           // iPad (10th generation)
        @"iPad14,1": @(UIDevice6GiPadMini),         // iPad mini (6th generation)
        @"iPad14,2": @(UIDevice6GiPadMini),         // iPad mini (6th generation)
        @"iPad14,3": @(UIDevice11Inch4GiPadPro),    // iPad Pro (11-inch, 4th generation, M2)
        @"iPad14,4": @(UIDevice11Inch4GiPadPro),    // iPad Pro (11-inch, 4th generation, M2)
        @"iPad14,5": @(UIDevice6G129InchiPadPro),   // iPad Pro (12.9-inch, 6th generation, M2)
        @"iPad14,6": @(UIDevice6G129InchiPadPro),   // iPad Pro (12.9-inch, 6th generation, M2)
        @"iPad14,8": @(UIDevice6GiPadAir),          // iPad Air 11-inch (M2)
        @"iPad14,9": @(UIDevice6GiPadAir),          // iPad Air 11-inch (M2)
        @"iPad14,10": @(UIDevice7GiPadAir),          // iPad Air 13-inch (M2)
        @"iPad14,11": @(UIDevice7GiPadAir),          // iPad Air 13-inch (M2)
        @"iPad16,1": @(UIDevice7GiPadMini),          // iPad mini (A17 Pro)
        @"iPad16,2": @(UIDevice7GiPadMini),          // iPad mini (A17 Pro)
        @"iPad16,3": @(UIDevice11Inch5GiPadPro),     // iPad Pro 11-inch (M4)
        @"iPad16,4": @(UIDevice11Inch5GiPadPro),     // iPad Pro 11-inch (M4)
        @"iPad16,5": @(UIDevice12Inch7GiPadPro),     // iPad Pro 13-inch (M4)
        @"iPad16,6": @(UIDevice12Inch7GiPadPro),     // iPad Pro 13-inch (M4)
        @"iPad15,7": @(UIDeviceA16iPad), // iPad (A16)
        @"iPad15,8": @(UIDeviceA16iPad), // iPad (A16)
        @"iPad15,3": @(UIDeviceM3iPadAir11Inch), // iPad Air 11-inch (M3)
        @"iPad15,4": @(UIDeviceM3iPadAir11Inch), // iPad Air 11-inch (M3)
        @"iPad15,5": @(UIDeviceM3iPadAir13Inch), // iPad Air 13-inch (M3)
        @"iPad15,6": @(UIDeviceM3iPadAir13Inch), // iPad Air 13-inch (M3)
        @"iPad16,8": @(UIDeviceM4iPadAir11Inch), // iPad Air 11-inch (M4)
        @"iPad16,9": @(UIDeviceM4iPadAir11Inch), // iPad Air 11-inch (M4)
        @"iPad16,10": @(UIDeviceM4iPadAir13Inch), // iPad Air 13-inch (M4)
        @"iPad16,11": @(UIDeviceM4iPadAir13Inch), // iPad Air 13-inch (M4)
        @"iPad17,1": @(UIDeviceM5iPadPro11Inch), // iPad Pro 11-inch (M5)
        @"iPad17,2": @(UIDeviceM5iPadPro11Inch), // iPad Pro 11-inch (M5)
        @"iPad17,3": @(UIDeviceM5iPadPro13Inch), // iPad Pro 13-inch (M5)
        @"iPad17,4": @(UIDeviceM5iPadPro13Inch), // iPad Pro 13-inch (M5)
    };
    NSNumber *ipadType = ipadIdentifiers[platform];
    if (ipadType) return ipadType.integerValue;
    
    // Apple TVs
    NSDictionary *appleTVIdentifiers = @{
        @"AppleTV5,3": @(UIDeviceAppleTV4),        // Apple TV HD
        @"AppleTV6,2": @(UIDeviceAppleTV4k),       // Apple TV 4K (1st generation)
        @"AppleTV11,1": @(UIDeviceAppleTV4k2G),    // Apple TV 4K (2nd generation)
        @"AppleTV14,1": @(UIDeviceAppleTV4k3G),    // Apple TV 4K (3rd generation)
    };
    NSNumber *appleTVType = appleTVIdentifiers[platform];
    if (appleTVType) return appleTVType.integerValue;
    
    // Check for any identifiers we might have missed.
    if ([platform hasPrefix:@"iPhone"]) return UIDeviceUnknowniPhone;
    if ([platform hasPrefix:@"iPad"]) return UIDeviceUnknowniPad;
    if ([platform hasPrefix:@"AppleTV"]) return UIDeviceUnknownAppleTV;
    
    return UIDeviceUnknown;  // Unknown platform fallback
}

- (BOOL)sfsdk_hasNeuralEngine {
    if (![UIDevice sfsdk_currentDeviceIsIPad] && ![UIDevice sfsdk_currentDeviceIsIPhone]) {
        return NO;
    }
    
    UIDevicePlatform platform = [self sfsdk_platformType];
    switch (platform) {
        // The A10-based iPad (7th generation) has no Neural Engine.
        case UIDevice7GiPad:
            return NO;

        // All other recognized iPhones/iPads use A12/A12X or newer chips.
        case UIDeviceSE2iPhone:
        case UIDeviceSE3iPhone:
        case UIDeviceXRiPhone:
        case UIDeviceXsiPhone:
        case UIDeviceXsMaxiPhone:
        case UIDevice11iPhone:
        case UIDevice11ProiPhone:
        case UIDevice11ProMaxiPhone:
        case UIDevice12MiniiPhone:
        case UIDevice12iPhone:
        case UIDevice12ProiPhone:
        case UIDevice12ProMaxiPhone:
        case UIDevice13MiniiPhone:
        case UIDevice13iPhone:
        case UIDevice13ProiPhone:
        case UIDevice13ProMaxiPhone:
        case UIDevice14iPhone:
        case UIDevice14PlusiPhone:
        case UIDevice14ProiPhone:
        case UIDevice14ProMaxiPhone:
        case UIDevice15iPhone:
        case UIDevice15PlusiPhone:
        case UIDevice15ProiPhone:
        case UIDevice15ProMaxiPhone:
        case UIDevice16ProiPhone:
        case UIDevice16ProMaxiPhone:
        case UIDevice16iPhone:
        case UIDevice16PlusiPhone:
        case UIDevice16eiPhone:
        case UIDevice17iPhone:
        case UIDevice17ProiPhone:
        case UIDevice17ProMaxiPhone:
        case UIDeviceAiriPhone:
        case UIDevice17eiPhone:
        case UIDevice18ProiPhone:
        case UIDevice18ProMaxiPhone:
        case UIDevice11InchiPadPro:
        case UIDevice3G129InchiPadPro:
        case UIDevice11Inch2GiPadPro:
        case UIDevice4G129InchiPadPro:
        case UIDevice3GiPadAir:
        case UIDevice5GiPadMini:
        case UIDevice8GiPad:
        case UIDevice9GiPad:
        case UIDevice4GiPadAir:
        case UIDevice11Inch3GiPadPro:
        case UIDevice5G129InchiPadPro:
        case UIDevice5GiPadAir:
        case UIDevice10GiPad:
        case UIDevice6GiPadMini:
        case UIDevice11Inch4GiPadPro:
        case UIDevice6G129InchiPadPro:
        case UIDevice6GiPadAir:
        case UIDevice7GiPadAir:
        case UIDevice7GiPadMini:
        case UIDevice11Inch5GiPadPro:
        case UIDevice12Inch7GiPadPro:
        case UIDeviceA16iPad:
        case UIDeviceM3iPadAir11Inch:
        case UIDeviceM3iPadAir13Inch:
        case UIDeviceM4iPadAir11Inch:
        case UIDeviceM4iPadAir13Inch:
        case UIDeviceM5iPadPro11Inch:
        case UIDeviceM5iPadPro13Inch:
        case UIDeviceM1iPadPro129Inch:
            return YES;

        // Do not infer hardware capabilities for unknown models or simulators.
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
        case UIDevice16eiPhone: return IPHONE_16E_NAMESTRING;
        case UIDevice17iPhone: return IPHONE_17_NAMESTRING;
        case UIDevice17ProiPhone: return IPHONE_17_PRO_NAMESTRING;
        case UIDevice17ProMaxiPhone: return IPHONE_17_PRO_MAX_NAMESTRING;
        case UIDeviceAiriPhone: return IPHONE_AIR_NAMESTRING;
        case UIDevice17eiPhone: return IPHONE_17E_NAMESTRING;
        case UIDevice18ProiPhone: return IPHONE_18_PRO_NAMESTRING;
        case UIDevice18ProMaxiPhone: return IPHONE_18_PRO_MAX_NAMESTRING;

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
        case UIDevice11InchiPadPro: return IPAD_PRO_11_1G_NAMESTRING;
        case UIDevice11Inch2GiPadPro: return IPAD_PRO_11_2G_NAMESTRING;
        case UIDevice11Inch3GiPadPro: return IPAD_PRO_11_3G_NAMESTRING;
        case UIDevice11Inch4GiPadPro: return IPAD_PRO_11_4G_NAMESTRING;
        case UIDevice6GiPadAir: return IPAD_AIR_6G_NAMESTRING;
        case UIDevice7GiPadAir: return IPAD_AIR_7G_NAMESTRING;
        case UIDevice7GiPadMini: return IPAD_MINI_7G_NAMESTRING;
        case UIDevice11Inch5GiPadPro: return IPAD_PRO_11_5G_NAMESTRING;
        case UIDevice12Inch7GiPadPro: return IPAD_PRO_12_7G_NAMESTRING;

        case UIDeviceA16iPad: return IPAD_A16_NAMESTRING;
        case UIDeviceM3iPadAir11Inch: return IPAD_AIR_11_M3_NAMESTRING;
        case UIDeviceM3iPadAir13Inch: return IPAD_AIR_13_M3_NAMESTRING;
        case UIDeviceM4iPadAir11Inch: return IPAD_AIR_11_M4_NAMESTRING;
        case UIDeviceM4iPadAir13Inch: return IPAD_AIR_13_M4_NAMESTRING;
        case UIDeviceM5iPadPro11Inch: return IPAD_PRO_11_M5_NAMESTRING;
        case UIDeviceM5iPadPro13Inch: return IPAD_PRO_13_M5_NAMESTRING;

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
