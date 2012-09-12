/*
 Copyright (c) 2012, salesforce.com, inc. All rights reserved.
 Author: Todd Stellanova
 
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

#import <UIKit/UIKit.h>

#import "SFPluginTestSuite.h"

#import "AppDelegate.h"
#import "SFHybridViewController.h"
#import "SFTestRunnerPlugin.h"
#import "SFSmartStore.h"
#import "SFSmartStorePlugin.h"



@implementation SFPluginTestSuite

@synthesize jsTestName = _jsTestName;
@synthesize jsSuiteName = _jsSuiteName;

- (void)setUp
{
    [super setUp];
    
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    _testRunnerPlugin = [appDelegate.viewController.commandDelegate getCommandInstance:kSFTestRunnerPluginName];

    
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
        if (elapsed > 15.0) {
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
    [self runTest:testName inSuite:self.jsSuiteName];
}

- (void)runTest:(NSString*)testName inSuite:(NSString*)suiteName 
{
    if (![self isTestRunnerReady]) {
        STAssertTrue([self isTestRunnerReady], @"Test runner not ready");
        return;
    }
    
    self.jsTestName = testName;
    
    NSString *testCmd = [NSString stringWithFormat:@"var testRunner = cordova.require(\"salesforce/plugin/testrunner\"); testRunner.setTestSuite('%@'); testRunner.startTest('%@');"
                         ,suiteName,testName];
    
    AppDelegate *app = (AppDelegate*)[SFContainerAppDelegate sharedInstance];
    NSString *cmdResult = [app evalJS:testCmd];
    NSLog(@"cmdResult: '%@'",cmdResult);
    
    BOOL timedOut = [self waitForOneCompletion];
    STAssertFalse(timedOut, @"timed out waiting for %@ to complete",testName);
    
    if (!timedOut) {
        AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        SFTestRunnerPlugin *plugin = (SFTestRunnerPlugin*)[appDelegate.viewController.commandDelegate getCommandInstance:kSFTestRunnerPluginName];
        SFTestResult *testResult = [[[plugin testResults] objectAtIndex:0] retain];
        [[plugin testResults] removeObjectAtIndex:0];
        NSLog(@"%@ completed in %f",testResult.testName, testResult.duration);
        STAssertEqualObjects(testResult.testName, testName, @"Wrong test completed");
        STAssertTrue(testResult.success, @"%@ failed: %@",testResult.testName,testResult.message);
        [testResult autorelease];
    }
}








@end
