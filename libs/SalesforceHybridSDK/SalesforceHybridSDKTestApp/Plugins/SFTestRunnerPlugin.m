/*
 Copyright (c) 2012-present, salesforce.com, inc. All rights reserved.
 
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

NSString * const kSFTestRunnerPluginName = @"com.salesforce.testrunner";

@implementation SFTestResult

@synthesize testName = _testName;
@synthesize message = _message;
@synthesize success = _success;
@synthesize duration = _duration;

- (id)initWithName:(NSString*)testName success:(BOOL)success message:(NSString*)message status:(NSDictionary*)testStatus {
    self = [super init];
    if (nil != self) {
        _testName = [testName copy];
        _success = success;
        _message = [message copy];
        NSNumber *durationMs = testStatus[@"testDuration"];
        _duration = [durationMs doubleValue] / 1000;
    }
    return self;
}

- (void)dealloc {
    SFRelease(_testName);
    SFRelease(_message);
}

@end

@implementation SFTestRunnerPlugin

@synthesize testResults = _testResults;
@synthesize readyToStartTests = _readyToStartTests;

- (void) pluginInitialize {
    _readyToStartTests = NO;
    [self log:SFLogLevelDebug msg:@"SFTestRunnerPlugin pluginInitialize"];
    _testResults = [[NSMutableDictionary alloc] init];
}

- (void)dealloc {
    SFRelease(_testResults);
}

- (BOOL)testResultAvailable:(NSString *)testName {
    if ([[self testResults] objectForKey:testName])
        return YES;
    return NO;
}

- (void)onReadyForTests:(CDVInvokedUrlCommand *)command {
    NSString* callbackId = command.callbackId;
    [self getVersion:@"onReadyForTests" withArguments:command.arguments];
    [self writeCommandOKResultToJsRealm:callbackId];
    self.readyToStartTests = YES;
}

- (void)onTestComplete:(CDVInvokedUrlCommand *)command {
    NSString* callbackId = command.callbackId;
    [self getVersion:@"onTestComplete" withArguments:command.arguments];
    NSDictionary *argsDict = [self getArgument:command.arguments atIndex:0];
    NSString *testName = argsDict[@"testName"];
    BOOL success = [[argsDict valueForKey:@"success"] boolValue];
    NSString *message = [self stringByStrippingHTML:[argsDict valueForKey:@"message"]];
    NSDictionary *testStatus = [argsDict valueForKey:@"testStatus"];
    [self log:SFLogLevelDebug format:@"testName: %@ success: %d message: %@",testName,success,message];
    if (!success) {
        [self log:SFLogLevelDebug format:@"### TEST FAILED: %@",testName];
    }
    SFTestResult *testResult = [[SFTestResult alloc] initWithName:testName success:success message:message status:testStatus];
    [self.testResults setObject:testResult forKey:testName];
    [self writeCommandOKResultToJsRealm: callbackId];    
}

- (NSString*)stringByStrippingHTML:(NSString*)str {
    NSRange r;
    while ((r = [str rangeOfString:@"<[^>]+>" options:NSRegularExpressionSearch]).location != NSNotFound) {
        str = [str stringByReplacingCharactersInRange:r withString:@"|"];
    }
    while ((r = [str rangeOfString:@"[|]+" options:NSRegularExpressionSearch]).location != NSNotFound) {
        str = [str stringByReplacingCharactersInRange:r withString:@" "];
    }
    return str;
}

@end
