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

#import "SFIdentityData+Internal.h"
#import "NSDictionary+SFAdditions.h"

// Private constants

NSString * const kSFIdentityIdUrlKey                      = @"id";
NSString * const kSFIdentityAssertedUserKey               = @"asserted_user";
NSString * const kSFIdentityUserIdKey                     = @"user_id";
NSString * const kSFIdentityOrgIdKey                      = @"organization_id";
NSString * const kSFIdentityUsernameKey                   = @"username";
NSString * const kSFIdentityNicknameKey                   = @"nick_name";
NSString * const kSFIdentityDisplayNameKey                = @"display_name";
NSString * const kSFIdentityEmailKey                      = @"email";
NSString * const kSFIdentityFirstNameKey                  = @"first_name";
NSString * const kSFIdentityLastNameKey                   = @"last_name";
NSString * const kSFIdentityPhotosKey                     = @"photos";
NSString * const kSFIdentityPictureUrlKey                 = @"picture";
NSString * const kSFIdentityThumbnailUrlKey               = @"thumbnail";
NSString * const kSFIdentityUrlsKey                       = @"urls";
NSString * const kSFIdentityEnterpriseSoapUrlKey          = @"enterprise";
NSString * const kSFIdentityMetadataSoapUrlKey            = @"metadata";
NSString * const kSFIdentityPartnerSoapUrlKey             = @"partner";
NSString * const kSFIdentityRestUrlKey                    = @"rest";
NSString * const kSFIdentityRestSObjectsUrlKey            = @"sobjects";
NSString * const kSFIdentityRestSearchUrlKey              = @"search";
NSString * const kSFIdentityRestQueryUrlKey               = @"query";
NSString * const kSFIdentityRestRecentUrlKey              = @"recent";
NSString * const kSFIdentityProfileUrlKey                 = @"profile";
NSString * const kSFIdentityChatterFeedsUrlKey            = @"feeds";
NSString * const kSFIdentityChatterGroupsUrlKey           = @"groups";
NSString * const kSFIdentityChatterUsersUrlKey            = @"users";
NSString * const kSFIdentityChatterFeedItemsUrlKey        = @"feed_items";
NSString * const kSFIdentityIsActiveKey                   = @"active";
NSString * const kSFIdentityUserTypeKey                   = @"user_type";
NSString * const kSFIdentityLanguageKey                   = @"language";
NSString * const kSFIdentityLocaleKey                     = @"locale";
NSString * const kSFIdentityUtcOffsetKey                  = @"utcOffset";
NSString * const kSFIdentityMobilePolicyKey               = @"mobile_policy";
NSString * const kSFIdentityMobileAppPinLengthKey         = @"pin_length";
NSString * const kSFIdentityMobileAppScreenLockTimeoutKey = @"screen_lock";
NSString * const kSFIdentityCustomAttributesKey           = @"custom_attributes";
NSString * const kSFIdentityCustomPermissionsKey          = @"custom_permissions";
NSString * const kSFIdentityLastModifiedDateKey           = @"last_modified_date";

NSString * const kSFIdentityDateFormatString              = @"yyyy-MM-dd'T'HH:mm:ss.SSSZZZ";
NSString * const kIdJsonDictKey                           = @"dictRepresentation";

@implementation SFIdentityData

#pragma mark - init / dealloc / standard overrides

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype)initWithJsonDict:(NSDictionary *)jsonDict
{
    self = [super init];
    if (self) {
        NSAssert(jsonDict != nil, @"Data dictionary must not be nil.");
        NSAssert([jsonDict isKindOfClass:[NSDictionary class]], @"Data dictionary must be a NSDictionary or sublcass");
        self.dictRepresentation = jsonDict;
    }
    
    return self;
}

- (NSString *)description
{
    return [self.dictRepresentation description];
}

#pragma mark - Property getters

- (NSURL *)idUrl
{
    return [NSURL URLWithString:(self.dictRepresentation)[kSFIdentityIdUrlKey]];
}

- (BOOL)assertedUser
{
    id value = [self.dictRepresentation nonNullObjectForKey:kSFIdentityAssertedUserKey];
    return value == nil ? NO : [value boolValue];
}

