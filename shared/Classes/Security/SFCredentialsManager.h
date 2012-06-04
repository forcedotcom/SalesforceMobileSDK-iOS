/*
 Copyright (c) 2012, salesforce.com, inc. All rights reserved.
 
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

@class SFOAuthCoordinator;
@class SFOAuthCredentials;
@class SFIdentityCoordinator;
@class SFIdentityData;

/**
 * Class used to manage a common credentials set across the app.
 */
@interface SFCredentialsManager : NSObject

/**
 * Returns the singleton instance of this class for the default account.
 */
+ (SFCredentialsManager *)sharedInstance;

/**
 * Returns the singleton instance of this class for the given account.
 * @param accountIdentifier The account identifier of the class.
 */
+ (SFCredentialsManager *)sharedInstanceForAccount:(NSString *)accountIdentifier;

+ (BOOL)logoutSettingEnabled;
+ (void)ensureAccountDefaultsExist;
+ (NSString *)loginHost;
+ (void)setLoginHost:(NSString *)newLoginHost;
+ (BOOL)updateLoginHost;
+ (NSString *)clientId;
+ (void)setClientId:(NSString *)newClientId;
+ (NSString *)redirectUri;
+ (void)setRedirectUri:(NSString *)newRedirectUri;
+ (NSSet *)scopes;
+ (void)setScopes:(NSSet *)newScopes;
- (void)clearAccountState:(BOOL)clearAccountData;
- (BOOL)mobilePinPolicyConfigured;

/**
 * The account identifier for a given account manager instance.
 */
@property (nonatomic, readonly) NSString *accountIdentifier;

@property (nonatomic, retain) SFOAuthCoordinator *coordinator;
@property (nonatomic, retain) SFIdentityCoordinator *idCoordinator;

/**
 * The auth credentials maintained for this app.
 */
@property (nonatomic, retain) SFOAuthCredentials *credentials;

@property (nonatomic, retain) SFIdentityData *idData;

@end
