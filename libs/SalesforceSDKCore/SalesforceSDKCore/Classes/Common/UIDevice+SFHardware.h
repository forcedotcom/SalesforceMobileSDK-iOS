/*
 Erica Sadun, http://ericasadun.com
 iPhone Developer's Cookbook, 6.x Edition
 BSD License, Use at your own risk
 */

#import <UIKit/UIKit.h>

#define IFPGA_NAMESTRING                @"iFPGA"

#define IPHONE_1G_NAMESTRING            @"iPhone 1G"
#define IPHONE_3G_NAMESTRING            @"iPhone 3G"
#define IPHONE_3GS_NAMESTRING           @"iPhone 3GS" 
#define IPHONE_4_NAMESTRING             @"iPhone 4"
#define IPHONE_4S_NAMESTRING            @"iPhone 4S"
#define IPHONE_5_NAMESTRING             @"iPhone 5"
#define IPHONE_5C_NAMESTRING            @"iPhone 5C"
#define IPHONE_5S_NAMESTRING            @"iPhone 5S"
#define IPHONE_6_NAMESTRING             @"iPhone 6"
#define IPHONE_6P_NAMESTRING            @"iPhone 6+"
#define IPHONE_6s_NAMESTRING             @"iPhone 6s"
#define IPHONE_6sP_NAMESTRING            @"iPhone 6s+"
#define IPHONE_UNKNOWN_NAMESTRING       @"Unknown iPhone"

#define IPOD_1G_NAMESTRING              @"iPod touch 1G"
#define IPOD_2G_NAMESTRING              @"iPod touch 2G"
#define IPOD_3G_NAMESTRING              @"iPod touch 3G"
#define IPOD_4G_NAMESTRING              @"iPod touch 4G"
#define IPOD_UNKNOWN_NAMESTRING         @"Unknown iPod"

#define IPAD_1G_NAMESTRING              @"iPad 1G"
#define IPAD_2G_NAMESTRING              @"iPad 2G"
#define IPAD_3G_NAMESTRING              @"iPad 3G"
#define IPAD_4G_NAMESTRING              @"iPad 4G"
#define IPAD_AIR_1G_NAMESTRING          @"iPad Air 1G"
#define IPAD_AIR_2G_NAMESTRING          @"iPad Air 2G"

#define IPAD_UNKNOWN_NAMESTRING         @"Unknown iPad"

#define IPAD_MINI_1G_NAMESTRING         @"iPad mini 1G"
#define IPAD_MINI_2G_NAMESTRING         @"iPad mini 2G"
#define IPAD_MINI_3G_NAMESTRING         @"iPad mini 3G"

#define APPLETV_2G_NAMESTRING           @"Apple TV 2G"
#define APPLETV_3G_NAMESTRING           @"Apple TV 3G"
#define APPLETV_4G_NAMESTRING           @"Apple TV 4G"
#define APPLETV_UNKNOWN_NAMESTRING      @"Unknown Apple TV"

#define IOS_FAMILY_UNKNOWN_DEVICE       @"Unknown iOS device"

#define SIMULATOR_NAMESTRING            @"iPhone Simulator"
#define SIMULATOR_IPHONE_NAMESTRING     @"iPhone Simulator"
#define SIMULATOR_IPAD_NAMESTRING       @"iPad Simulator"
#define SIMULATOR_APPLETV_NAMESTRING    @"Apple TV Simulator"

