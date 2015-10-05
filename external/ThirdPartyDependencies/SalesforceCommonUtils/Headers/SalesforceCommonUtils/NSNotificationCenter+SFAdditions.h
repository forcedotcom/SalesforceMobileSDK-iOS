//
//  NSNotificationCenter+SFAdditions.h
//  SalesforceCommonUtils
//
//  Created by Riley Crebs on 4/13/15.
//  Copyright (c) 2015 Salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSNotificationCenter (SFAdditions)

/**
 Posts a notification once within a runloop - coalescing on the name.
 @param notificationName The name of the notification
 @param object The object for the new notificaiton
 @param userInfo The user information dictionary for the new notification. May be nil.
 */
+ (void)postNotificationOnceWithName:(NSString*)notificationName object:(id)object userInfo:(NSDictionary*)userInfo;

/**
 Posts a notification on the main thread
 @param notificationName The name of the notification
 @param object The object for the new notificaiton
 @param userInfo The user information dictionary for the new notification. May be nil.
 */
- (void)postNotificationOnMainThreadWithName:(NSString *)notificationName object:(id)object userInfo:(NSDictionary *)userInfo;

@end
