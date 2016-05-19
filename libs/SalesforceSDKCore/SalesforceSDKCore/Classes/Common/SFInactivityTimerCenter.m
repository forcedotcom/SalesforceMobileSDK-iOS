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

#import "SFInactivityTimerCenter.h"
#import "SFLogger.h"

@implementation SFInactivityTimerCenter

static NSString *const kDefaultKeyLastActivity = @"timer.lastactivity";
static NSMutableDictionary *allTimers = nil;
static NSMutableDictionary *allIntervals = nil;
static NSDate *lastActivityTimestamp = nil;

+ (void)initialize {
    if (self == [SFInactivityTimerCenter class]) {
        lastActivityTimestamp = [[NSUserDefaults standardUserDefaults] objectForKey:kDefaultKeyLastActivity];
        if(!lastActivityTimestamp) {
            lastActivityTimestamp = [[NSDate alloc] init];
        }
    }
}

+ (void)registerTimer:(NSString *)timerName target:(id)target selector:(SEL)aSelector timerInterval:(NSTimeInterval)interval {
	[SFInactivityTimerCenter removeTimer:timerName];
	if (interval > 0) {
		NSTimer *t = [NSTimer timerWithTimeInterval:interval target:target selector:aSelector userInfo:timerName repeats:NO];
		[[NSRunLoop mainRunLoop] addTimer:t forMode:NSDefaultRunLoopMode];
		if (!allTimers)
			allTimers = [[NSMutableDictionary alloc] init];
		if (!allIntervals)
			allIntervals = [[NSMutableDictionary alloc] init];
		[allTimers setObject:t forKey:timerName];
		[allIntervals setObject:@(interval) forKey:timerName];
	}
}

+ (void)removeTimer:(NSString *)timerName {
	NSTimer *t = [allTimers objectForKey:timerName];
	[t invalidate];
	[allTimers removeObjectForKey:timerName];
	[allIntervals removeObjectForKey:timerName];
}

+ (void)removeAllTimers {
	for (NSTimer *t in [allTimers allValues]) {
		[t invalidate];
	}
	[allTimers removeAllObjects];
	[allIntervals removeAllObjects];
}

+ (void)updateActivityTimestamp {
    [self updateActivityTimestampTo:[NSDate date]];
}

+ (void)updateActivityTimestampTo:(NSDate *)date {
    lastActivityTimestamp  = [date copy];
    NSMutableArray *keysToRemove = [NSMutableArray array];
    for (NSString *timerName in allTimers) {
        NSTimer *t = [allTimers objectForKey:timerName];
        NSNumber *interval = [allIntervals objectForKey:timerName];
        if (t.valid) {
            [t setFireDate:[[NSDate date] dateByAddingTimeInterval:[interval doubleValue]]];
            [self log:SFLogLevelDebug format:@"timer %@ updated to +%@ seconds", timerName, interval];
        } else {
            [self log:SFLogLevelError format:@"timer %@ is invalid. removing...", timerName];
            [keysToRemove addObject:timerName];
        }
    }
    [allTimers removeObjectsForKeys:keysToRemove];
    [allIntervals removeObjectsForKeys:keysToRemove];
}

+ (void)saveActivityTimestamp {
	[[NSUserDefaults standardUserDefaults] setObject:lastActivityTimestamp forKey:kDefaultKeyLastActivity];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (NSDate *)lastActivityTimestamp {
	return lastActivityTimestamp;
}

@end
