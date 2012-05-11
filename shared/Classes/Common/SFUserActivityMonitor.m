//
//  SFUserActivityMonitor.m
//  SalesforceSDK
//
//  Created by Kevin Hawkins on 5/10/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "SFUserActivityMonitor.h"
#import "SFApplication.h"

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
    [_lastEventDate release]; _lastEventDate = nil;
    [self stopMonitoring]; _monitorTimer = nil;
    [super dealloc];
}

#pragma mark - Monitoring

- (void)startMonitoring
{
    [self stopMonitoring];
    
    [_lastEventDate release];
    _lastEventDate = [[(SFApplication *)[UIApplication sharedApplication] lastEventDate] retain];
    _monitorTimer = [[NSTimer timerWithTimeInterval:kActivityCheckPeriodSeconds target:self selector:@selector(timerFired:) userInfo:nil repeats:YES] retain];
    [[NSRunLoop mainRunLoop] addTimer:_monitorTimer forMode:NSDefaultRunLoopMode];
}

- (void)stopMonitoring
{
    if (_monitorTimer != nil) {
        [_monitorTimer invalidate];
        [_monitorTimer release];
    }
}

- (void)timerFired:(NSTimer *)theTimer
{
    
}

@end
