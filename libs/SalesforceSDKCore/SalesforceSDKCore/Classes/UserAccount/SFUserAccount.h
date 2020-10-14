/*
 Copyright (c) 2012-present, salesforce.com, inc. All rights reserved.
 
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
#import <UIKit/UIKit.h>
#import <SalesforceSDKCore/SFUserAccountConstants.h>
#import <SalesforceSDKCore/SFIdentityData.h>
#import <SalesforceSDKCore/SalesforceSDKConstants.h>

NS_ASSUME_NONNULL_BEGIN

@class SFUserAccountIdentity;
@class SFOAuthCredentials;

/**
 Enumeration of the potential login states of the user account.
 */
typedef NS_ENUM(NSUInteger, SFUserAccountLoginState) {
    /**
     User account is not logged in.
     */
    SFUserAccountLoginStateNotLoggedIn = 0,
    
    /**
     User account is logged in.
     */
    SFUserAccountLoginStateLoggedIn,
    
    /**
     User account is in the process of logging out.
     */
    SFUserAccountLoginStateLoggingOut,
} NS_SWIFT_NAME(UserAccount.LoginState);

/** Class that represents an `account`. An `account` represents
 a user together with the current community it is logged in.
 */
NS_SWIFT_NAME(UserAccount)
@interface SFUserAccount : NSObject <NSSecureCoding>

/** The access scopes for this user
 */
@property (nonatomic, copy, nullable) NSSet<NSString*> *accessScopes;

/**
 The unique identifier for this account.
 */
@property (nonatomic, readonly) SFUserAccountIdentity *accountIdentity;

/** The credentials associated with this user
 */
@property (nonatomic, strong) SFOAuthCredentials *credentials;

/** The identity data associated with this user
 */
@property (nonatomic, strong) SFIdentityData *idData;

/** The user's photo. Usually store a thumbnail of the user.
To set this property use `setPhoto:completion:`
 */
@property (nonatomic, strong, nullable, readonly) UIImage *photo;

/** The access restriction associated with this user
 */
@property (nonatomic) SFUserAccountAccessRestriction accessRestrictions;

/** Returns YES if the user has an access token and, presumably,
 a valid session.
 */
@property (nonatomic, readonly, getter = isSessionValid) BOOL sessionValid;

/** Indicates if this account was deleted.  Returns `YES` if this account was deleted since being created.
 */
@property (nonatomic, readonly, getter = isUserDeleted) BOOL userDeleted;


/** Indicates this user's current login state.
 */
@property (nonatomic, readonly, assign) SFUserAccountLoginState loginState;

/** Initialize with SFOAuthCredentials credentials
 @param credentials The credentials to link with the SFUserAccount.
 @return the account instance
 */
- (instancetype)initWithCredentials:(SFOAuthCredentials *) credentials NS_DESIGNATED_INITIALIZER;

/** Set object in customData dictionary
 
 @param object The object to store, must be NSCoding enabled
 @param key An NSCopying key to store the object at
 */
- (void)setCustomDataObject:(id<NSCoding>)object forKey:(id<NSCopying>)key;

/** Remove a custom data object for a key
 
 @param key The key for the object to remove
 */
- (void)removeCustomDataObjectForKey:(id)key;

/** Retrieve the object stored in the custom data dictionary
 @param key The key for the object to retrieve
 @return The object for a particular key
 */
- (nullable id)customDataObjectForKey:(id)key;

/** Sets the user's photo.
 @param photo The user photo, usually the thumbnail of the user.
 @param completion Optional callback block invoked when the photo has been set. If not set, an error is returned.
 */
- (void)setPhoto:(UIImage*_Nullable)photo completion:(void (^ __nullable)(NSError* _Nullable))completion;

/** Function that returns a key that uniquely identifies this user account for the
 given scope. Note that if you use SFUserAccountScopeGlobal,
 the same key will be returned regardless of the user account.
 
 @param user The user
 @param scope The scope
 @return a key identifying this user account for the specified scope
 */
NSString *_Nullable SFKeyForUserAndScope(SFUserAccount * _Nullable user, SFUserAccountScope scope);

/** Function that returns a key that uniquely identifies this user,org & community for the
 given scope. Note that if you use SFUserAccountScopeGlobal,
 the same key will be returned regardless of the user account.
 
 @param userId The user identifier
 @param orgId The org identifier
 @param communityId The community id identifier
 @param scope The scope
 @return a key identifying this user account for the specified scope
 */
NSString *_Nullable SFKeyForUserIdAndScope(NSString *_Nullable userId,NSString *_Nullable orgId, NSString *_Nullable communityId, SFUserAccountScope scope);

/** Function that returns a key for scope SFUserAccountScopeGlobal,
  @return a key identifying this scope for the specified scope
 */
NSString *SFKeyForGlobalScope(void);

@end

NS_ASSUME_NONNULL_END
