//
//  SFAccountManagerPlugin.h
//  SalesforceHybridSDK
//
//  Created by Kevin Hawkins on 3/12/14.
//  Copyright (c) 2014 salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CDVPlugin.h"

@class CDVInvokedUrlCommand;

//
// NSDictionary keys defining auth data properties.  See [SFHybridViewController credentialsAsDictionary].
//
extern NSString * const kUserAccountAuthTokenDictKey;
extern NSString * const kUserAccountRefreshTokenDictKey;
extern NSString * const kUserAccountLoginServerDictKey;
extern NSString * const kUserAccountIdentityUrlDictKey;
extern NSString * const kUserAccountInstanceServerDictKey;
extern NSString * const kUserAccountOrgIdDictKey;
extern NSString * const kUserAccountUserIdDictKey;
extern NSString * const kUserAccountUsernameDictKey;
extern NSString * const kUserAccountClientIdDictKey;

/**
 * Plugin for managing accounts, account switching, etc.
 */
@interface SFAccountManagerPlugin : CDVPlugin

/**
 * Cordova plug-in method to get the users that have been associated with the app on
 * this device.
 * @param command Cordova plugin command object, containing input parameters.
 */
- (void)getUsers:(CDVInvokedUrlCommand *)command;

@end
