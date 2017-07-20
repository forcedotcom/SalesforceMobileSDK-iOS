/*
 Copyright (c) 2012-present, salesforce.com, inc. All rights reserved.
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
#import <SmartStore/SmartStore.h>
#import <SalesforceHybridSDK/SalesforceHybridSDK.h>
#import <SalesforceSDKCore/SFApplicationHelper.h>
#import "SFPluginTestSuite.h"
#import "AppDelegate.h"
#import "SFTestRunnerPlugin.h"

@implementation SFPluginTestSuite

@synthesize jsTestName = _jsTestName;
@synthesize jsSuiteName = _jsSuiteName;

- (void)setUp
{
    [super setUp];
    AppDelegate *appDelegate = (AppDelegate *)[[SFApplicationHelper sharedApplication] delegate];
    _testRunnerPlugin = [appDelegate.viewController.commandDelegate getCommandInstance:kSFTestRunnerPluginName];
    
    // Block until the javascript has notified the container that it's ready
    BOOL timedOut = [self waitForTestRunnerReady];
    if (timedOut) {
        [SFSDKLogger log:[self class] level:DDLogLevelDebug message:@"failed to start test runner..."];
    }
}

- (void)tearDown
{
    // Tear-down code here.
    [super tearDown];
}

- (BOOL)isTestResultAvailable:(NSString *)testName {
    return [_testRunnerPlugin testResultAvailable:testName];
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
            [SFSDKLogger log:[self class] level:DDLogLevelDebug format:@"testRunner took too long (%f) to startup", elapsed];
            completionTimedOut = YES;
            break;
        }
        [SFSDKLogger log:[self class] level:DDLogLevelDebug format:@"## waiting to start tests... "];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    }
    return completionTimedOut;
}


- (BOOL)waitForOneCompletion:(NSString *)testName {
    NSDate *startTime = [NSDate date] ;
    BOOL completionTimedOut = NO;
    while (![self isTestResultAvailable:testName]) {
        NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:startTime];
        if (elapsed > 30.0) {
            [SFSDKLogger log:[self class] level:DDLogLevelDebug format:@"test took too long (%f) to complete", elapsed];
            completionTimedOut = YES;
            break;
        }
        [SFSDKLogger log:[self class] level:DDLogLevelDebug format:@"## sleeping on %@...", self.jsTestName];
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
        XCTAssertTrue([self isTestRunnerReady], @"Test runner not ready");
        return;
    }
    self.jsTestName = testName;
    NSString *testCmd = [NSString stringWithFormat:@"var testRunner = cordova.require(\"com.salesforce.plugin.testrunner\"); testRunner.setTestSuite('%@'); testRunner.startTest('%@');"
                         ,suiteName,testName];
    AppDelegate *app = (AppDelegate*)[SFApplicationHelper sharedApplication].delegate;
    NSString *cmdResult = [app evalJS:testCmd];
    [SFSDKLogger log:[self class] level:DDLogLevelDebug format:@"cmdResult: '%@'", cmdResult];
    BOOL timedOut = [self waitForOneCompletion:testName];
    XCTAssertFalse(timedOut, @"timed out waiting for %@ to complete",testName);
    if (!timedOut) {
        AppDelegate *appDelegate = (AppDelegate *)[[SFApplicationHelper sharedApplication] delegate];
        SFTestRunnerPlugin *plugin = (SFTestRunnerPlugin*)[appDelegate.viewController.commandDelegate getCommandInstance:kSFTestRunnerPluginName];
        SFTestResult *testResult = [[plugin testResults] objectForKey:testName];
        [SFSDKLogger log:[self class] level:DDLogLevelDebug format:@"%@ completed in %f",testResult.testName, testResult.duration];
        XCTAssertEqualObjects(testResult.testName, testName, @"Wrong test completed");
        XCTAssertTrue(testResult.success, @"%@ failed: %@",testResult.testName,testResult.message);
        [[plugin testResults] removeObjectForKey:testName];
    }
}

@end
