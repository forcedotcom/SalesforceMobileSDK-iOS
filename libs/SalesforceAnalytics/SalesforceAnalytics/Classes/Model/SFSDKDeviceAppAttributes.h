/*
 DeviceAppAttributes.h
 SalesforceAnalytics
 
 Created by Bharath Hariharan on 5/24/16.
 
 Copyright (c) 2016-present, salesforce.com, inc. All rights reserved.
 
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

@interface SFSDKDeviceAppAttributes : NSObject

@property (nonatomic, strong, readonly, nonnull) NSString *appVersion;
@property (nonatomic, strong, readonly, nonnull) NSString *appName;
@property (nonatomic, strong, readonly, nonnull) NSString *osVersion;
@property (nonatomic, strong, readonly, nonnull) NSString *osName;
@property (nonatomic, strong, readonly, nonnull) NSString *nativeAppType;
@property (nonatomic, strong, readonly, nonnull) NSString *mobileSdkVersion;
@property (nonatomic, strong, readonly, nonnull) NSString *deviceModel;
@property (nonatomic, strong, readonly, nonnull) NSString *deviceId;
@property (nonatomic, strong, readonly, nonnull) NSString *clientId;

/**
 * Parameterized initializer.
 *
 * @param appVersion App version.
 * @param appName App name.
 * @param osVersion OS version.
 * @param osName OS name.
 * @param nativeAppType Native app type.
 * @param mobileSdkVersion Mobile SDK version.
 * @param deviceModel Device model.
 * @param deviceId Device ID.
 * @param clientId Client ID.
 * @return Instance of this class.
 */
- (nonnull instancetype) initWithAppVersion:(nonnull NSString *) appVersion appName:(nonnull NSString *) appName osVersion:(nonnull NSString *) osVersion osName:(nonnull NSString *) osName nativeAppType:(nonnull NSString *) nativeAppType
    mobileSdkVersion:(nonnull NSString *) mobileSdkVersion deviceModel:(nonnull NSString *) deviceModel deviceId:(nonnull NSString *) deviceId clientId:(nonnull NSString *) clientId;

/**
 * Parameterized initializer.
 *
 * @param jsonRepresentation JSON representation.
 * @return Instance of this class.
 */
- (nonnull instancetype) initWithJson:(nonnull NSDictionary *) jsonRepresentation;

/**
 * Returns a JSON representation of device app attributes.
 *
 * @return JSON representation.
 */
- (nonnull NSDictionary *) jsonRepresentation;

@end
