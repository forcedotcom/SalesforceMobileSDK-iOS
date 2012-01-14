//
//  TestPluginsTests.m
//  TestPluginsTests
//
//  Created by Todd Stellanova on 1/13/12.
//  Copyright (c) 2012 Salesforce.com. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "TestPluginsTests.h"

#import "SFContainerAppDelegate.h"

@implementation TestPluginsTests

- (void)setUp
{
    [super setUp];
    
    // Set-up code here.
}

- (void)tearDown
{
    // Tear-down code here.
    
    [super tearDown];
}

- (BOOL)areTestsFinishedRunning {
    BOOL result = NO;
   // gTestsFinishedRunning
    
    SFContainerAppDelegate *myApp = [SFContainerAppDelegate sharedInstance];
    NSString *jsResult = [(UIWebView*)myApp.webView stringByEvaluatingJavaScriptFromString:@"gTestsFinishedRunning === true"];
    result = [jsResult isEqualToString:@"true"];
    return result;
}

- (BOOL)waitForAllTestCompletions {
    NSDate *startTime = [NSDate date] ;
    BOOL completionTimedOut = NO;
    while (![self areTestsFinishedRunning]) {
        NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:startTime];
        if (elapsed > 30.0) {
            NSLog(@"request took too long (%f) to complete",elapsed);
            completionTimedOut = YES;
            break;
        }
        
        NSLog(@"## sleeping...");
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.3]];
    }
    
    return completionTimedOut;
}

- (void)testExample
{
    
    
    BOOL timedOut = [self waitForAllTestCompletions];
    
    STAssertFalse(timedOut,@"Timed out waiting for tests to complete");
    
}

@end
