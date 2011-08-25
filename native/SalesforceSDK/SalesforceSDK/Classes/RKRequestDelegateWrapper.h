//
//  RKRequestDelegateWrapper.h
//  SalesforceSDK
//
//  Created by Didier Prophete on 7/22/11.
//  Copyright 2011 Salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RestKit.h"
#import "SFOAuthCoordinator.h"
#import "SFRestAPI.h"

@class SFRestRequest;

@interface RKRequestDelegateWrapper : NSObject<RKRequestDelegate, SFOAuthCoordinatorDelegate> {
    id<SFRestDelegate> _delegate;
    SFRestRequest *_request;
    id<SFOAuthCoordinatorDelegate> _previousOauthDelegate;
}

@property (nonatomic, assign) id<SFRestDelegate>delegate;
@property (nonatomic, retain) SFRestRequest *request;
@property (nonatomic, assign) id<SFOAuthCoordinatorDelegate> previousOauthDelegate;

+ (id)wrapperWithDelegate:(id<SFRestDelegate>)delegate request:(SFRestRequest *)request;

- (void)send;
@end
