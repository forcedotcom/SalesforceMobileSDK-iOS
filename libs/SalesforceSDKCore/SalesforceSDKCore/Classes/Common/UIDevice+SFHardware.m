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

#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>

#import "UIDevice+SFHardware.h"
#import "UIScreen+SFAdditions.h"
#import "SFLogger.h"
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
- (NSString *) getSysInfoByName:(char *)typeSpecifier
{
    size_t size;
    sysctlbyname(typeSpecifier, NULL, &size, NULL, 0);
    
    char *answer = malloc(size);
    sysctlbyname(typeSpecifier, answer, &size, NULL, 0);
    
    NSString *results = [NSString stringWithCString:answer encoding: NSUTF8StringEncoding];

    free(answer);
    return results;
}

- (NSString *) platform
{
    static NSString *result = nil;
    if (!result) {
        result = [self getSysInfoByName:"hw.machine"];
    }
    return result;
}


// Thanks, Tom Harrington (Atomicbird)
- (NSString *) hwmodel
{
    static NSString *result = nil;
    if (!result) {
        result = [self getSysInfoByName:"hw.model"];
    }
    return result;
}

- (double)systemVersionNumber
{
    static double version = 0;
    if (version == 0) {
        version = [[self systemVersion] doubleValue];
    }

    return version;
}

#pragma mark sysctl utils
- (NSUInteger) getSysInfo: (uint) typeSpecifier
{
    size_t size = sizeof(int);
    int results;
    int mib[2] = {CTL_HW, typeSpecifier};
    sysctl(mib, 2, &results, &size, NULL, 0);
    return (NSUInteger) results;
}

- (NSUInteger) cpuFrequency
{
    return [self getSysInfo:HW_CPU_FREQ];
}

- (NSUInteger) busFrequency
{
    return [self getSysInfo:HW_BUS_FREQ];
}

- (NSUInteger) cpuCount
{
    return [self getSysInfo:HW_NCPU];
}

- (NSUInteger) totalMemory
{
    return [self getSysInfo:HW_PHYSMEM];
}

- (NSUInteger) userMemory
{
    return [self getSysInfo:HW_USERMEM];
}

- (NSUInteger) applicationMemory
{
    struct mach_task_basic_info info;
    mach_msg_type_number_t size = MACH_TASK_BASIC_INFO_COUNT;
    kern_return_t kerr = task_info(mach_task_self(),
                                   MACH_TASK_BASIC_INFO,
                                   (task_info_t)&info,
                                   &size);
    
    return (kerr == KERN_SUCCESS) ? info.resident_size : 0;
}

