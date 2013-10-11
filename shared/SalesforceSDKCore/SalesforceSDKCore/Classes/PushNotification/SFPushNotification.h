/*
 Copyright (c) 2013, salesforce.com, inc. All rights reserved.
 
 Redistribution and use of this software in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright notice, this list of conditions
 and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of
 conditions and the following disclaimer in the documentation and/or other materials provided
 with the distribution.
 * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
 endorse or promote products derived from this software without specific prior written
 permission of salesforce.com, inc.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
 FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
 WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIApplication.h>


@interface SFPushNotification : NSObject

@property (nonatomic, strong) NSData* PNSToken;
@property (nonatomic, strong) NSString* pushObjectEntity;

+ (SFPushNotification *) sharedInstance;

/**
 * Registers the application for remote notifications with apple for the given notification types.
 * This should be called from the application's didFinishLaunching method.
 * @param types UIRemoteNotificationType that defines the type of notifications to register for.
 */
- (void)registerForRemoteNotificationTypes:(UIRemoteNotificationType)types;
/**
 * Registers for Notifications with the SFDC servers. This should be called after successful registeration with Apple.
 * It uses the DeviceToken received from Apple (PNSToken). On successful registeration with SFDC, the pushObjectEntity is populated.
 * @return YES for successful registration call made.
 */
- (BOOL)registerForSFDCNotifications;
/**
 * Unregisters for Notifications with the SFDC servers. This should be done when the user logs out.
 * @return YES for successful unregistration call being made.
 */
- (BOOL)unregisterSFDCNotifications;

@end
