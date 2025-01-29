/*
 Erica Sadun, http://ericasadun.com
 iPhone Developer's Cookbook, 6.x Edition
 BSD License, Use at your own risk
 */

#import <UIKit/UIKit.h>
#import <SalesforceSDKCore/SalesforceSDKConstants.h>

#define IFPGA_NAMESTRING                @"iFPGA"

// Supported iPhones
#define IPHONE_SE_2G_NAMESTRING         @"iPhone SE (2nd generation)"
#define IPHONE_SE_3G_NAMESTRING         @"iPhone SE (3rd generation)"
#define IPHONE_XS_NAMESTRING            @"iPhone XS"
#define IPHONE_XSMAX_NAMESTRING         @"iPhone XS Max"
#define IPHONE_XR_NAMESTRING            @"iPhone XR"
#define IPHONE_11_NAMESTRING            @"iPhone 11"
#define IPHONE_11_PRO_NAMESTRING        @"iPhone 11 Pro"
#define IPHONE_11_PRO_MAX_NAMESTRING    @"iPhone 11 Pro Max"
#define IPHONE_12_MINI_NAMESTRING       @"iPhone 12 Mini"
#define IPHONE_12_NAMESTRING            @"iPhone 12"
#define IPHONE_12_PRO_NAMESTRING        @"iPhone 12 Pro"
#define IPHONE_12_PRO_MAX_NAMESTRING    @"iPhone 12 Pro Max"
#define IPHONE_13_MINI_NAMESTRING       @"iPhone 13 Mini"
#define IPHONE_13_NAMESTRING            @"iPhone 13"
#define IPHONE_13_PRO_NAMESTRING        @"iPhone 13 Pro"
#define IPHONE_13_PRO_MAX_NAMESTRING    @"iPhone 13 Pro Max"
#define IPHONE_14_NAMESTRING            @"iPhone 14"
#define IPHONE_14_PLUS_NAMESTRING       @"iPhone 14 Plus"
#define IPHONE_14_PRO_NAMESTRING        @"iPhone 14 Pro"
#define IPHONE_14_PRO_MAX_NAMESTRING    @"iPhone 14 Pro Max"
#define IPHONE_15_NAMESTRING            @"iPhone 15"
#define IPHONE_15_PLUS_NAMESTRING       @"iPhone 15 Plus"
#define IPHONE_15_PRO_NAMESTRING        @"iPhone 15 Pro"
#define IPHONE_15_PRO_MAX_NAMESTRING    @"iPhone 15 Pro Max"
#define IPHONE_16_PRO_NAMESTRING        @"iPhone 16 Pro"
#define IPHONE_16_PRO_MAX_NAMESTRING    @"iPhone 16 Pro Max"
#define IPHONE_16_NAMESTRING            @"iPhone 16"
#define IPHONE_16_PLUS_NAMESTRING       @"iPhone 16 Plus"

#define IPHONE_UNKNOWN_NAMESTRING       @"Unknown iPhone"

// Supported iPads
#define IPAD_MINI_5G_NAMESTRING         @"iPad mini (5th generation)"
#define IPAD_MINI_6G_NAMESTRING         @"iPad mini (6th generation)"
#define IPAD_MINI_7G_NAMESTRING         @"iPad mini 7th Gen"
#define IPAD_AIR_3G_NAMESTRING          @"iPad Air (3rd generation)"
#define IPAD_AIR_4G_NAMESTRING          @"iPad Air (4th generation)"
#define IPAD_AIR_5G_NAMESTRING          @"iPad Air (5th generation)"
#define IPAD_AIR_6G_NAMESTRING          @"iPad Air 6th Gen"
#define IPAD_AIR_7G_NAMESTRING          @"iPad Air 7th Gen"
#define IPAD_7G_NAMESTRING              @"iPad (7th generation)"
#define IPAD_8G_NAMESTRING              @"iPad (8th generation)"
#define IPAD_9G_NAMESTRING              @"iPad (9th generation)"
#define IPAD_10G_NAMESTRING             @"iPad (10th generation)"
#define IPAD_PRO_11_2G_NAMESTRING       @"iPad Pro (11-inch, 2nd generation)"
#define IPAD_PRO_11_3G_NAMESTRING       @"iPad Pro (11-inch, 3rd generation)"
#define IPAD_PRO_11_4G_NAMESTRING       @"iPad Pro (11-inch, 4th generation)"
#define IPAD_PRO_12_9_3G_NAMESTRING     @"iPad Pro (12.9-inch, 3rd generation)"
#define IPAD_PRO_12_9_4G_NAMESTRING     @"iPad Pro (12.9-inch, 4th generation)"
#define IPAD_PRO_12_9_5G_NAMESTRING     @"iPad Pro (12.9-inch, 5th generation)"
#define IPAD_PRO_12_9_6G_NAMESTRING     @"iPad Pro (12.9-inch, 6th generation)"
#define IPAD_PRO_11_5G_NAMESTRING       @"iPad Pro 11 inch 5th Gen"
#define IPAD_PRO_12_7G_NAMESTRING       @"iPad Pro 12.9 inch 7th Gen"

