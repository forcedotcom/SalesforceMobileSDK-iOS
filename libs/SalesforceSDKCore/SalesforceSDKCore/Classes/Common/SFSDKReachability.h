/*
     File: Reachability.h
 Abstract: Basic demonstration of how to use the SystemConfiguration Reachablity APIs.
  Version: 3.5
 
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 
 */

#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <netinet/in.h>

/*!
 * @typedef SFSDKReachabilityNetworkStatus
 * @abstract The different network statuses based on reachability.
 * @constant SFSDKReachabilityNotReachable The network is not reachable.
 * @constant SFSDKReachabilityReachableViaWiFi The network is reachable over WiFi.
 * @constant SFSDKReachabilityReachableViaWWAN The network is reachable over cellular.
 */
typedef enum {
	SFSDKReachabilityNotReachable = 0,
	SFSDKReachabilityReachableViaWiFi,
	SFSDKReachabilityReachableViaWWAN
} SFSDKReachabilityNetworkStatus;

/*!
 * @const kSFSDKReachabilityChangedNotification
 * @abstract String label for the reachability changed notification.
 */
extern NSString *kSFSDKReachabilityChangedNotification;

/*!
 * @class SFSDKReachability
 * @abstract Class used to determine network reachability status.
 */
@interface SFSDKReachability : NSObject

/*!
 * @brief Use to check the reachability of a given host name.
 * @param hostName The host name to check for reachability.
 * @return An instance of SFSDKReachability configured to reach the host name.
 */
+ (instancetype)reachabilityWithHostName:(NSString *)hostName;

/*!
 * @brief Use to check the reachability of a given IP address.
 * @param hostAddress The IP address of the host to check for reachability.
 * @return An instance of SFSDKReachability configured to reach the IP address.
 */
+ (instancetype)reachabilityWithAddress:(const struct sockaddr_in *)hostAddress;

/*!
 * @brief Checks whether the default route is available.
 * @discussion Should be used by applications that do not connect to a particular host.
 * @return An instance of SFSDKReachability configured to reach the network via the default route.
 */
+ (instancetype)reachabilityForInternetConnection;

/*!
 * @brief Checks whether a local WiFi connection is available.
 * @return An instance of SFSDKReachability configured to reach the network via WiFi.
 */
+ (instancetype)reachabilityForLocalWiFi;

/*!
 * @brief Start listening for reachability notifications on the current run loop.
 * @return YES if starting the notifier was successful, NO otherwise.
 */
- (BOOL)startNotifier;

/*!
 * @brief Stops listening for notifications.
 */
- (void)stopNotifier;

/*!
 * @brief The current reachability status.
 * @return SFSDKReachabilityNetworkStatus representing the current reachability status.
 */
- (SFSDKReachabilityNetworkStatus)currentReachabilityStatus;

/*!
 * @brief Determines whether a connection is required for network access.
 * @discussion WWAN may be available, but not active until a connection has been established. WiFi may require a connection for VPN on Demand.
 * @return YES if further network connections are required, NO otherwise.
 */
- (BOOL)connectionRequired;

@end


