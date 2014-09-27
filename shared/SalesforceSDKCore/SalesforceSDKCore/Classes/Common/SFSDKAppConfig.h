//
//  SFSDKAppConfig.h
//  SalesforceSDKCore
//
//  Created by Kevin Hawkins on 9/26/14.
//  Copyright (c) 2014 salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SFSDKAppConfig : NSObject

/**
 * The Connected App key associated with this application.
 */
@property (nonatomic, copy) NSString *remoteAccessConsumerKey;

/**
 * The OAuth Redirect URI associated with the configured Connected Application.
 */
@property (nonatomic, copy) NSString *oauthRedirectURI;

/**
 * The OAuth Scopes being requested for this app.
 */
@property (nonatomic, strong) NSSet *oauthScopes;

/**
 * Whether or not this app should authenticate when it first starts.
 */
@property (nonatomic, assign) BOOL shouldAuthenticate;

/**
 * The config as a dictionary
 */
@property (nonatomic, strong) NSMutableDictionary *configDict;

/**
 * Initializer with a given JSON-based configuration dictionary.
 * @param configDict The dictionary containing the configuration.
 */
- (instancetype)initWithDict:(NSDictionary *)configDict;

@end
