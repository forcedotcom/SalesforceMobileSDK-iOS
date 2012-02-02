//
//  TestPluginsTests.m
//  TestPluginsTests
//
//  Created by Todd Stellanova on 1/13/12.
//  Copyright (c) 2012 Salesforce.com. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "TestPluginsTests.h"

#import "AppDelegate.h"
#import "SFTestRunnerPlugin.h"


@interface TestPluginsTests (Private)

- (BOOL)waitForTestRunnerReady;

@end

@implementation TestPluginsTests

@synthesize jsTestName = _jsTestName;

- (void)setUp
{
    [super setUp];
    
    _testRunnerPlugin = (SFTestRunnerPlugin*)[[SFContainerAppDelegate sharedInstance] getCommandInstance:kSFTestRunnerPluginName];

    // Block until the javascript has notified the container that it's ready
    BOOL timedOut = [self waitForTestRunnerReady];
    if (timedOut) {
        NSLog(@"failed to start test runner...");
    } 
    
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

- (BOOL)isTestResultAvailable {
    return [_testRunnerPlugin testResultAvailable];
}

- (BOOL)isTestRunnerReady {
    return [_testRunnerPlugin readyToStartTests];
}


- (BOOL)waitForTestRunnerReady {
    NSDate *startTime = [NSDate date] ;
    BOOL completionTimedOut = NO;
    
    while (![self isTestRunnerReady]) {
        NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:startTime];
        if (elapsed > 4.0) {
            NSLog(@"testRunner took too long (%f) to startup",elapsed);
            completionTimedOut = YES;
            break;
        }
        
        NSLog(@"## waiting to start tests... ");
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    }
    
    return completionTimedOut;
}


- (BOOL)waitForOneCompletion {
    NSDate *startTime = [NSDate date] ;
    BOOL completionTimedOut = NO;
    
    while (![self isTestResultAvailable]) {
        NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:startTime];
        if (elapsed > 30.0) {
            NSLog(@"test took too long (%f) to complete",elapsed);
            completionTimedOut = YES;
            break;
        }
        
        NSLog(@"## sleeping on %@...",self.jsTestName);
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.3]];
    }
    
    return completionTimedOut;
}



- (void)runTest:(NSString*)testName
{
    if (![self isTestRunnerReady]) {
        STAssertTrue([self isTestRunnerReady], @"Test runner not ready");
        return;
    }
    
    self.jsTestName = testName;
        
    NSString *testCmd = [NSString stringWithFormat:@"gTestSuiteSmartStore.startTest('%@');",testName];
    AppDelegate *app = (AppDelegate*)[SFContainerAppDelegate sharedInstance];
    NSString *cmdResult = [app evalJS:testCmd];
    NSLog(@"cmdResult: %@",cmdResult);
    
    BOOL timedOut = [self waitForOneCompletion];
    STAssertFalse(timedOut, @"timed out waiting for %@ to complete",testName);
    
    if (!timedOut) {
        SFTestRunnerPlugin *plugin = (SFTestRunnerPlugin*)[[SFContainerAppDelegate sharedInstance] getCommandInstance:kSFTestRunnerPluginName];
        SFTestResult *testResult = [[[plugin testResults] objectAtIndex:0] retain];
        [[plugin testResults] removeObjectAtIndex:0];
        
        STAssertEqualObjects(testResult.testName, testName, @"Wrong test completed");
        STAssertTrue(testResult.success, @"%@ %d",testResult.testName,testResult.success);
    }
}


- (void)testRegisterRemoveSoup {
    [self runTest:@"testRegisterRemoveSoup"];
}

- (void)testRemoveFromSoup {
    [self runTest:@"testRemoveFromSoup"];
}

- (void)testUpsertSoupEntries {
    [self runTest:@"testUpsertSoupEntries"];
}

// TODO uncomment this test once it's fixed
//- (void)testRetrieveSoupEntries {
//    [self runTest:@"testRetrieveSoupEntries"];
//}

- (void)testQuerySoup {
    [self runTest:@"testQuerySoup"];
}

- (void)testManipulateCursor {
    [self runTest:@"testManipulateCursor"];
}

@end
