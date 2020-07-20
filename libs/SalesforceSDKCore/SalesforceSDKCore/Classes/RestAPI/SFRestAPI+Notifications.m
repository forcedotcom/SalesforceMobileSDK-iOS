//
//  SFRestAPI+Notifications.m
//  SalesforceSDKCore
//
//  Created by Brianna Birman on 4/7/20.
//  Copyright (c) 2020-present, salesforce.com, inc. All rights reserved.
// 
//  Redistribution and use of this software in source and binary forms, with or without modification,
//  are permitted provided that the following conditions are met:
//  * Redistributions of source code must retain the above copyright notice, this list of conditions
//  and the following disclaimer.
//  * Redistributions in binary form must reproduce the above copyright notice, this list of
//  conditions and the following disclaimer in the documentation and/or other materials provided
//  with the distribution.
//  * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
//  endorse or promote products derived from this software without specific prior written
//  permission of salesforce.com, inc.
// 
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
//  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
//  FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
//  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
//  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
//  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
//  WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import "SFRestAPI+Notifications.h"
#import "SFRestAPI+Internal.h"
#import "SFFormatUtils.h"

@implementation SFRestAPI(Notifications)

- (SFRestRequest *)requestForNotificationsStatus:(NSString *)apiVersion {
    NSString *path = [NSString stringWithFormat:@"/%@/connect/notifications/status", [self computeAPIVersion:apiVersion]];
    return [SFRestRequest requestWithMethod:SFRestMethodGET path:path queryParams:nil];
}

- (SFRestRequest *)requestForNotification:(NSString *)notificationId apiVersion:(NSString *)apiVersion {
    NSString *path = [NSString stringWithFormat:@"/%@/connect/notifications/%@", [self computeAPIVersion:apiVersion], notificationId];
    return [SFRestRequest requestWithMethod:SFRestMethodGET path:path queryParams:nil];
}

@end


@interface SFSDKFetchNotificationsRequestBuilder()
@property (nonatomic, strong, readwrite) NSMutableDictionary *parameters;
@end

@implementation SFSDKFetchNotificationsRequestBuilder

- (instancetype)init {
    if (self = [super init]) {
        _parameters = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (SFSDKFetchNotificationsRequestBuilder *)setAfter:(NSDate *)date {
    self.parameters[@"after"] = [SFFormatUtils getIsoStringFromDate:date];
    return self;
}

- (SFSDKFetchNotificationsRequestBuilder *)setBefore:(NSDate *)date {
    self.parameters[@"before"] = [SFFormatUtils getIsoStringFromDate:date];
    return self;
}

- (SFSDKFetchNotificationsRequestBuilder *)setSize:(NSUInteger)size {
    self.parameters[@"size"] = [@(size) stringValue];
    return self;
}

- (SFRestRequest *)buildFetchNotificationsRequest:(NSString *)apiVersion {
    NSString *path = [NSString stringWithFormat:@"/%@/connect/notifications", apiVersion];
    SFRestRequest *request = [SFRestRequest requestWithMethod:SFRestMethodGET path:path queryParams:self.parameters];
    return request;
}

@end


@interface SFSDKUpdateNotificationsRequestBuilder()
@property (nonatomic, strong, readwrite) NSMutableDictionary *parameters;
@property (nonatomic, strong) NSString *notifId;
@end

@implementation SFSDKUpdateNotificationsRequestBuilder

- (instancetype)init {
    if (self = [super init]) {
        _parameters = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (SFSDKUpdateNotificationsRequestBuilder *)setNotificationId:(NSString *)notificationId {
    self.notifId = notificationId;
    return self;
    
}
- (SFSDKUpdateNotificationsRequestBuilder *)setNotificationIds:(NSArray<NSString *> *)notificationIds {
    self.parameters[@"notificationIds"] = notificationIds;
    return self;
}

- (SFSDKUpdateNotificationsRequestBuilder *)setBefore:(NSDate *)date {
    self.parameters[@"before"] = [SFFormatUtils getIsoStringFromDate:date];
    return self;
}

- (SFSDKUpdateNotificationsRequestBuilder *)setSeen:(BOOL)seen {
    self.parameters[@"seen"] = seen ? @"true" : @"false";
    return self;
}

- (SFSDKUpdateNotificationsRequestBuilder *)setRead:(BOOL)read {
    self.parameters[@"read"] = read ? @"true" : @"false";
    return self;
}

- (SFRestRequest *)buildUpdateNotificationsRequest:(NSString *)apiVersion {
    NSString *path;
    if (self.notifId) {
        path = [NSString stringWithFormat:@"/%@/connect/notifications/%@", apiVersion, self.notifId];
    } else {
        path = [NSString stringWithFormat:@"/%@/connect/notifications", apiVersion];
    }

    SFRestRequest *request = [SFRestRequest requestWithMethod:SFRestMethodPATCH path:path queryParams:nil];
    [request setCustomRequestBodyDictionary:self.parameters contentType:@"application/json"];
    return request;
}

@end