/**Free VM page space available to application*/
- (NSUInteger) freeMemory
{
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

- (NSUInteger) maxSocketBufferSize
{
    return [self getSysInfo:KIPC_MAXSOCKBUF];
}

#pragma mark file system -- Thanks Joachim Bean!
- (NSNumber *) totalDiskSpace
{
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    NSDictionary *fattributes = [fileManager attributesOfFileSystemForPath:NSHomeDirectory() error:nil];
    return [fattributes objectForKey:NSFileSystemSize];
}

- (NSNumber *) freeDiskSpace
{
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    NSDictionary *fattributes = [fileManager attributesOfFileSystemForPath:NSHomeDirectory() error:nil];
    return [fattributes objectForKey:NSFileSystemFreeSize];
}

#pragma mark platform type and name utils
- (UIDevicePlatform) platformType
{
    NSString *platform = [self platform];
    
    // The ever mysterious iFPGA
    if ([platform isEqualToString:@"iFPGA"])        return UIDeviceIFPGA;
    
    // iPhone
    if ([platform isEqualToString:@"iPhone1,1"])    return UIDevice1GiPhone;
    if ([platform isEqualToString:@"iPhone1,2"])    return UIDevice3GiPhone;
    if ([platform hasPrefix:@"iPhone2"])            return UIDevice3GSiPhone;
    if ([platform hasPrefix:@"iPhone3"])            return UIDevice4iPhone;
    if ([platform hasPrefix:@"iPhone4"])            return UIDevice4SiPhone;

    if ([platform isEqualToString:@"iPhone5,1"])    return UIDevice5iPhone;
    if ([platform isEqualToString:@"iPhone5,2"])    return UIDevice5iPhone;
    if ([platform isEqualToString:@"iPhone5,3"])    return UIDevice5CiPhone;
    if ([platform isEqualToString:@"iPhone5,4"])    return UIDevice5CiPhone;
    if ([platform hasPrefix:@"iPhone6"])            return UIDevice5SiPhone;
    if ([platform isEqualToString:@"iPhone7,1"])    return UIDevice6PlusiPhone;
    if ([platform isEqualToString:@"iPhone7,2"])    return UIDevice6iPhone;
    if ([platform isEqualToString:@"iPhone8,1"])    return UIDevice6siPhone;
    if ([platform isEqualToString:@"iPhone8,2"])    return UIDevice6sPlusiPhone;
    
    // iPod
    if ([platform hasPrefix:@"iPod1"])              return UIDevice1GiPod;
    if ([platform hasPrefix:@"iPod2"])              return UIDevice2GiPod;
    if ([platform hasPrefix:@"iPod3"])              return UIDevice3GiPod;
    if ([platform hasPrefix:@"iPod4"])              return UIDevice4GiPod;
    
    // iPad
    if ([platform isEqualToString:@"iPad1,1"])      return UIDevice1GiPad;
    
    if ([platform isEqualToString:@"iPad2,1"])      return UIDevice2GiPad;
    if ([platform isEqualToString:@"iPad2,2"])      return UIDevice2GiPad;
    if ([platform isEqualToString:@"iPad2,3"])      return UIDevice2GiPad;
    if ([platform isEqualToString:@"iPad2,4"])      return UIDevice2GiPad;
    
    if ([platform isEqualToString:@"iPad2,5"])      return UIDevice1GiPadMini;
    if ([platform isEqualToString:@"iPad2,6"])      return UIDevice1GiPadMini;
    if ([platform isEqualToString:@"iPad2,7"])      return UIDevice1GiPadMini;
    
    if ([platform isEqualToString:@"iPad3,1"])      return UIDevice3GiPad;
    if ([platform isEqualToString:@"iPad3,2"])      return UIDevice3GiPad;
    if ([platform isEqualToString:@"iPad3,3"])      return UIDevice3GiPad;
    
    if ([platform isEqualToString:@"iPad3,4"])      return UIDevice4GiPad;
    if ([platform isEqualToString:@"iPad3,5"])      return UIDevice4GiPad;
    if ([platform isEqualToString:@"iPad3,6"])      return UIDevice4GiPad;
    
    if ([platform isEqualToString:@"iPad4,1"])      return UIDevice1GiPadAir;
    if ([platform isEqualToString:@"iPad4,2"])      return UIDevice1GiPadAir;
    if ([platform isEqualToString:@"iPad4,3"])      return UIDevice1GiPadAir;
    if ([platform isEqualToString:@"iPad4,4"])      return UIDevice2GiPadMini;
    if ([platform isEqualToString:@"iPad4,5"])      return UIDevice2GiPadMini;
    if ([platform isEqualToString:@"iPad4,6"])      return UIDevice2GiPadMini;
    if ([platform isEqualToString:@"iPad4,7"])      return UIDevice3GiPadMini;
    if ([platform isEqualToString:@"iPad4,8"])      return UIDevice3GiPadMini;
    if ([platform isEqualToString:@"iPad4,9"])      return UIDevice3GiPadMini;
    
    if ([platform isEqualToString:@"iPad5,3"])      return UIDevice2GiPadAir;
    if ([platform isEqualToString:@"iPad5,4"])      return UIDevice2GiPadAir;
    
    // Apple TV
    if ([platform hasPrefix:@"AppleTV2"])           return UIDeviceAppleTV2;
    if ([platform hasPrefix:@"AppleTV3"])           return UIDeviceAppleTV3;
    
    if ([platform hasPrefix:@"iPhone"]) {
        return UIDeviceUnknowniPhone;
    }
    
    if ([platform hasPrefix:@"iPod"])               return UIDeviceUnknowniPod;
    if ([platform hasPrefix:@"iPad"])               return UIDeviceUnknowniPad;
    if ([platform hasPrefix:@"AppleTV"])            return UIDeviceUnknownAppleTV;
    
    // Simulator thanks Jordan Breeding
    if ([platform hasSuffix:@"86"] || [platform isEqual:@"x86_64"])
    {
        if ([self hasIphone6ScreenSize]) {
            return UIDeviceSimulatoriPhone6;
        } else if ([self hasIphone6PlusScreenSize]) {
            return UIDeviceSimulatoriPhone6Plus;
        } else {
            BOOL smallerScreen = [[UIScreen mainScreen] bounds].size.width < 768;
            return smallerScreen ? UIDeviceSimulatoriPhone : UIDeviceSimulatoriPad;
        }
    }
    
    return UIDeviceUnknown;
}

- (NSString *) platformString
{
    switch ([self platformType])
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
        case UIDeviceUnknowniPhone: return IPHONE_UNKNOWN_NAMESTRING;
            
        case UIDevice1GiPod: return IPOD_1G_NAMESTRING;
        case UIDevice2GiPod: return IPOD_2G_NAMESTRING;
        case UIDevice3GiPod: return IPOD_3G_NAMESTRING;
        case UIDevice4GiPod: return IPOD_4G_NAMESTRING;
        case UIDeviceUnknowniPod: return IPOD_UNKNOWN_NAMESTRING;
            
        case UIDevice1GiPad : return IPAD_1G_NAMESTRING;
        case UIDevice2GiPad : return IPAD_2G_NAMESTRING;
        case UIDevice3GiPad : return IPAD_3G_NAMESTRING;
        case UIDevice4GiPad : return IPAD_4G_NAMESTRING;
        case UIDevice1GiPadAir: return IPAD_AIR_1G_NAMESTRING;
        case UIDevice2GiPadAir: return IPAD_AIR_2G_NAMESTRING;
        case UIDevice1GiPadMini: return  IPAD_MINI_1G_NAMESTRING;
        case UIDevice2GiPadMini: return  IPAD_MINI_2G_NAMESTRING;
        case UIDevice3GiPadMini: return  IPAD_MINI_3G_NAMESTRING;
        case UIDeviceUnknowniPad : return IPAD_UNKNOWN_NAMESTRING;
            
        case UIDeviceAppleTV2 : return APPLETV_2G_NAMESTRING;
        case UIDeviceAppleTV3 : return APPLETV_3G_NAMESTRING;
        case UIDeviceAppleTV4 : return APPLETV_4G_NAMESTRING;
        case UIDeviceUnknownAppleTV: return APPLETV_UNKNOWN_NAMESTRING;
            
        case UIDeviceSimulator: return SIMULATOR_NAMESTRING;
        case UIDeviceSimulatoriPhone: return SIMULATOR_IPHONE_NAMESTRING;
        case UIDeviceSimulatoriPad: return SIMULATOR_IPAD_NAMESTRING;
        case UIDeviceSimulatorAppleTV: return SIMULATOR_APPLETV_NAMESTRING;
            
        case UIDeviceIFPGA: return IFPGA_NAMESTRING;
            
        default: return IOS_FAMILY_UNKNOWN_DEVICE;
    }
}

