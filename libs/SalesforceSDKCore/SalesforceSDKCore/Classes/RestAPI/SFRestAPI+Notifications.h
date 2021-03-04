//
//  SFRestAPI+Notifications.h
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

#import <Foundation/Foundation.h>
#import <SalesforceSDKCore/SFRestAPI.h>

NS_ASSUME_NONNULL_BEGIN

@interface SFRestAPI(Notifications)

/**
 * Returns a request to fetch the status of notifications, including unread and unseen count.
 * @param apiVersion API version.
 * @see https://developer.salesforce.com/docs/atlas.en-us.chatterapi.meta/chatterapi/connect_resources_notifications_status.htm
 */
- (SFRestRequest *)requestForNotificationsStatus:(NSString *)apiVersion;

/**
 * Returns a request to fetch the given notification.
 * @param notificationId ID of notification to fetch.
 * @param apiVersion API version.
 * @see https://developer.salesforce.com/docs/atlas.en-us.chatterapi.meta/chatterapi/connect_resource_notifications_specific.htm
 */
- (SFRestRequest *)requestForNotification:(NSString *)notificationId apiVersion:(NSString *)apiVersion;
@end

/**
 * Use this interface to create a RestRequest object that calls the Notifications REST API.
 * @see https://developer.salesforce.com/docs/atlas.en-us.chatterapi.meta/chatterapi/connect_resources_notifications_list.htm
 */
NS_SWIFT_NAME(FetchNotificationsRequestBuilder)
@interface SFSDKFetchNotificationsRequestBuilder: NSObject

/**
 * Sets the number of notifications to fetch. Max and default are 20.
 * @param size Number of notifications to fetch.
 */
- (SFSDKFetchNotificationsRequestBuilder *)setSize:(NSUInteger)size;

/**
 * Notifications occurring before the provided date will be fetched. Shouldn't be used with `setAfter`.
 * @param date Before date. If unspecified, defaults to current date and time.
 */
- (SFSDKFetchNotificationsRequestBuilder *)setBefore:(NSDate *)date;

/**
 * Notifications occurring after the provided date will be fetched. Shouldn't be used with `setBefore`.
 * @param date After date.
 */
- (SFSDKFetchNotificationsRequestBuilder *)setAfter:(NSDate *)date;

/**
 * Returns a request to fetch notifications based on values from the builder.
 * @param apiVersion API version.
 */
- (SFRestRequest *)buildFetchNotificationsRequest:(NSString *)apiVersion;

@end

/**
 * Use this interface to create a PATCH RestRequest object that calls the Notifications REST API.
 * @see https://developer.salesforce.com/docs/atlas.en-us.chatterapi.meta/chatterapi/connect_resources_notifications_list.htm
 * @see https://developer.salesforce.com/docs/atlas.en-us.chatterapi.meta/chatterapi/connect_resource_notifications_specific.htm
 */
NS_SWIFT_NAME(UpdateNotificationsRequestBuilder)
@interface SFSDKUpdateNotificationsRequestBuilder: NSObject

/**
 * Sets the notification to update. Shouldn't be used with `setNotificationIds` or `setBefore`.
 * @param notificationId ID of notification to update.
 */
- (SFSDKUpdateNotificationsRequestBuilder *)setNotificationId:(NSString *)notificationId;

/**
 * Sets a list of notifications to update (max 50). Shouldn't be used with `setNotificationId` or `setBefore`.
 * @param notificationIds Array of notifications IDs to update.
 */
- (SFSDKUpdateNotificationsRequestBuilder *)setNotificationIds:(NSArray<NSString *> *)notificationIds;

/**
 * Notifications occurring before the provided date will be updated. Shouldn't be used with `setNotificationId` or `setNotificationIds`.
 * @param date Before date. If unspecified, defaults to current date and time.
 */
- (SFSDKUpdateNotificationsRequestBuilder *)setBefore:(NSDate *)date;

/**
 * Marks the notification(s) as seen (true) or unseen (false)
 * @param seen If the notification is seen or not.
 */
- (SFSDKUpdateNotificationsRequestBuilder *)setSeen:(BOOL)seen;

/**
 * Marks the notification(s) as read (true) or unread (false)
 * @param read If the notification is read or not.
 */
- (SFSDKUpdateNotificationsRequestBuilder *)setRead:(BOOL)read;

/**
 * Returns a request to update notifications based on values from the builder.
 * @param apiVersion API version.
 */
- (SFRestRequest *)buildUpdateNotificationsRequest:(NSString *)apiVersion;

@end

NS_ASSUME_NONNULL_END
