//
//  SFApplication.m
//  SalesforceSDK
//
//  Created by Kevin Hawkins on 5/10/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "SFApplication.h"

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
    [_lastEventDate release]; _lastEventDate = nil;
    
    [super dealloc];
}

#pragma mark - Event handling

- (void)sendEvent:(UIEvent *)event
{
    if (event.type == UIEventTypeTouches) {
        [_lastEventDate release];
        _lastEventDate = [[NSDate alloc] init];
    }
    
    [super sendEvent:event];
}


@end
