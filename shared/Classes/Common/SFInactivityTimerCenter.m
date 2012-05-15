//
//  SFInactivityTimerCenter.m
//  SalesforceSDK
//
//  Created by Kevin Hawkins on 5/10/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "SFInactivityTimerCenter.h"
#import "SFLogger.h"

@implementation SFInactivityTimerCenter

static NSMutableDictionary *allTimers = nil;
static NSMutableDictionary *allIntervals = nil;
static NSDate *lastActivityTimestamp = nil;

+ (void)initialize {
    if (self == [SFInactivityTimerCenter class]) {
        lastActivityTimestamp = [[NSUserDefaults standardUserDefaults] objectForKey:DEFAULT_KEY_LAST_ACTIVITY];
        if(lastActivityTimestamp == nil) {
            lastActivityTimestamp = [[NSDate alloc] init];
        }
    }
}

+ (void)registerTimer:(NSString *)timerName target:(id)target selector:(SEL)aSelector timerInterval:(NSTimeInterval)interval {
	[SFInactivityTimerCenter removeTimer:timerName];
	if (interval > 0) {
		NSTimer *t = [NSTimer timerWithTimeInterval:interval target:target selector:aSelector userInfo:timerName repeats:NO];
		[[NSRunLoop mainRunLoop] addTimer:t forMode:NSDefaultRunLoopMode];
		if (allTimers == nil)
			allTimers = [[NSMutableDictionary alloc] init];
		if (allIntervals == nil)
			allIntervals = [[NSMutableDictionary alloc] init];
		[allTimers setObject:t forKey:timerName];
		[allIntervals setObject:[NSNumber numberWithDouble:interval] forKey:timerName];
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
	[lastActivityTimestamp release];
	lastActivityTimestamp  = [[NSDate alloc] init];
	NSMutableArray *keysToRemove = [NSMutableArray array];
	for (NSString *timerName in allTimers) {
		NSTimer *t = [allTimers objectForKey:timerName];
		NSNumber *interval = [allIntervals objectForKey:timerName];
		if ([t isValid]) {
            [t setFireDate:[[NSDate date] dateByAddingTimeInterval:[interval doubleValue]]];
            [self log:Info format:@"timer %@ updated to +%@ seconds", timerName, interval];
		} else {
            [self log:Error format:@"timer %@ is invalid. removing...", timerName];
			[keysToRemove addObject:timerName];
		}
	}
	[allTimers removeObjectsForKeys:keysToRemove];
	[allIntervals removeObjectsForKeys:keysToRemove];
}

+ (void)saveActivityTimestamp {
	[[NSUserDefaults standardUserDefaults] setObject:lastActivityTimestamp forKey:DEFAULT_KEY_LAST_ACTIVITY];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (NSDate *)lastActivityTimestamp {
	return lastActivityTimestamp;
}

@end
