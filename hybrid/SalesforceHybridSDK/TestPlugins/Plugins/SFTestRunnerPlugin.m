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

#import "SFTestRunnerPlugin.h"
#import "CDVPlugin+SFAdditions.h"
#import "CDVInvokedUrlCommand.h"

NSString * const kSFTestRunnerPluginName = @"com.salesforce.testrunner";

@implementation SFTestResult

@synthesize testName = _testName;
@synthesize message = _message;
@synthesize success = _success;
@synthesize duration = _duration;

- (id)initWithName:(NSString*)testName success:(BOOL)success message:(NSString*)message status:(NSDictionary*)testStatus
{
    self = [super init];
    if (nil != self) {
        _testName = [testName copy];
        _success = success;
        _message = [message copy];
        NSNumber *durationMs = [testStatus objectForKey:@"testDuration"];
        _duration = [durationMs doubleValue] / 1000;
    }
    
    return self;
}

- (void)dealloc {
    [_testName release]; _testName = nil;
    [_message release]; _message = nil;
    [super dealloc];
}

@end


@implementation SFTestRunnerPlugin


@synthesize testResults = _testResults;
@synthesize readyToStartTests = _readyToStartTests;


///designated init
- (CDVPlugin*) initWithWebView:(UIWebView*)theWebView 
{
    self = [super initWithWebView:theWebView];
    
    if (nil != self)  {
        _readyToStartTests = NO;
        NSLog(@"SFTestRunnerPlugin initWithWebView");
        _testResults = [[NSMutableArray alloc] init ];
    }
    return self;
}

- (void)dealloc {
    [_testResults release]; _testResults = nil;
    [super dealloc];
}


- (BOOL)testResultAvailable {
    return ([self.testResults count] > 0);
}


#pragma mark - Plugin methods called from js

- (void)onReadyForTests:(CDVInvokedUrlCommand *)command
{
    NSString* callbackId = command.callbackId;
    /* NSString* jsVersionStr = */[self getVersion:@"onReadyForTests" withArguments:command.arguments];
    [self writeCommandOKResultToJsRealm:callbackId];

    self.readyToStartTests = YES;
}

- (void)onTestComplete:(CDVInvokedUrlCommand *)command
{
    NSString* callbackId = command.callbackId;
    /* NSString* jsVersionStr = */[self getVersion:@"onTestComplete" withArguments:command.arguments];
    NSDictionary *argsDict = [self getArgument:command.arguments atIndex:0];
    NSString *testName = [argsDict objectForKey:@"testName"];
    BOOL success = [[argsDict valueForKey:@"success"] boolValue];
    NSString *message = [argsDict valueForKey:@"message"];
    NSDictionary *testStatus = [argsDict valueForKey:@"testStatus"];
    
    NSLog(@"testName: %@ success: %d message: %@",testName,success,message);
    if (!success) {
        NSLog(@"### TEST FAILED: %@",testName);
    }
    SFTestResult *testResult = [[SFTestResult alloc] initWithName:testName success:success message:message status:testStatus];
    [self.testResults addObject:testResult];
    [testResult release];
    
    [self writeCommandOKResultToJsRealm: callbackId];    
}

    

@end
