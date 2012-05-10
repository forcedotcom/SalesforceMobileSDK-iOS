//
//  SFInactivityTimerCenter.h
//  SalesforceSDK
//
//  Created by Kevin Hawkins on 5/10/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString *const DEFAULT_KEY_LAST_ACTIVITY;

@interface SFInactivityTimerCenter : NSObject

/*!
 * Register the timer
 */
+ (void)registerTimer:(NSString *)timerName target:(id)target selector:(SEL)aSelector timerInterval:(NSTimeInterval)interval;

/*!
 * Remove a specific timer.
 */
+ (void)removeTimer:(NSString *)timerName;

/*!
 * Remove all timers.
 */
+ (void)removeAllTimers;

/*!
 * Update last activity timestamp.
 */
+ (void)updateActivityTimestamp;

/*!
 * Return the timestamp for the latest activity.
 */
+ (NSDate *)lastActivityTimestamp;

/*!
 * Save the activity timestamp to persistant storage.
 */
+ (void)saveActivityTimestamp;

@end
