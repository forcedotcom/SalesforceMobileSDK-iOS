//
//  SFUserActivityMonitor.m
//  SalesforceSDK
//
//  Created by Kevin Hawkins on 5/10/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "SFUserActivityMonitor.h"
#import "SFApplication.h"
#import "SalesforceSDKConstants.h"
#import "SFInactivityTimerCenter.h"

// Singleton instance
static SFUserActivityMonitor *_instance;
static dispatch_once_t _sharedInstanceGuard;

// Private constants
static NSTimeInterval const kActivityCheckPeriodSeconds = 10;

@interface SFUserActivityMonitor()

- (void)timerFired:(NSTimer *)theTimer;

@end

@implementation SFUserActivityMonitor

#pragma mark - Singleton

+ (SFUserActivityMonitor *)sharedInstance {
    dispatch_once(&_sharedInstanceGuard, 
                  ^{ 
                      _instance = [[SFUserActivityMonitor alloc] init];
                  });
    return _instance;
}

+ (void)clearSharedInstance {
    //subverts dispatch_once by clearing _sharedInstanceGuard
    //This should really only be used for unit testing.
    @synchronized(self) {
        [_instance release];
        _instance = nil;
        _sharedInstanceGuard = 0; 
    }
}

#pragma mark - init / dealloc / etc.

- (void)dealloc
{
    SFRelease(_lastEventDate);
    [self stopMonitoring];
    [super dealloc];
}

#pragma mark - Monitoring

- (void)startMonitoring
{
    [self stopMonitoring];
    
    [_lastEventDate release];
    _lastEventDate = [[(SFApplication *)[UIApplication sharedApplication] lastEventDate] copy];
    _monitorTimer = [[NSTimer timerWithTimeInterval:kActivityCheckPeriodSeconds
                                             target:self
                                           selector:@selector(timerFired:)
                                           userInfo:nil
                                            repeats:YES] retain];
    [[NSRunLoop mainRunLoop] addTimer:_monitorTimer forMode:NSDefaultRunLoopMode];
}

- (void)stopMonitoring
{
    if (_monitorTimer != nil) {
        [_monitorTimer invalidate];
        SFRelease(_monitorTimer);
    }
}

- (void)timerFired:(NSTimer *)theTimer
{
    NSDate *lastEventAsOfNow = [(SFApplication *)[UIApplication sharedApplication] lastEventDate];
    if (![_lastEventDate isEqualToDate:lastEventAsOfNow]) {
        [SFInactivityTimerCenter updateActivityTimestamp];
        // TODO: Possibly consider a notification, if other objects would like to subscribe to this.
        [_lastEventDate release];
        _lastEventDate = [lastEventAsOfNow copy];
    }
}

@end
