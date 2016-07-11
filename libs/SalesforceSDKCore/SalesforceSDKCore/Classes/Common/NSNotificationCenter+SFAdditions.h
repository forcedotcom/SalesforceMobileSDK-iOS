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

#import <Foundation/Foundation.h>

// Constant for notifying of app exit or abort.
static NSString * const SFApplicationWillAbortOrExitNotification = @"ApplicationWillAbortOrExit";

/** Posts notifications either once with a run loop, or on the main thread.
 */
@interface NSNotificationCenter (SFAdditions)

/**
 Posts a notification once within a runloop - coalescing on the name.
 @param notificationName The name of the notification.
 @param object The object for the new notification.
 @param userInfo The user information dictionary for the new notification. May be nil.
 */
+ (void)postNotificationOnceWithName:(NSString*)notificationName object:(id)object userInfo:(NSDictionary*)userInfo;

/**
 Posts a notification on the main thread.
 @param notificationName The name of the notification.
 @param object The object for the new notificaiton.
 @param userInfo The user information dictionary for the new notification. May be nil.
 */
- (void)postNotificationOnMainThreadWithName:(NSString *)notificationName object:(id)object userInfo:(NSDictionary *)userInfo;

@end