- (BOOL) hasRetinaDisplay
{
    return ([UIScreen mainScreen].scale > 1.0f);
}

- (UIDeviceFamily) deviceFamily
{
    NSString *platform = [self platform];
    if ([platform hasPrefix:@"iPhone"]) return UIDeviceFamilyiPhone;
    if ([platform hasPrefix:@"iPod"]) return UIDeviceFamilyiPod;
    if ([platform hasPrefix:@"iPad"]) return UIDeviceFamilyiPad;
    if ([platform hasPrefix:@"AppleTV"]) return UIDeviceFamilyAppleTV;
    
    return UIDeviceFamilyUnknown;
}

#pragma mark MAC addy
// Return the local MAC addy
// Courtesy of FreeBSD hackers email list
// Accidentally munged during previous update. Fixed thanks to mlamb.
- (NSString *) macaddress
{
    int                 mib[6];
    size_t              len;
    char                *buf;
    unsigned char       *ptr;
    struct if_msghdr    *ifm;
    struct sockaddr_dl  *sdl;
    
    mib[0] = CTL_NET;
    mib[1] = AF_ROUTE;
    mib[2] = 0;
    mib[3] = AF_LINK;
    mib[4] = NET_RT_IFLIST;
    
    if ((mib[5] = if_nametoindex("en0")) == 0) {
        // we've only seen this case when running on Jenkins where the simulator shares the server's ifaces (ifconfig)
        // to fix this, we will try to find en1 which hopefully also exists.
        [self log:SFLogLevelWarning msg:@"if_nametoindex could not find en0, trying en1"];
        if ((mib[5] = if_nametoindex("en1")) == 0) {
            [self log:SFLogLevelError msg:@"if_nametoindex error"];
            return NULL;
        }
    }
    
    if (sysctl(mib, 6, NULL, &len, NULL, 0) < 0) {
        [self log:SFLogLevelError msg:@"sysctl, take 1"];
        return NULL;
    }
    
    if ((buf = malloc(len)) == NULL) {
        [self log:SFLogLevelError msg:@"Memory allocation error"];
        return NULL;
    }
    
    if (sysctl(mib, 6, buf, &len, NULL, 0) < 0) {
        [self log:SFLogLevelError msg:@"sysctl, take 2"];
        free(buf); // Thanks, Remy "Psy" Demerest
        return NULL;
    }
    
    ifm = (struct if_msghdr *)buf;
    sdl = (struct sockaddr_dl *)(ifm + 1);
    ptr = (unsigned char *)LLADDR(sdl);
    NSString *outstring = [NSString stringWithFormat:@"%02X:%02X:%02X:%02X:%02X:%02X", *ptr, *(ptr+1), *(ptr+2), *(ptr+3), *(ptr+4), *(ptr+5)];
    
    free(buf);
    return outstring;
}