#define IPAD_UNKNOWN_NAMESTRING         @"Unknown iPad"

// Supported Apple TVs
#define APPLETV_4G_NAMESTRING           @"Apple TV HD"
#define APPLETV_4K_NAMESTRING           @"Apple TV 4K (1st generation)"
#define APPLETV_4K_2G_NAMESTRING        @"Apple TV 4K (2nd generation)"
#define APPLETV_4K_3G_NAMESTRING        @"Apple TV 4K (3rd generation)"

#define APPLETV_UNKNOWN_NAMESTRING      @"Unknown Apple TV"

// Simulator
#define SIMULATOR_NAMESTRING            @"iPhone Simulator"
#define SIMULATOR_IPHONE_NAMESTRING     @"iPhone Simulator"
#define SIMULATOR_IPAD_NAMESTRING       @"iPad Simulator"
#define SIMULATOR_APPLETV_NAMESTRING    @"Apple TV Simulator"

// Unknown
#define IOS_FAMILY_UNKNOWN_DEVICE       @"Unknown iOS device"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, UIDevicePlatform) {
    UIDeviceUnknown,
    
    UIDeviceIFPGA,
    
    UIDeviceSimulator,
    UIDeviceSimulatoriPhone,
    UIDeviceSimulatoriPad,
    UIDeviceSimulatorAppleTV,
    
    // Supported iPhones (A12 Bionic and newer)
    UIDeviceSE2iPhone,            // iPhone SE (2nd generation)
    UIDeviceSE3iPhone,            // iPhone SE (3rd generation)
    UIDeviceXRiPhone,             // iPhone XR
    UIDeviceXsiPhone,             // iPhone XS
    UIDeviceXsMaxiPhone,          // iPhone XS Max
    UIDevice11iPhone,             // iPhone 11
    UIDevice11ProiPhone,          // iPhone 11 Pro
    UIDevice11ProMaxiPhone,       // iPhone 11 Pro Max
    UIDevice12MiniiPhone,         // iPhone 12 Mini
    UIDevice12iPhone,             // iPhone 12
    UIDevice12ProiPhone,          // iPhone 12 Pro
    UIDevice12ProMaxiPhone,       // iPhone 12 Pro Max
    UIDevice13MiniiPhone,         // iPhone 13 Mini
    UIDevice13iPhone,             // iPhone 13
    UIDevice13ProiPhone,          // iPhone 13 Pro
    UIDevice13ProMaxiPhone,       // iPhone 13 Pro Max
    UIDevice14iPhone,             // iPhone 14
    UIDevice14PlusiPhone,         // iPhone 14 Plus
    UIDevice14ProiPhone,          // iPhone 14 Pro
    UIDevice14ProMaxiPhone,       // iPhone 14 Pro Max
    UIDevice15iPhone,             // iPhone 15
    UIDevice15PlusiPhone,         // iPhone 15 Plus
    UIDevice15ProiPhone,          // iPhone 15 Pro
    UIDevice15ProMaxiPhone,       // iPhone 15 Pro Max
    UIDevice16ProiPhone,          // iPhone 16 Pro
    UIDevice16ProMaxiPhone,       // iPhone 16 Pro Max
    UIDevice16iPhone,             // iPhone 16
    UIDevice16PlusiPhone,         // iPhone 16 Plus
    
    // Supported iPads (A12 Bionic and newer)
    UIDevice5GiPadMini,           // iPad mini (5th generation)
    UIDevice6GiPadMini,           // iPad mini (6th generation)
    UIDevice3GiPadAir,            // iPad Air (3rd generation)
    UIDevice4GiPadAir,            // iPad Air (4th generation)
    UIDevice5GiPadAir,            // iPad Air (5th generation)
    UIDevice7GiPad,               // iPad (7th generation)
    UIDevice8GiPad,               // iPad (8th generation)
    UIDevice9GiPad,               // iPad (9th generation)
    UIDevice10GiPad,              // iPad (10th generation)
    UIDeviceM1iPadPro129Inch,     // iPad Pro (12.9-inch, M1)
    UIDevice3G129InchiPadPro,     // iPad Pro (12.9-inch, 3rd generation)
    UIDevice4G129InchiPadPro,     // iPad Pro (12.9-inch, 4th generation)
    UIDevice5G129InchiPadPro,     // iPad Pro (12.9-inch, 5th generation)
    UIDevice6G129InchiPadPro,     // iPad Pro (12.9-inch, 6th generation, M2)
    UIDevice11InchiPadPro,        // iPad Pro (11-inch, 1st gen)
    UIDevice11Inch2GiPadPro,      // iPad Pro (11-inch, 2nd generation)
    UIDevice11Inch3GiPadPro,      // iPad Pro (11-inch, 3rd generation, M1)
    UIDevice11Inch4GiPadPro,      // iPad Pro (11-inch, 4th generation, M2)
    UIDevice6GiPadAir,            // iPad Air 6th Gen
    UIDevice7GiPadAir,            //iPad Air 7th Gen
    UIDevice7GiPadMini,           //iPad mini 7th Gen
    UIDevice11Inch5GiPadPro,      //iPad Pro 11 inch 5th Gen
    UIDevice12Inch7GiPadPro,      //iPad Pro 12.9 inch 7th Gen
    
    // Supported Apple TVs
    UIDeviceAppleTV4,             // Apple TV HD
    UIDeviceAppleTV4k,            // Apple TV 4K (1st generation)
    UIDeviceAppleTV4k2G,          // Apple TV 4K (2nd generation)
    UIDeviceAppleTV4k3G,          // Apple TV 4K (3rd generation)
    
    UIDeviceUnknowniPhone,
    UIDeviceUnknowniPad,
    UIDeviceUnknownAppleTV
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
- (nullable NSString *)sfsdk_platform;

