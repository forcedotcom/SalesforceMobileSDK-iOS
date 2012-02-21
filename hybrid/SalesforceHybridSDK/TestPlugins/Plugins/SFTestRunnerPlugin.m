//
//  SFTestRunnerPlugin.m
//  SalesforceHybridSDK
//
//  Created by Todd Stellanova on 1/25/12.
//  Copyright (c) 2012 Salesforce.com. All rights reserved.
//

#import "SFTestRunnerPlugin.h"



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


@interface SFTestRunnerPlugin (Private)

- (void)writeSuccessResultToJsRealm:(PluginResult*)result callbackId:(NSString*)callbackId;
- (void)writeErrorResultToJsRealm:(PluginResult*)result callbackId:(NSString*)callbackId;
- (void)writeSuccessDictToJsRealm:(NSDictionary*)dict callbackId:(NSString*)callbackId;
- (void)writeCommandOKResultToJsRealm:(NSString*)callbackId;

@end

@implementation SFTestRunnerPlugin


@synthesize testResults = _testResults;
@synthesize readyToStartTests = _readyToStartTests;


///designated init
- (PGPlugin*) initWithWebView:(UIWebView*)theWebView 
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



#pragma mark - PhoneGap plugin support

- (void)writeSuccessDictToJsRealm:(NSDictionary*)dict callbackId:(NSString*)callbackId
{
    PluginResult* result = [PluginResult resultWithStatus:PGCommandStatus_OK messageAsDictionary:dict];
    [self writeSuccessResultToJsRealm:result callbackId:callbackId];
}

- (void)writeSuccessResultToJsRealm:(PluginResult*)result callbackId:(NSString*)callbackId
{    
    NSString *jsString = [result toSuccessCallbackString:callbackId];
    
	if (jsString){
		[self writeJavascript:jsString];
    }
}

- (void)writeCommandOKResultToJsRealm:(NSString*)callbackId
{
    [self writeSuccessResultToJsRealm:[PluginResult resultWithStatus:PGCommandStatus_OK] callbackId:callbackId];
}

- (void)writeErrorResultToJsRealm:(PluginResult*)result callbackId:(NSString*)callbackId
{
    NSString *jsString = [result toErrorCallbackString:callbackId];
    
	if (jsString){
		[self writeJavascript:jsString];
    }
}

#pragma mark - Plugin methods called from js

- (void)onReadyForTests:(NSArray*)arguments withDict:(NSDictionary*)options
{
    NSString* callbackId = [arguments objectAtIndex:0];
    [self writeCommandOKResultToJsRealm:callbackId];

    self.readyToStartTests = YES;
}

- (void)onTestComplete:(NSArray*)arguments withDict:(NSDictionary*)options
{
    NSString* callbackId = [arguments objectAtIndex:0];
    NSString *testName = [options objectForKey:@"testName"];
    BOOL success = [(NSNumber *)[options valueForKey:@"success"] boolValue];
    NSString *message = [options valueForKey:@"message"];
    NSDictionary *testStatus = [options valueForKey:@"testStatus"];
    
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
