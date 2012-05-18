//
//  SFCredentialsManager.h
//  SalesforceSDK
//
//  Created by Kevin Hawkins on 5/15/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SFOAuthCredentials;

@interface SFCredentialsManager : NSObject

+ (SFCredentialsManager *)sharedInstance;

@property (nonatomic, retain) SFOAuthCredentials *credentials;

@end