/**Platform type
 See `UIDevicePlatform`
 */
- (UIDevicePlatform)sfsdk_platformType;

/**Returns the system-dependent version number.
 @return The system version number.
 */
- (double)sfsdk_systemVersionNumber;

/**Platform string
 
 Valid values are defined above in the IPHONE_XX_NAMESTRING and IPAD_XXX_NAMESTRING
 */
- (NSString *)sfsdk_platformString;

/**Total memory*/
- (NSUInteger)sfsdk_totalMemory;

/**User Memory*/
- (NSUInteger)sfsdk_userMemory;

/**Memory used by application (in bytes)*/
- (NSUInteger)sfsdk_applicationMemory;

/**Free VM page space available to application (in bytes)*/
- (NSUInteger)sfsdk_freeMemory;

/**Total disk space*/
- (NSNumber *)sfsdk_totalDiskSpace;

/**Total free space*/
- (NSNumber *)sfsdk_freeDiskSpace;

/**Returns whether the device's SOC has a neural engine for core ML tasks*/
- (BOOL)sfsdk_hasNeuralEngine;

/**Device Family*/
- (UIDeviceFamily)sfsdk_deviceFamily;

/**Device's current orientation
 This method will first try to retrieve orientation using UIDevice currentOrientation, if return value is an invalid orientation, it will try to use the orientation of the first window scene
 */
- (UIInterfaceOrientation)sfsdk_interfaceOrientation API_UNAVAILABLE(visionos);

/**
 *  Determine if current device is simulator or not
 *
 *  @return Return YES if current device is simulator, NO otherwise.
 */
- (BOOL)sfsdk_isSimulator;

/**Return YES if device is iPad
 */
+ (BOOL)sfsdk_currentDeviceIsIPad;

/**Return YES if device is iPhone
 */
+ (BOOL)sfsdk_currentDeviceIsIPhone;

@end

NS_ASSUME_NONNULL_END
