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

NSString * const kSFUserAuthenticatedNotification               = @"SFUserAuthenticatedNotification";
NSString * const kSFUserAuthenticatedNotificationCredentialsKey = @"oauthCredentials";
NSString * const kSFUserLoggedOutNotification                   = @"SFUserLoggedOutNotification";

@interface SFCredentialsManager ()

- (void)gotCredentials:(NSNotification *)note;
- (void)loggedOut;

@end

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

- (id)init
{
    self = [super init];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self 
                                                 selector:@selector(gotCredentials:) 
                                                     name:kSFUserAuthenticatedNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self 
                                                 selector:@selector(loggedOut) 
                                                     name:kSFUserLoggedOutNotification
                                                   object:nil];
    }
    
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    SFRelease(_credentials);
    [super dealloc];
}

#pragma mark - Private methods

- (void)gotCredentials:(NSNotification *)note
{
    self.credentials = [[note userInfo] objectForKey:kSFUserAuthenticatedNotificationCredentialsKey];
}

- (void)loggedOut
{
    SFRelease(_credentials);
}

@end
