/*
 DeviceAppAttributes.m
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

#import "SFSDKDeviceAppAttributes.h"

static NSString* const kSFAppVersionKey = @"appVersion";
static NSString* const kSFAppNameKey = @"appName";
static NSString* const kSFOsVersionKey = @"osVersion";
static NSString* const kSFOsNameKey = @"osName";
static NSString* const kSFNativeAppTypeKey = @"nativeAppType";
static NSString* const kSFMobileSdkVersionKey = @"mobileSdkVersion";
static NSString* const kSFDeviceModelKey = @"deviceModel";
static NSString* const kSFDeviceIdKey = @"deviceId";
static NSString* const kSFClientIdKey = @"clientId";

@interface SFSDKDeviceAppAttributes ()

@property (nonatomic, strong, readwrite) NSString *appVersion;
@property (nonatomic, strong, readwrite) NSString *appName;
@property (nonatomic, strong, readwrite) NSString *osVersion;
@property (nonatomic, strong, readwrite) NSString *osName;
@property (nonatomic, strong, readwrite) NSString *nativeAppType;
@property (nonatomic, strong, readwrite) NSString *mobileSdkVersion;
@property (nonatomic, strong, readwrite) NSString *deviceModel;
@property (nonatomic, strong, readwrite) NSString *deviceId;
@property (nonatomic, strong, readwrite) NSString *clientId;

@end

@implementation SFSDKDeviceAppAttributes

- (instancetype) initWithAppVersion:(NSString *) appVersion appName:(NSString *) appName osVersion:(NSString *) osVersion
        osName:(NSString *) osName nativeAppType:(NSString *) nativeAppType
        mobileSdkVersion:(NSString *) mobileSdkVersion deviceModel:(NSString *) deviceModel
        deviceId:(NSString *) deviceId clientId:(NSString *) clientId {
    self = [super init];
    if (self) {
        self.appVersion = appVersion;
        self.appName = appName;
        self.osVersion = osVersion;
        self.osName = osName;
        self.nativeAppType = nativeAppType;
        self.mobileSdkVersion = mobileSdkVersion;
        self.deviceModel = deviceModel;
        self.deviceId = deviceId;
        self.clientId = clientId;
    }
    return self;
}

- (instancetype) initWithJson:(NSDictionary *) jsonRepresentation {
    self = [super init];
    if (self && jsonRepresentation) {
        self.appVersion = jsonRepresentation[kSFAppVersionKey];
        self.appName = jsonRepresentation[kSFAppNameKey];
        self.osVersion = jsonRepresentation[kSFOsVersionKey];
        self.osName = jsonRepresentation[kSFOsNameKey];
        self.nativeAppType = jsonRepresentation[kSFNativeAppTypeKey];
        self.mobileSdkVersion = jsonRepresentation[kSFMobileSdkVersionKey];
        self.deviceModel = jsonRepresentation[kSFDeviceModelKey];
        self.deviceId = jsonRepresentation[kSFDeviceIdKey];
        self.clientId = jsonRepresentation[kSFClientIdKey];
    }
    return self;
}

- (NSDictionary *) jsonRepresentation {
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    dict[kSFAppVersionKey] = self.appVersion;
    dict[kSFAppNameKey] = self.appName;
    dict[kSFOsVersionKey] = self.osVersion;
    dict[kSFOsNameKey] = self.osName;
    dict[kSFNativeAppTypeKey] = self.nativeAppType;
    dict[kSFMobileSdkVersionKey] = self.mobileSdkVersion;
    dict[kSFDeviceModelKey] = self.deviceModel;
    dict[kSFDeviceIdKey] = self.deviceId;
    dict[kSFClientIdKey] = self.clientId;
    return dict;
}

@end
