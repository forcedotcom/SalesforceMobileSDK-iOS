//
//  SFSDKAsyncProcessListener.h
//  SalesforceSDKCommon
//
//  Created by Kevin Hawkins on 12/18/14.
//  Copyright (c) 2014 salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SFSDKAsyncProcessListener : NSObject

- (id)initWithExpectedStatus:(id)expectedStatus actualStatusBlock:(id (^)(void))actualStatusBlock timeout:(NSTimeInterval)timeout;
- (id)waitForCompletion;

@end
