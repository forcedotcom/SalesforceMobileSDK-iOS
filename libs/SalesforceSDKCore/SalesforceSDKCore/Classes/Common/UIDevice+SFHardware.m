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

 // iPad Models
 iPad7,11   ->    iPad (7th Generation), D331AP
 iPad7,12   ->    iPad (7th Generation), D331AP
 iPad8,1    ->    iPad Pro (11-inch, 1st Generation), D42A
 iPad8,2    ->    iPad Pro (11-inch, 1st Generation), D42A
 iPad8,3    ->    iPad Pro (11-inch, 1st Generation), D42A
 iPad8,4    ->    iPad Pro (11-inch, 1st Generation), D42A
 iPad8,5    ->    iPad Pro (12.9-inch, 3rd Generation), J417AP
 iPad8,6    ->    iPad Pro (12.9-inch, 3rd Generation), J417AP
 iPad8,7    ->    iPad Pro (12.9-inch, 3rd Generation), J417AP
 iPad8,8    ->    iPad Pro (12.9-inch, 3rd Generation), J417AP
 iPad8,9    ->    iPad Pro (11-inch, 2nd Generation), D43AP
 iPad8,10   ->    iPad Pro (11-inch, 2nd Generation), D43AP
 iPad8,11   ->    iPad Pro (12.9-inch, 4th Generation), J418AP
 iPad8,12   ->    iPad Pro (12.9-inch, 4th Generation), J418AP
 iPad11,1   ->    iPad mini (5th Generation), J210AP
 iPad11,2   ->    iPad mini (5th Generation), J210AP
 iPad11,3   ->    iPad Air (3rd Generation), J230AP
 iPad11,4   ->    iPad Air (3rd Generation), J230AP
 iPad11,6   ->    iPad (8th Generation), J217AP
 iPad11,7   ->    iPad (8th Generation), J217AP
 iPad12,1   ->    iPad (9th Generation), J272AP
 iPad12,2   ->    iPad (9th Generation), J272AP
 iPad13,1   ->    iPad Air (4th Generation), J413AP
 iPad13,2   ->    iPad Air (4th Generation), J413AP
 iPad13,4   ->    iPad Pro (11-inch, 3rd Generation), D44AP
 iPad13,5   ->    iPad Pro (11-inch, 3rd Generation), D44AP
 iPad13,6   ->    iPad Pro (11-inch, 3rd Generation), D44AP
 iPad13,7   ->    iPad Pro (11-inch, 3rd Generation), D44AP
 iPad13,8   ->    iPad Pro (12.9-inch, 5th Generation, M1), J522AP
 iPad13,9   ->    iPad Pro (12.9-inch, 5th Generation, M1), J522AP
 iPad13,10  ->    iPad Pro (12.9-inch, 5th Generation, M1), J522AP
 iPad13,11  ->    iPad Pro (12.9-inch, 5th Generation, M1), J522AP
 iPad13,16  ->    iPad Air (5th Generation, M1), J517AP
 iPad13,17  ->    iPad Air (5th Generation, M1), J517AP
 iPad13,18  ->    iPad (10th Generation), J274AP
 iPad13,19  ->    iPad (10th Generation), J274AP
 iPad14,1   ->    iPad mini (6th Generation), J407AP
 iPad14,2   ->    iPad mini (6th Generation), J407AP
 iPad14,3   ->    iPad Pro (12.9-inch, 6th Generation, M2), J523AP
 iPad14,4   ->    iPad Pro (12.9-inch, 6th Generation, M2), J523AP
 iPad14,5   ->    iPad Pro (11-inch, 4th Generation, M2), D45AP
 iPad14,6   ->    iPad Pro (11-inch, 4th Generation, M2), D45AP

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
    
    // iPhones (iOS 17 and newer supported)
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
    };
    NSNumber *iphoneType = iphoneIdentifiers[platform];
    if (iphoneType) return iphoneType.integerValue;
    
    // iPads (iOS 17 and newer supported)
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
        @"iPad14,3": @(UIDevice6G129InchiPadPro),   // iPad Pro (12.9-inch, 6th generation)
        @"iPad14,4": @(UIDevice6G129InchiPadPro),   // iPad Pro (12.9-inch, 6th generation)
        @"iPad14,5": @(UIDevice11Inch4GiPadPro),    // iPad Pro (11-inch, 4th generation)
        @"iPad14,6": @(UIDevice11Inch4GiPadPro),    // iPad Pro (11-inch, 4th generation)
        @"iPad14,8": @(UIDevice6GiPadAir),          // iPad Air 6th Gen
        @"iPad14,9": @(UIDevice6GiPadAir),          // iPad Air 6th Gen
        @"iPad14,10": @(UIDevice7GiPadAir),          //iPad Air 7th Gen
        @"iPad14,11": @(UIDevice7GiPadAir),          //iPad Air 7th Gen
        @"iPad16,1": @(UIDevice7GiPadMini),          //iPad mini 7th Gen (WiFi)
        @"iPad16,2": @(UIDevice7GiPadMini),          //iPad mini 7th Gen (WiFi+Cellular)
        @"iPad16,3": @(UIDevice11Inch5GiPadPro),     //iPad Pro 11 inch 5th Gen
        @"iPad16,4": @(UIDevice11Inch5GiPadPro),     //iPad Pro 11 inch 5th Gen
        @"iPad16,5": @(UIDevice12Inch7GiPadPro),     //iPad Pro 12.9 inch 7th Gen
        @"iPad16,6": @(UIDevice12Inch7GiPadPro),     //iPad Pro 12.9 inch 7th Gen
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
        case UIDevice6GiPadAir: return IPAD_AIR_6G_NAMESTRING;
        case UIDevice7GiPadAir: return IPAD_AIR_7G_NAMESTRING;
        case UIDevice7GiPadMini: return IPAD_MINI_7G_NAMESTRING;
        case UIDevice11Inch5GiPadPro: return IPAD_PRO_11_5G_NAMESTRING;
        case UIDevice12Inch7GiPadPro: return IPAD_PRO_12_7G_NAMESTRING;

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
