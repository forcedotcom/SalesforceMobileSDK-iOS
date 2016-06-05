/*
 DeviceAppAttributes.m
 SalesforceAnalytics
 
 Created by Bharath Hariharan on 5/24/16.
 
 Copyright (c) 2016, salesforce.com, inc. All rights reserved.
 
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

#import "DeviceAppAttributes.h"

static NSString* const kSFAppVersionKey = @"appVersion";
static NSString* const kSFAppNameKey = @"appName";
static NSString* const kSFOsVersionKey = @"osVersion";
static NSString* const kSFOsNameKey = @"osName";
static NSString* const kSFNativeAppTypeKey = @"nativeAppType";
static NSString* const kSFMobileSdkVersionKey = @"mobileSdkVersion";
static NSString* const kSFDeviceModelKey = @"deviceModel";
static NSString* const kSFDeviceIdKey = @"deviceId";

@interface DeviceAppAttributes ()

@property (nonatomic, strong, readwrite) NSString *appVersion;
@property (nonatomic, strong, readwrite) NSString *appName;
@property (nonatomic, strong, readwrite) NSString *osVersion;
@property (nonatomic, strong, readwrite) NSString *osName;
@property (nonatomic, strong, readwrite) NSString *nativeAppType;
@property (nonatomic, strong, readwrite) NSString *mobileSdkVersion;
@property (nonatomic, strong, readwrite) NSString *deviceModel;
@property (nonatomic, strong, readwrite) NSString *deviceId;

@end

@implementation DeviceAppAttributes

- (id) init:(NSString *) appVersion appName:(NSString *) appName osVersion:(NSString *) osVersion
        osName:(NSString *) osName nativeAppType:(NSString *) nativeAppType
        mobileSdkVersion:(NSString *) mobileSdkVersion deviceModel:(NSString *) deviceModel
        deviceId:(NSString *) deviceId {
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
    }
    return self;
}

- (id) initWithJson:(NSData *) jsonRepresentation {
    self = [super init];
    if (self && jsonRepresentation) {
        NSError *error;
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:jsonRepresentation
                                                             options:NSJSONReadingAllowFragments
                                                               error:&error];
        if (dict) {
            self.appVersion = dict[kSFAppVersionKey];
            self.appName = dict[kSFAppNameKey];
            self.osVersion = dict[kSFOsVersionKey];
            self.osName = dict[kSFOsNameKey];
            self.nativeAppType = dict[kSFNativeAppTypeKey];
            self.mobileSdkVersion = dict[kSFMobileSdkVersionKey];
            self.deviceModel = dict[kSFDeviceModelKey];
            self.deviceId = dict[kSFDeviceIdKey];
        }
    }
    return self;
}

- (NSData *) jsonRepresentation {
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    dict[kSFAppVersionKey] = self.appVersion;
    dict[kSFAppNameKey] = self.appName;
    dict[kSFOsVersionKey] = self.osVersion;
    dict[kSFOsNameKey] = self.osName;
    dict[kSFNativeAppTypeKey] = self.nativeAppType;
    dict[kSFMobileSdkVersionKey] = self.mobileSdkVersion;
    dict[kSFDeviceModelKey] = self.deviceModel;
    dict[kSFDeviceIdKey] = self.deviceId;
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&error];
    return jsonData;
}

@end