- (NSString *)userId
{
    return (self.dictRepresentation)[kSFIdentityUserIdKey];
}

- (NSString *)orgId
{
    return (self.dictRepresentation)[kSFIdentityOrgIdKey];
}

- (NSString *)username
{
    return (self.dictRepresentation)[kSFIdentityUsernameKey];
}

- (NSString *)nickname
{
    return [self.dictRepresentation nonNullObjectForKey:kSFIdentityNicknameKey];
}

- (NSString *)displayName
{
    return [self.dictRepresentation nonNullObjectForKey:kSFIdentityDisplayNameKey];
}

- (NSString *)email
{
    return (self.dictRepresentation)[kSFIdentityEmailKey];
}

- (NSString *)firstName
{
    return [self.dictRepresentation nonNullObjectForKey:kSFIdentityFirstNameKey];
}

- (NSString *)lastName
{
    return (self.dictRepresentation)[kSFIdentityLastNameKey];
}

- (NSURL *)pictureUrl
{
    return [self parentExistsOrNilForUrl:kSFIdentityPhotosKey childKey:kSFIdentityPictureUrlKey];
}

- (NSURL *)thumbnailUrl
{
    return [self parentExistsOrNilForUrl:kSFIdentityPhotosKey childKey:kSFIdentityThumbnailUrlKey];
}

- (NSString *)enterpriseSoapUrl
{
    return [self parentExistsOrNilForString:kSFIdentityUrlsKey childKey:kSFIdentityEnterpriseSoapUrlKey];
}

- (NSString *)metadataSoapUrl
{
    return [self parentExistsOrNilForString:kSFIdentityUrlsKey childKey:kSFIdentityMetadataSoapUrlKey];
}

- (NSString *)partnerSoapUrl
{
    return [self parentExistsOrNilForString:kSFIdentityUrlsKey childKey:kSFIdentityPartnerSoapUrlKey];
}

- (NSString *)restUrl
{
    return [self parentExistsOrNilForString:kSFIdentityUrlsKey childKey:kSFIdentityRestUrlKey];
}

- (NSString *)restSObjectsUrl
{
    return [self parentExistsOrNilForString:kSFIdentityUrlsKey childKey:kSFIdentityRestSObjectsUrlKey];
}

- (NSString *)restSearchUrl
{
    return [self parentExistsOrNilForString:kSFIdentityUrlsKey childKey:kSFIdentityRestSearchUrlKey];
}

- (NSString *)restQueryUrl
{
    return [self parentExistsOrNilForString:kSFIdentityUrlsKey childKey:kSFIdentityRestQueryUrlKey];
}

- (NSString *)restRecentUrl
{
    return [self parentExistsOrNilForString:kSFIdentityUrlsKey childKey:kSFIdentityRestRecentUrlKey];
}

- (NSURL *)profileUrl
{
    return [self parentExistsOrNilForUrl:kSFIdentityUrlsKey childKey:kSFIdentityProfileUrlKey];
}

- (NSString *)chatterFeedsUrl
{
    return [self parentExistsOrNilForString:kSFIdentityUrlsKey childKey:kSFIdentityChatterFeedsUrlKey];
}

- (NSString *)chatterGroupsUrl
{
    return [self parentExistsOrNilForString:kSFIdentityUrlsKey childKey:kSFIdentityChatterGroupsUrlKey];
}

- (NSString *)chatterUsersUrl
{
    return [self parentExistsOrNilForString:kSFIdentityUrlsKey childKey:kSFIdentityChatterUsersUrlKey];
}

- (NSString *)chatterFeedItemsUrl
{
    return [self parentExistsOrNilForString:kSFIdentityUrlsKey childKey:kSFIdentityChatterFeedItemsUrlKey];
}

- (BOOL)isActive
{
    if ((self.dictRepresentation)[kSFIdentityIsActiveKey] != nil)
        return [(self.dictRepresentation)[kSFIdentityIsActiveKey] boolValue];
    else
        return NO;
}

- (NSString *)userType
{
    return (self.dictRepresentation)[kSFIdentityUserTypeKey];
}

