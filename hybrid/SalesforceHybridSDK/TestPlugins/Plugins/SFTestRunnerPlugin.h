//
//  SFTestRunnerPlugin.h
//  SalesforceHybridSDK
//
//  Created by Todd Stellanova on 1/25/12.
//  Copyright (c) 2012 Salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>

// From Cordova.framework
#import <Cordova/CDVPlugin.h>


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
    
    NSMutableArray *_testResults;
}

/// array of SFTestResult
@property (atomic, readonly, strong) NSMutableArray *testResults;
@property (atomic, readonly) BOOL testResultAvailable;
@property (atomic, assign) BOOL readyToStartTests;

#pragma mark - Plugin methods called from js

- (void)onReadyForTests:(NSArray*)arguments withDict:(NSDictionary*)options;
- (void)onTestComplete:(NSArray*)arguments withDict:(NSDictionary*)options;

@end