- (UIInterfaceOrientation)interfaceOrientation {
    UIDeviceOrientation deviceOrientation = [[UIDevice currentDevice] orientation];
    UIInterfaceOrientation orientation = (UIInterfaceOrientation)deviceOrientation;
    if (!UIDeviceOrientationIsValidInterfaceOrientation(orientation)) {
        orientation = [[SFApplicationHelper sharedApplication] statusBarOrientation];
    }
    return orientation;
}

- (BOOL)isSimulator {
    NSString *platform = [self platform];
    if ([platform hasSuffix:@"86"] || [platform isEqual:@"x86_64"]) {
        return YES;
    }
    return NO;
}

- (BOOL)hasIphone6ScreenSize {
   return  CGRectGetHeight([[UIScreen mainScreen] portraitScreenBounds]) == 667.0f && CGRectGetWidth([[UIScreen mainScreen] portraitScreenBounds]) == 375.0f;
}

- (BOOL)hasIphone6PlusScreenSize {
    return  CGRectGetHeight([[UIScreen mainScreen] portraitScreenBounds]) == 736.0f && CGRectGetWidth([[UIScreen mainScreen] portraitScreenBounds]) == 414.0f;
}

#pragma mark - 

- (BOOL)canDevicePlaceAPhoneCall {
    BOOL canPlaceCall = NO;
    // Check if the device can place a phone call
    if ([[SFApplicationHelper sharedApplication] canOpenURL:[NSURL URLWithString:@"tel://"]]) {
        // Confirm it can make a phone call right now
        CTTelephonyNetworkInfo *netInfo = [[CTTelephonyNetworkInfo alloc] init];
        CTCarrier *carrier = [netInfo subscriberCellularProvider];
        NSString *mnc = [carrier mobileNetworkCode];
        canPlaceCall = [mnc length] != 0;
    }
    return canPlaceCall;
}

@end