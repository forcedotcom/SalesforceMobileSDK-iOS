//
//  UserAccount.h
//  Salesforce
//
//  Created by Michael Nachbaur on 2/13/11.
//  Copyright 2011 Salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SalesforceOAuth/SFOAuthCredentials.h>

/** Constants for the keys available in the community dictionary returned by
 the `communityWithId:` method below. They map to the keys
 returned by the server endpoint /services/data/vXX.X/connect/communities
 */
extern NSString *kCommunityEntityIdKey;
extern NSString *kCommunityNameKey;
extern NSString *kCommunitySiteUrlKey;

/** User account restrictions
 */
typedef NS_OPTIONS(NSUInteger, SFUserAccountAccessRestriction) {
    SFUserAccountAccessRestrictionNone    = 0,
    SFUserAccountAccessRestrictionChatter = 1 << 0,
    SFUserAccountAccessRestrictionREST    = 1 << 1,
    SFUserAccountAccessRestrictionOther   = 1 << 2,
};

/** Class that represents an `account`. An `account` represents
 a user together with the current community it is logged in.
 */
@interface SFUserAccount : NSObject<NSCoding>

@property (nonatomic, copy) NSSet *accessScopes;
@property (nonatomic, strong) SFOAuthCredentials *credentials;
@property (nonatomic, copy) NSString *email;
@property (nonatomic, copy) NSString *organizationId;
@property (nonatomic, copy) NSString *organizationName;
@property (nonatomic, copy) NSString *fullName;
@property (nonatomic, copy) NSString *userName;
@property (nonatomic) SFUserAccountAccessRestriction accessRestrictions;

// The current community id the user is logged in
@property (nonatomic, copy) NSString *communityId;

// The list of communities (as dictionary)
@property (nonatomic, copy) NSArray *communities;

/** Designated initializer
 @param identifier The user identifier
 @return the account instance
 */
- (id)initWithIdentifier:(NSString*)identifier;

/** Returns the community dictionary for the specified ID
 */
- (NSDictionary*)communityWithId:(NSString*)communityId;

/** Returns YES if the user has an access token and, presumably,
 a valid session.
 */
- (BOOL)isSessionValid;

@end
