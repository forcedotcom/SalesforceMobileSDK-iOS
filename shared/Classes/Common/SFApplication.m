//
//  SFApplication.m
//  SalesforceSDK
//
//  Created by Kevin Hawkins on 5/10/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "SFApplication.h"
#import "SalesforceSDKConstants.h"

@implementation SFApplication

@synthesize lastEventDate = _lastEventDate;

#pragma mark - init / dealloc / etc.

- (id)init
{
    self = [super init];
    if (self) {
        _lastEventDate = [[NSDate alloc] init];
    }
    return self;
}

- (void)dealloc
{
    SFRelease(_lastEventDate);
    
    [super dealloc];
}

#pragma mark - Event handling

- (void)sendEvent:(UIEvent *)event
{
    NSSet *allTouches = [event allTouches];
    if ([allTouches count] > 0) {
        UITouchPhase phase = ((UITouch *)[allTouches anyObject]).phase;
        if (phase == UITouchPhaseBegan || phase == UITouchPhaseEnded) {
            [_lastEventDate release];
            _lastEventDate = [[NSDate alloc] init];
        }
    }
    
    [super sendEvent:event];
}


@end
