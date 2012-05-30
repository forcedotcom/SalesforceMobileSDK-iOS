/*
 Copyright (c) 2012, salesforce.com, inc. All rights reserved.
 
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

extern NSString *const kDefaultKeyLastActivity;

/**
 * Class for managing timers that monitor user activity.
 */
@interface SFInactivityTimerCenter : NSObject

/*!
 * Register a timer.
 * @param timerName The key/name associated with the timer.
 * @param target The target object to be called when the timer fires.
 * @param aSelector The selector on the target object to call when the timer fires.
 * @param interval The amount of inactive time before the timer will fire.
 */
+ (void)registerTimer:(NSString *)timerName target:(id)target selector:(SEL)aSelector timerInterval:(NSTimeInterval)interval;

/*!
 * Remove a specific timer from monitoring.
 * @param timerName the key/name used to register the timer.
 */
+ (void)removeTimer:(NSString *)timerName;

/*!
 * Remove all timers from monitoring.
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
