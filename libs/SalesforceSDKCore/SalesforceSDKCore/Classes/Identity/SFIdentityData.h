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

/**
 * The data structure for the identity data that's retrieved from the Salesforce service.
 * @see SFIdentityCoordinator
 */
@interface SFIdentityData : NSObject <NSSecureCoding>

/**
 * The NSDictionary representation of this identity data.
 */
@property (nonnull, strong, nonatomic, readonly) NSDictionary *dictRepresentation;

/**
 * The ID URL.
 */
@property (nonnull, strong, nonatomic, readonly) NSURL *idUrl;

/**
 * Whether or not this is the asserted user for this session.
 */
@property (readonly) BOOL assertedUser;

/**
 * The User ID of the associated user.
 */
@property (nonnull, strong, nonatomic, readonly) NSString *userId;

/**
 * The Organization ID of the associated user.
 */
@property (nonnull, strong, nonatomic, readonly) NSString *orgId;

/**
 * The username of the associated user.
 */
@property (nonnull, strong, nonatomic, readonly) NSString *username;

/**
 * The nickname of the associated user.
 */
@property (nonnull, strong, nonatomic, readonly) NSString *nickname;

/**
 * The display name of the associated user.
 */
@property (nonnull, strong, nonatomic, readonly) NSString *displayName;

/**
 * The email address of the associated user.
 */
@property (nonnull, strong, nonatomic, readonly) NSString *email;

/**
 * The first name of the user.
 */
@property (nonnull, strong, nonatomic, readonly) NSString *firstName;

/**
 * The last name of the user.
 */
@property (nonnull, strong, nonatomic, readonly) NSString *lastName;

/**
 * The URL to retrieve the user's picture.
 */
@property (nonnull, strong, nonatomic, readonly) NSURL *pictureUrl;

/**
 * The URL to retrieve a thumbnail picture for the user.
 */
@property (nullable, strong, nonatomic, readonly) NSURL *thumbnailUrl;

/**
 * The enterprise SOAP API URL string for this user.
 * Note: API URLs require replacement of the `version` token with a valid API version string.
 */
@property (nullable, strong, nonatomic, readonly) NSString *enterpriseSoapUrl;

/**
 * The metadata SOAP API URL string for this user.
 * Note: API URLs require replacement of the `version` token with a valid API version string.
 */
@property (nullable, strong, nonatomic, readonly) NSString *metadataSoapUrl;

/**
 * The partner SOAP API URL string for this user.
 * Note: API URLs require replacement of the `version` token with a valid API version string.
 */
@property (nullable, strong, nonatomic, readonly) NSString *partnerSoapUrl;

/**
 * The REST API URL string entry point for this user.
 * Note: API URLs require replacement of the `version` token with a valid API version string.
 */
@property (nullable, strong, nonatomic, readonly) NSString *restUrl;

/**
 * The REST endpoint string for SObjects.
 * Note: API URLs require replacement of the `version` token with a valid API version string.
 */
@property (nullable, strong, nonatomic, readonly) NSString *restSObjectsUrl;

/**
 * The REST endpoint string for search.
 * Note: API URLs require replacement of the `version` token with a valid API version string.
 */
@property (nullable, strong, nonatomic, readonly) NSString *restSearchUrl;

/**
 * The REST endpoint string for queries.
 * Note: API URLs require replacement of the `version` token with a valid API version string.
 */
@property (nullable, strong, nonatomic, readonly) NSString *restQueryUrl;

/**
 * The REST endpoint string for recent activity.
 * Note: API URLs require replacement of the `version` token with a valid API version string.
 */
@property (nullable, strong, nonatomic, readonly) NSString *restRecentUrl;

/**
 * The user profile URL.
 */
@property (nullable, strong, nonatomic, readonly) NSURL *profileUrl;

/**
 * The URL string for Chatter feeds.
 * Note: API URLs require replacement of the `version` token with a valid API version string.
 */
@property (nullable, strong, nonatomic, readonly) NSString *chatterFeedsUrl;

/**
 * The URL string for Chatter groups.
 * Note: API URLs require replacement of the `version` token with a valid API version string.
 */
@property (nullable, strong, nonatomic, readonly) NSString *chatterGroupsUrl;

/**
 * The URL string for Chatter users.
 * Note: API URLs require replacement of the `version` token with a valid API version string.
 */
@property (nullable, strong, nonatomic, readonly) NSString *chatterUsersUrl;

/**
 * The URL string for Chatter feed items.
 * Note: API URLs require replacement of the `version` token with a valid API version string.
 */
@property (nullable, strong, nonatomic, readonly) NSString *chatterFeedItemsUrl;

/**
 * Whether or not this user is active.
 */
@property (readonly) BOOL isActive;

/**
 * The user type.
 */
@property (nonnull, strong, nonatomic, readonly) NSString *userType;

/**
 * The user's configured language.
 */
@property (nonnull, strong, nonatomic, readonly) NSString *language;

/**
 * The user's configured locale.
 */
@property (nonnull, strong, nonatomic, readonly) NSString *locale;

/**
 * The UTC offset for this user.
 */
@property (readonly) int utcOffset;

/**
 * Whether or not any additional mobile security policies have been configured
 * for this application.
 */
@property (readonly) BOOL mobilePoliciesConfigured;

/**
 * The length of the PIN code, if it's required.  Defaults to 0 if not set, but
 * querying mobilePoliciesConfigured is recommended to validate that policies
 * are set.
 */
@property (readonly) int mobileAppPinLength;

/**
 * The length of time in minutes before the app will be locked, if it's required.
 * Defaults to -1 if not set, but querying mobilePoliciesConfigured is recommended
 * to validate that policies are set.
 */
@property (readonly) int mobileAppScreenLockTimeout;

/**
 * An optional dictionary of custom attributes defined on the Connected App.
 */
@property (nullable, strong, nonatomic, readonly) NSDictionary *customAttributes;

/**
 * An optional dictionary of custom permissions defined on the Connected App.
 */
@property (nullable, strong, nonatomic, readonly) NSDictionary *customPermissions;

/**
 * The date this record was last modified.
 */
@property (nonnull, strong, nonatomic, readonly) NSDate *lastModifiedDate;

/**
 * Designated initializer for creating an instance of the SFIdentityData object.
 * @param jsonDict The JSON dictionary containing the user data.
 */
- (nonnull instancetype)initWithJsonDict:(nonnull NSDictionary *)jsonDict;

@end