typedef NS_ENUM(NSUInteger, UIDevicePlatform) {
    UIDeviceUnknown,
    
    UIDeviceSimulator,
    UIDeviceSimulatoriPhone,
    UIDeviceSimulatoriPhone6,
    UIDeviceSimulatoriPhone6Plus,
    UIDeviceSimulatoriPad,
    UIDeviceSimulatorAppleTV,
    
    UIDevice1GiPhone,
    UIDevice3GiPhone,
    UIDevice3GSiPhone,
    UIDevice4iPhone,
    UIDevice4SiPhone,
    UIDevice5iPhone,
    UIDevice5CiPhone,
    UIDevice5SiPhone,
    UIDevice6iPhone,
    UIDevice6PlusiPhone,
    UIDevice6siPhone,
    UIDevice6sPlusiPhone,
    
    UIDevice1GiPod,
    UIDevice2GiPod,
    UIDevice3GiPod,
    UIDevice4GiPod,
    
    UIDevice1GiPad,
    UIDevice2GiPad,
    UIDevice3GiPad,
    UIDevice4GiPad,
    UIDevice1GiPadAir,
    UIDevice2GiPadAir,
    
    UIDevice1GiPadMini,
    UIDevice2GiPadMini,
    UIDevice3GiPadMini,
    
    UIDeviceAppleTV2,
    UIDeviceAppleTV3,
    UIDeviceAppleTV4,
    
    UIDeviceUnknowniPhone,
    UIDeviceUnknowniPod,
    UIDeviceUnknowniPad,
    UIDeviceUnknownAppleTV,
    UIDeviceIFPGA
};

typedef NS_ENUM(NSUInteger, UIDeviceFamily) {
    UIDeviceFamilyiPhone,
    UIDeviceFamilyiPod,
    UIDeviceFamilyiPad,
    UIDeviceFamilyAppleTV,
    UIDeviceFamilyUnknown
};

/**Extension to UIDevice class to provide more hardware related information, including hardware model, capability and also most importantly current device's orientation
 */
@interface UIDevice (SFHardware)

/**Platform for the Device*/
- (NSString *) platform;

/**Hardware model*/
- (NSString *) hwmodel;

/**Platform type
 See `UIDevicePlatform`
 */
- (UIDevicePlatform) platformType;

/**Returns the system-dependent version number.
 @return The system version number.
 */
- (double)systemVersionNumber;

/**Platform string
 
 Valid values are defined above in the IPHONE_XX_NAMESTRING and IPAD_XXX_NAMESTRING
 */
- (NSString *) platformString;

/**CPU Frequency*/
- (NSUInteger) cpuFrequency;

/**Bus frequency*/
- (NSUInteger) busFrequency;

/**CPU Count*/
- (NSUInteger) cpuCount;

/**Total memory*/
- (NSUInteger) totalMemory;

/**User Memory*/
- (NSUInteger) userMemory;

/**Memory used by application (in bytes)*/
- (NSUInteger) applicationMemory;

/**Free VM page space available to application (in bytes)*/
- (NSUInteger) freeMemory;

/**Total disk space*/
- (NSNumber *) totalDiskSpace;

/**Total free space*/
- (NSNumber *) freeDiskSpace;

/**Mac address*/
- (NSString *) macaddress;

/**Returns whether the device has a retina display*/
- (BOOL) hasRetinaDisplay;

/**Device Family*/
- (UIDeviceFamily) deviceFamily;

/**Device's current orientation
 This method will first try to retrieve orientation using UIDevice currentOrientation, if return value is an invalid orientation, it will try to use status bar orientation as fallback
 */
- (UIInterfaceOrientation)interfaceOrientation;

/**
 *  Determine if current device is simulator or not
 *
 *  @return Return YES if current device is simulator, NO otherwise.
 */
- (BOOL)isSimulator;

/** Determines whether the current device can place phone calls.
 * @return Returns YES if the current device can make a phone call, NO otherwise.
 */
- (BOOL)canDevicePlaceAPhoneCall;

/** Determine if the current device has the screen size of an iPhone 6.
 * @return Returns YES if so, NO otherwise.
 */
- (BOOL)hasIphone6ScreenSize;

/** Determine if the current device has the screen size of an iPhone 6 plus.
 * @return Returns YES if so, NO otherwise.
 */
- (BOOL)hasIphone6PlusScreenSize;

@end