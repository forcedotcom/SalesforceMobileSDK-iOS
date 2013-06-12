//
//  SFInactivityTimerCenter.h
//  SalesforceCommonUtils
//
//  Created by Amol Prabhu on 9/24/12.
//  Copyright (c) 2012 Salesforce.com. All rights reserved.
//

/**
 This class manages manages the inactivity timer.
 */

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
