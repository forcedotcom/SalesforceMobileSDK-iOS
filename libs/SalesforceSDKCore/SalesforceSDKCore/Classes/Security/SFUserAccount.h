/*
 Copyright (c) 2012-2014, salesforce.com, inc. All rights reserved.
 
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
#import "SFUserAccountConstants.h"

NS_ASSUME_NONNULL_BEGIN

@class SFCommunityData;
@class SFUserAccountIdentity;
@class SFIdentityData;
@class SFOAuthCredentials;

/** Class that represents an `account`. An `account` represents
 a user together with the current community it is logged in.
 */
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

/** The URL that can be used to invoke any API
 on the server-side. This URL takes into account the
 current community if available (see `communityId`).
 */
@property (nonatomic, copy, readonly) NSURL *apiUrl;

/** The user's email
 */
@property (nonatomic, copy, nullable) NSString *email;

/** The user's organization name
 */
@property (nonatomic, copy) NSString *organizationName;

/** The user's full name
 */
@property (nonatomic, copy) NSString *fullName;

/** The user's name
 */
@property (nonatomic, copy) NSString *userName;

/** The user's photo. Usually store a thumbnail of the user.
 Note: the consumer of this class must set the photo at least once,
 because this class doesn't fetch it from the server but
 only stores it locally on the disk.
 */
@property (nonatomic, strong, nullable) UIImage *photo;

/** The access restriction associated with this user
 */
@property (nonatomic) SFUserAccountAccessRestriction accessRestrictions;

/** The current community id the user is logged in
 */
@property (nonatomic, copy, nullable) NSString *communityId;

/** The list of communities (as SFCommunityData item)
 */
@property (nonatomic, copy, nullable) NSArray<SFCommunityData *> *communities;

/** Indicates whether or not the receiver represents a guest user account.
 */
@property (nonatomic, readonly, getter = isGuestUser) BOOL guestUser;

/** Returns YES if the user has an access token and, presumably,
 a valid session.
 */
@property (nonatomic, readonly, getter = isSessionValid) BOOL sessionValid;

/** Indicates if this account was deleted.  Returns `YES` if this account was deleted since being created.
 */
@property (nonatomic, readonly, getter = isUserDeleted) BOOL userDeleted;

/** Returns YES if the user is a temporary user.
 Note: a temporary user is created when a new user
 is requested, for example during the login into
 a new org, and is replaced by the real user once
 the login is finished.
 */
@property (nonatomic, readonly, getter = isTemporaryUser) BOOL temporaryUser;

/** Returns YES if the user is an anonymous user.
 Note: an anonymous user is a user that doesn't require
 credentials towards a server.
 */
@property (nonatomic, readonly, getter = isAnonymousUser) BOOL anonymousUser;

/** Designated initializer
 @param identifier The user identifier
 @return the account instance
 */
- (instancetype)initWithIdentifier:(NSString*)identifier;

/** Designated initializer to construct a user account with a guest user account.
 @return The guest user account instance.
 */
- (instancetype)initWithGuestUser NS_DESIGNATED_INITIALIZER;

/** Initialize with identifier and client id
 @param identifier The user identifier
 @param clientId The client id
 @return the account instance
 */
- (instancetype)initWithIdentifier:(NSString*)identifier clientId:(NSString*)clientId NS_DESIGNATED_INITIALIZER;

/** Returns the community API url for a particular
 community ID if it exists in the communities array
 
 @param communityId The ID of the community
 @return The URL of the API endpoint for that community
 */
- (nullable NSURL*)communityUrlWithId:(NSString *)communityId;

/** Returns the community dictionary for the specified ID
 @param communityId The ID of the community
 @return The dictionary for the given community
 */
- (nullable SFCommunityData*)communityWithId:(NSString*)communityId;

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

/** Function that returns a key that uniquely identifies this user account for the
 given scope. Note that if you use SFUserAccountScopeGlobal,
 the same key will be returned regardless of the user account.
 
 @param user The user
 @param scope The scope
 @return a key identifying this user account for the specified scope
 */
NSString *_Nullable SFKeyForUserAndScope(SFUserAccount * _Nullable user, SFUserAccountScope scope);

@end

NS_ASSUME_NONNULL_END
