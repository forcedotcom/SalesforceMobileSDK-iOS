/*
 Copyright (c) 2015, salesforce.com, inc. All rights reserved.
 
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

/**
 This class manages manages the inactivity timer. See NSTimer in the Objective-C documentation for more details.
 */

#import <Foundation/Foundation.h>

@interface SFInactivityTimerCenter : NSObject

/*!
 * Register the timer.
 @param timerName Name to use to register the timer.
 @param target The object to which to send the message specified by aSelector when the timer fires. See NSTimer documentation.
 @param aSelector The message to send to target when the timer fires. See NSTimer documentation.
 @param interval For a repeating timer, this parameter contains the number of seconds between firings of the timer. See NSTimer documentation.
 */
+ (void)registerTimer:(NSString *)timerName target:(id)target selector:(SEL)aSelector timerInterval:(NSTimeInterval)interval;

/*!
 * Remove a specific timer.
 @param timerName Name of the timer to remove.
 */
+ (void)removeTimer:(NSString *)timerName;

/*!
 * Remove all timers.
 */
+ (void)removeAllTimers;

/*!
 * Update last activity timestamp to current time.
 */
+ (void)updateActivityTimestamp;

/*!
 * Update last activity timestamp to specified time.
 @param date The NSDate object that specifies the new timestamp.
 */
+ (void)updateActivityTimestampTo:(NSDate *)date;

/*!
 * Return the timestamp for the latest activity.
 */
+ (NSDate *)lastActivityTimestamp;

/*!
 * Save the activity timestamp to persistant storage.
 */
+ (void)saveActivityTimestamp;

@end
