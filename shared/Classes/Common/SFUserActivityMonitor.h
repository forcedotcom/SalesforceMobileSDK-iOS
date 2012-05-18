//
//  SFUserActivityMonitor.h
//  SalesforceSDK
//
//  Created by Kevin Hawkins on 5/10/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SFUserActivityMonitor : NSObject
{
    NSTimer *_monitorTimer;
    NSDate *_lastEventDate;
}

+ (SFUserActivityMonitor *)sharedInstance;

- (void)startMonitoring;
- (void)stopMonitoring;

@end
