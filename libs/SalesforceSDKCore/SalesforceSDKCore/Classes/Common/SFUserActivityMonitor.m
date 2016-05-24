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

#import "SFUserActivityMonitor.h"
#import "SFApplication.h"
#import "SFInactivityTimerCenter.h"
#import "SFApplicationHelper.h"

// Singleton instance
static SFUserActivityMonitor *_instance;
static dispatch_once_t _sharedInstanceGuard;

// Private constants
static NSTimeInterval const kActivityCheckPeriodSeconds = 20;

@interface SFUserActivityMonitor()

/**
 * Method called when the periodic timer check fires.
 */
- (void)timerFired:(NSTimer *)theTimer;

@end

@implementation SFUserActivityMonitor

#pragma mark - Singleton

+ (instancetype)sharedInstance {
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
        _instance = nil;
        _sharedInstanceGuard = 0; 
    }
}

#pragma mark - init / dealloc / etc.

- (void)dealloc
{
    SFRelease(_lastEventDate);
    [self stopMonitoring];
}

#pragma mark - Monitoring

- (void)startMonitoring
{
    [self stopMonitoring];
    
    _lastEventDate = [[(SFApplication *)[SFApplicationHelper sharedApplication] lastEventDate] copy];
    _monitorTimer = [NSTimer timerWithTimeInterval:kActivityCheckPeriodSeconds
                                             target:self
                                           selector:@selector(timerFired:)
                                           userInfo:nil
                                            repeats:YES];
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
    NSDate *lastEventAsOfNow = [(SFApplication *)[SFApplicationHelper sharedApplication] lastEventDate];
    if (![_lastEventDate isEqualToDate:lastEventAsOfNow]) {
        [self log:SFLogLevelDebug format:@"New user activity at %@", lastEventAsOfNow];
        [SFInactivityTimerCenter updateActivityTimestampTo:lastEventAsOfNow];
        // TODO: Possibly consider a notification, if other objects would like to subscribe to this.
        _lastEventDate = [lastEventAsOfNow copy];
    } else {
        [self log:SFLogLevelDebug format:@"Last user activity: %.2f secs ago.", [[NSDate date] timeIntervalSinceDate:_lastEventDate]];
    }
}

@end
