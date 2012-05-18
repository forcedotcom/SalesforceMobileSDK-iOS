//
//  SFCredentialsManager.m
//  SalesforceSDK
//
//  Created by Kevin Hawkins on 5/15/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "SFCredentialsManager.h"
#import "SFOAuthCredentials.h"
#import "SalesforceSDKConstants.h"

@implementation SFCredentialsManager

@synthesize credentials = _credentials;

#pragma mark - init / dealloc / etc.

+ (SFCredentialsManager *)sharedInstance {
    static dispatch_once_t pred;
    static SFCredentialsManager *credentialsManager = nil;
	
    dispatch_once(&pred, ^{
		credentialsManager = [[self alloc] init];
	});
    return credentialsManager;
}

- (void)dealloc
{
    SFRelease(_credentials);
    [super dealloc];
}

@end
