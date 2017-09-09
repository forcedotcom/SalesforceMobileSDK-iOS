/*
 Copyright (c) 2014-present, salesforce.com, inc. All rights reserved.
 
 Redistribution and use of this software in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright notice, this list of conditions
 and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of
 conditions and the following disclaimer in the documentation and/or other materials provided
 with the distribution.
 * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
 endorse or promote products derived from this software without specific prior written
 permission of salesforce.com, inc.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
 FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
 WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <Foundation/Foundation.h>
#import <Cordova/CDVPlugin.h>

@class CDVInvokedUrlCommand;

/**
 * Dictionary keys for the user account data object used by the plugin.
 */
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

/**
 * Cordova plug-in method to get information about the current user of the app.
 * @param command Cordova plugin command object, containing input parameters.
 */
- (void)getCurrentUser:(CDVInvokedUrlCommand *)command;

/**
 * Cordova plug-in method to switch to a different user.  If no user information is given
 * or the user isn't found, switch to a new user.
 * @param command Cordova plugin command object, containing input parameters.
 */
- (void)switchToUser:(CDVInvokedUrlCommand *)command;

/**
 * Cordova plug-in method to log out a user.  If no user information is given
 * or the user isn't found, logout the current user.
 * @param command Cordova plugin command object, containing input parameters.
 */
- (void)logout:(CDVInvokedUrlCommand *)command;

@end
