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

#import "SFUserAccountManager.h"
#import "SFSDKSafeMutableDictionary.h"
#import "SFSDKIDPAuthClient.h"
#import "SFSDKUserSelectionView.h"

@class SFSDKAuthPreferences;

@interface SFUserAccountManager () <SFSDKOAuthClientSafariViewDelegate,SFSDKOAuthClientWebViewDelegate,SFSDKIDPAuthClientDelegate,
    SFSDKOAuthClientDelegate,SFSDKUserSelectionViewDelegate>

{
    NSRecursiveLock *_accountsLock;
}

@property (nonatomic, strong, nonnull) NSHashTable<id<SFUserAccountManagerDelegate>> *delegates;

/** A map of user accounts by user ID
 */
@property (nonatomic, strong, nonnull) NSMutableDictionary *userAccountMap;

@property (nonatomic, strong, nullable) id<SFUserAccountPersister> accountPersister;

@property (nonatomic, strong, nonnull) SFSDKAuthPreferences *authPreferences;

@property (nonatomic,strong) SFSDKSafeMutableDictionary * _Nonnull oauthClientInstances;
/**
 Executes the given block for each configured delegate.
 @param block The block to execute for each delegate.
 */
- (void)enumerateDelegates:(nullable void (^)(id<SFUserAccountManagerDelegate> _Nonnull))block;

/**
 *
 * @return NSSet enumeration of all account Names
 */
- (nullable NSSet *)allExistingAccountNames;

/** Returns a unique identifier that can be used to create a new Account
 *
 * @param clientId OAuth Client Id
 * @return A unique identifier
 */
- (nonnull NSString *)uniqueUserAccountIdentifier:(nonnull NSString *)clientId;

/** Reload the accounts and reset the state of SFUserAccountManager. Use for tests only
 *
 */
- (void)reload;

/** Get the Account Persister being used.
 * @return SFUserAccountPersister that is used.
 */
- (nullable id<SFUserAccountPersister>)accountPersister;

- (NSString *_Nonnull)encodeUserIdentity:(SFUserAccountIdentity *_Nonnull)userIdentity;

- ( SFUserAccountIdentity *_Nullable)decodeUserIdentity:(NSString *_Nullable)userIdentity;

/**
 Handle an advanced authentication response from the external browser, continuing any
 in-progress adavanced authentication flow.
 @param  url The URL response returned to the app from the external browser.
 @param  options Dictionary of name-value pairs received from open URL
 @return YES if this is request is handled, NO otherwise.
 */
- (BOOL)handleNativeAuthResponse:(NSURL *_Nonnull)url options:(NSDictionary *_Nullable)options;

/**
 Handle an error situation that occured in the IDP flow.
 @param url The URL request from the idp or SP App.
 @param options Dictionary of name-value pairs received from open URL
 @return YES if this is request is handled, NO otherwise.
 */
- (BOOL)handleIdpAuthError:(NSURL *_Nonnull)url options:(NSDictionary *_Nullable)options;

/**
 Handle an IDP initiated auth flow.
 @param url The URL request from the IDP APP.
 @param options Dictionary of name-value pairs received from open URL
 @return YES if this is request is handled, NO otherwise.
 */
- (BOOL)handleIdpInitiatedAuth:(NSURL *_Nonnull)url options:(NSDictionary *_Nullable)options;

/**
 Handle an IDP request initiated from an SP APP.
 @param url The URL request from the SP APP.
 @param options Dictionary of name-value pairs received from open URL
 @return YES if this is request is handled, NO otherwise.
 */
- (BOOL)handleIdpRequest:(NSURL *_Nonnull)url options:(NSDictionary *_Nullable)options;


/**
 Handle an IDP response received from an IDP APP.
 @param  url The URL response from the IDP APP.
 @param  options Dictionary of name-value pairs received from open URL
 @return YES if this is request is handled, NO otherwise.
 */
- (BOOL)handleIdpResponse:(NSURL *_Nonnull)url options:(NSDictionary *_Nullable)options;
@end
