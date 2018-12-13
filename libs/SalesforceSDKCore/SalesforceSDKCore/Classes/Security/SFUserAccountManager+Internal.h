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
#import "SFSDKLoginFlowSelectionView.h"
#import "SFSDKAlertView.h"
#import "SFSDKAuthErrorManager.h"

@class SFSDKAuthPreferences;

@interface SFUserAccountManager () <SFSDKOAuthClientSafariViewDelegate,SFSDKOAuthClientWebViewDelegate,SFSDKIDPAuthClientDelegate,
    SFSDKOAuthClientDelegate,SFSDKUserSelectionViewDelegate,SFSDKLoginFlowSelectionViewDelegate>

{
    NSRecursiveLock *_accountsLock;
}

@property (nonatomic, strong, nonnull) NSHashTable<id<SFUserAccountManagerDelegate>> *delegates;

/** A map of user accounts by user ID
 */
@property (nonatomic, strong, nonnull) NSMutableDictionary *userAccountMap;

/** instance of accountPersister
 *
 */
@property (nonatomic, strong, nullable) id<SFUserAccountPersister> accountPersister;

/** instance of authPreferences
 *
 */
@property (nonatomic, strong, nonnull) SFSDKAuthPreferences *authPreferences;

/** SFSDKAlertView used to wrap display of SFSDKMessage using an AlertController.
 *
 */
@property (nonatomic, strong, nullable) SFSDKAlertView *alertView;

/** SFSDKAlertView used to wrap display of SFSDKMessage using an AlertController.
 *
 */
@property (nonatomic, strong, nullable) SFSDKAuthErrorManager *errorManager;

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

/** Check if user accounts exist for a given org.
 *
 * @param orgId for org
 * @return YES if accounts exist, otherwise NO.
 */
- (BOOL)orgHasLoggedInUsers:(nonnull NSString *)orgId;

/** Get the Account Persister being used.
 * @return SFUserAccountPersister that is used.
 */
- (nullable id<SFUserAccountPersister>)accountPersister;

/**
 * @return SFOAuthCredentials
 */
- (SFOAuthCredentials *_Nonnull)newClientCredentials;

/**
 * @param userIdentity to use for encoding to String
 * @return NSString userid:orgid
 */
- (NSString *_Nonnull)encodeUserIdentity:(SFUserAccountIdentity *_Nonnull)userIdentity;

/**
 * @param userIdentityEncoded encoded string
 * @return SFUserAccountIdentity decoded from string
 */
- (SFUserAccountIdentity *_Nullable)decodeUserIdentity:(NSString *_Nullable)userIdentityEncoded;

/**
 * @param client to remove from cache.
 */
- (void)disposeOAuthClient:(SFSDKOAuthClient *_Nonnull)client;

/**
 * @param credentials to use to init client
 * @param completionBlock to use for client
 * @param failureBlock  to use for client
 * @return SFSDKIDPAuthClient instance
 */
- (SFSDKIDPAuthClient *_Nonnull)fetchIDPAuthClient:(SFOAuthCredentials *_Nonnull)credentials completion:(SFUserAccountManagerSuccessCallbackBlock _Nullable)completionBlock failure:(SFUserAccountManagerFailureCallbackBlock _Nullable)failureBlock;

/**
 * @param credentials  to use to init client
 * @param completionBlock to use for the client
 * @param failureBlock  to use for the client
 * @return SFSDKOAuthClient instance
 */
- (SFSDKOAuthClient *_Nonnull)fetchOAuthClient:(SFOAuthCredentials *_Nonnull)credentials completion:(SFUserAccountManagerSuccessCallbackBlock _Nullable)completionBlock failure:(SFUserAccountManagerFailureCallbackBlock _Nullable)failureBlock;
@end
