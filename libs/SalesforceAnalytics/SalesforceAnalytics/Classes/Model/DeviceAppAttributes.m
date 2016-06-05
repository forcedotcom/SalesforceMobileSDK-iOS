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

@implementation DeviceAppAttributes

- (id) init:(NSString *) appVersion appName:(NSString *) appName osVersion:(NSString *) osVersion
        osName:(NSString *) osName nativeAppType:(NSString *) nativeAppType
        mobileSdkVersion:(NSString *) mobileSdkVersion deviceModel:(NSString *) deviceModel
        deviceId:(NSString *) deviceId {
    self = [super init];
    if (self) {
        _appVersion = appVersion;
        _appName = appName;
        _osVersion = osVersion;
        _osName = osName;
        _nativeAppType = nativeAppType;
        _mobileSdkVersion = mobileSdkVersion;
        _deviceModel = deviceModel;
        _deviceId = deviceId;
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
            _appVersion = dict[kSFAppVersionKey];
            _appName = dict[kSFAppNameKey];
            _osVersion = dict[kSFOsVersionKey];
            _osName = dict[kSFOsNameKey];
            _nativeAppType = dict[kSFNativeAppTypeKey];
            _mobileSdkVersion = dict[kSFMobileSdkVersionKey];
            _deviceModel = dict[kSFDeviceModelKey];
            _deviceId = dict[kSFDeviceIdKey];
        }
    }
    return self;
}

- (NSData *) jsonRepresentation {
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    [dict setValue:self.appVersion forKey:kSFAppVersionKey];
    [dict setValue:self.appName forKey:kSFAppNameKey];
    [dict setValue:self.osVersion forKey:kSFOsVersionKey];
    [dict setValue:self.osName forKey:kSFOsNameKey];
    [dict setValue:self.nativeAppType forKey:kSFNativeAppTypeKey];
    [dict setValue:self.mobileSdkVersion forKey:kSFMobileSdkVersionKey];
    [dict setValue:self.deviceModel forKey:kSFDeviceModelKey];
    [dict setValue:self.deviceId forKey:kSFDeviceIdKey];
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&error];
    return jsonData;
}

@end