- (NSString *)language
{
    return (self.dictRepresentation)[kSFIdentityLanguageKey];
}

- (NSString *)locale
{
    return (self.dictRepresentation)[kSFIdentityLocaleKey];
}

- (int)utcOffset
{
    id value = [self.dictRepresentation nonNullObjectForKey:kSFIdentityUtcOffsetKey];
    return value == nil ? -1 : [value intValue];
}

- (BOOL)mobilePoliciesConfigured
{
    id value = [self.dictRepresentation nonNullObjectForKey:kSFIdentityMobilePolicyKey];
    return value == nil ? NO : [value boolValue];
}

- (int)mobileAppPinLength
{
    NSDictionary *mobilePolicy = [self.dictRepresentation nonNullObjectForKey:kSFIdentityMobilePolicyKey];
    if (mobilePolicy != nil) {
        id pinLength = [mobilePolicy nonNullObjectForKey:kSFIdentityMobileAppPinLengthKey];
        return (pinLength != nil ? [pinLength intValue] : 0);
    } else {
        return 0;
    }
}

- (int)mobileAppScreenLockTimeout
{
    NSDictionary *mobilePolicy = [self.dictRepresentation nonNullObjectForKey:kSFIdentityMobilePolicyKey];
    if (mobilePolicy != nil) {
        id screenLockTimeout = [mobilePolicy nonNullObjectForKey:kSFIdentityMobileAppScreenLockTimeoutKey];
        return (screenLockTimeout != nil ? [screenLockTimeout intValue] : 0);
    } else {
        return 0;
    }
}

- (NSDictionary *)customAttributes
{
    NSDictionary *attributes = [self.dictRepresentation nonNullObjectForKey:kSFIdentityCustomAttributesKey];

    if (![attributes isKindOfClass:[NSDictionary class]]) {
        attributes = nil;
    }
    return attributes;
}

- (void)setCustomAttributes:(NSDictionary *)customAttributes
{
    NSMutableDictionary *mutableDict = [self.dictRepresentation mutableCopy];
    mutableDict[kSFIdentityCustomAttributesKey] = customAttributes;
    self.dictRepresentation = [mutableDict copy];
}

- (NSDictionary *)customPermissions
{
    return [self.dictRepresentation nonNullObjectForKey:kSFIdentityCustomPermissionsKey];
}

- (void)setCustomPermissions:(NSDictionary *)customPermissions
{
    NSMutableDictionary *mutableDict = [self.dictRepresentation mutableCopy];
    mutableDict[kSFIdentityCustomPermissionsKey] = customPermissions;
    self.dictRepresentation = [mutableDict copy];
}

- (NSDate *)lastModifiedDate
{
    NSString *value = [self.dictRepresentation nonNullObjectForKey:kSFIdentityLastModifiedDateKey];
    if (value != nil)
        return [[self class] dateFromRfc822String:value];
    else
        return nil;
}

#pragma mark - Private methods

- (NSURL *)parentExistsOrNilForUrl:(NSString *)parentKey childKey:(NSString *)childKey
{
    NSString *value = [self parentExistsOrNilForString:parentKey childKey:childKey];
    return value != nil ? [NSURL URLWithString:value] : nil;
}

- (NSString *)parentExistsOrNilForString:(NSString *)parentKey childKey:(NSString *)childKey
{
    NSDictionary *parentDict = [self.dictRepresentation nonNullObjectForKey:parentKey];
    if (parentDict != nil) {
        NSString *value = [parentDict nonNullObjectForKey:childKey];
        return [value isKindOfClass:[NSString class]] ? value : nil;
    } else {
        return nil;
    }
}

+ (NSDate *)dateFromRfc822String:(NSString *)dateString
{
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    [df setDateFormat:kSFIdentityDateFormatString];
    NSDate *date = [df dateFromString:dateString];
    return date;
}

#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self) {
        self.dictRepresentation = [aDecoder decodeObjectOfClass:[NSDictionary class] forKey:kIdJsonDictKey];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.dictRepresentation forKey:kIdJsonDictKey];
}

@end
