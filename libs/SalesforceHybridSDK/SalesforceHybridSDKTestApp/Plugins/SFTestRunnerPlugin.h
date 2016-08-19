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

#import <Foundation/Foundation.h>
#import <Cordova/CDVPlugin.h>
@class CDVInvokedUrlCommand;

extern NSString * const kSFTestRunnerPluginName;

@interface SFTestResult : NSObject {
    NSString *_testName;
    NSString *_message;
    BOOL    _success;
    NSTimeInterval _duration;
}

@property (nonatomic, readonly, strong) NSString *testName;
@property (nonatomic, readonly, assign) BOOL success;
@property (nonatomic, readonly, strong) NSString *message;
@property (nonatomic, readonly, assign) NSTimeInterval duration;

- (id)initWithName:(NSString*)testName success:(BOOL)success message:(NSString*)message status:(NSDictionary*)testStatus;

@end

@interface SFTestRunnerPlugin : CDVPlugin {
    NSMutableDictionary *_testResults;
}

@property (atomic, readonly, strong) NSMutableDictionary *testResults;
@property (atomic, assign) BOOL readyToStartTests;

- (void)onReadyForTests:(CDVInvokedUrlCommand *)command;
- (void)onTestComplete:(CDVInvokedUrlCommand *)command;
- (BOOL)testResultAvailable:(NSString *)testName;

@end
