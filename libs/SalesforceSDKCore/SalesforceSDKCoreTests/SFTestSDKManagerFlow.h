//
//  SFTestSDKManagerFlow.h
//  SalesforceSDKCore
//
//  Created by Kevin Hawkins on 9/20/14.
//  Copyright (c) 2014-present, salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SalesforceSDKCore/SalesforceSDKCore.h>
#import "SalesforceSDKManager+Internal.h"

@interface SFTestSDKManagerFlow : NSObject <SalesforceSDKManagerFlow>

@property (nonatomic, assign) BOOL pauseInAuth;

- (id)initWithStepTimeDelaySecs:(NSTimeInterval)timeDelayInSecs;
- (void)resumeAuth;
- (BOOL)waitForLaunchCompletion;

@end
