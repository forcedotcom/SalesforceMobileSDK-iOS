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

#import "SFIdentityData.h"

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
NSString * const kSFIdentityLastModifiedDateKey           = @"last_modified_date";

NSString * const kSFIdentityDateFormatString              = @"yyyy-MM-dd'T'HH:mm:ss.SSSZZZ";
NSString * const kIdJsonDictKey                           = @"dictRepresentation";

/**
 * Private interface
 */
@interface SFIdentityData ()

/**
 * Creates an NSDate object from an RFC 822-formatted date string.
 * @param dateString The date string to parse into an NSDate.
 * @return The NSDate representation of the date string.
 */
+ (NSDate *)dateFromRfc822String:(NSString *)dateString;

/**
 * Returns the URL configured in the sub-object of the parent, or nil if the parent
 * object does not exist.
 * @param parentKey The data key associated with the parent object.
 * @param childKey The data key associated with the child object where the URL is configured.
 * @return The NSURL representation configured in the child object, or nil if the parent
 *         does not exist.
 */
- (NSURL *)parentExistsOrNilForUrl:(NSString *)parentKey childKey:(NSString *)childKey;

/**
 * Returns the NSString configured in the sub-object of the parent, or nil if the parent
 * object does not exist.
 * @param parentKey The data key associated with the parent object.
 * @param childKey The data key associated with the child object where the string is configured.
 * @return The NSString representation configured in the child object, or nil if the parent
 *         does not exist.
 */
- (NSString *)parentExistsOrNilForString:(NSString *)parentKey childKey:(NSString *)childKey;

@end

@implementation SFIdentityData

@synthesize dictRepresentation = _dictRepresentation;

#pragma mark - init / dealloc / standard overrides

- (id)initWithJsonDict:(NSDictionary *)jsonDict
{
    self = [super init];
    if (self) {
        NSAssert(jsonDict != nil, @"Data dictionary must not be nil.");
        _dictRepresentation = jsonDict;
    }
    
    return self;
}

- (void)dealloc
{
    SFRelease(_dictRepresentation);
    
}

- (NSString *)description
{
    return [self.dictRepresentation description];
}

#pragma mark - Property getters

- (NSURL *)idUrl
{
    return [NSURL URLWithString:[self.dictRepresentation objectForKey:kSFIdentityIdUrlKey]];
}

- (BOOL)assertedUser
{
    if ([self.dictRepresentation objectForKey:kSFIdentityAssertedUserKey] != nil)
        return [[self.dictRepresentation objectForKey:kSFIdentityAssertedUserKey] boolValue];
    else
        return NO;
}

- (NSString *)userId
{
    return [self.dictRepresentation objectForKey:kSFIdentityUserIdKey];
}

- (NSString *)orgId
{
    return [self.dictRepresentation objectForKey:kSFIdentityOrgIdKey];
}

- (NSString *)username
{
    return [self.dictRepresentation objectForKey:kSFIdentityUsernameKey];
}

- (NSString *)nickname
{
    return [self.dictRepresentation objectForKey:kSFIdentityNicknameKey];
}

- (NSString *)displayName
{
    return [self.dictRepresentation objectForKey:kSFIdentityDisplayNameKey];
}

- (NSString *)email
{
    return [self.dictRepresentation objectForKey:kSFIdentityEmailKey];
}

- (NSString *)firstName
{
    return [self.dictRepresentation objectForKey:kSFIdentityFirstNameKey];
}

- (NSString *)lastName
{
    return [self.dictRepresentation objectForKey:kSFIdentityLastNameKey];
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
    if ([self.dictRepresentation objectForKey:kSFIdentityIsActiveKey] != nil)
        return [[self.dictRepresentation objectForKey:kSFIdentityIsActiveKey] boolValue];
    else
        return NO;
}

- (NSString *)userType
{
    return [self.dictRepresentation objectForKey:kSFIdentityUserTypeKey];
}

- (NSString *)language
{
    return [self.dictRepresentation objectForKey:kSFIdentityLanguageKey];
}

- (NSString *)locale
{
    return [self.dictRepresentation objectForKey:kSFIdentityLocaleKey];
}

- (int)utcOffset
{
    if ([self.dictRepresentation objectForKey:kSFIdentityUtcOffsetKey] != nil)
        return [[self.dictRepresentation objectForKey:kSFIdentityUtcOffsetKey] intValue];
    else
        return -1;
}

- (BOOL)mobilePoliciesConfigured
{
    return ([self.dictRepresentation objectForKey:kSFIdentityMobilePolicyKey] != nil);
}

- (int)mobileAppPinLength
{
    NSDictionary *mobilePolicy = [self.dictRepresentation objectForKey:kSFIdentityMobilePolicyKey];
    if (mobilePolicy != nil) {
        id pinLength = [mobilePolicy objectForKey:kSFIdentityMobileAppPinLengthKey];
        return (pinLength != nil ? [pinLength intValue] : 0);
    } else {
        return 0;
    }
}

- (int)mobileAppScreenLockTimeout
{
    NSDictionary *mobilePolicy = [self.dictRepresentation objectForKey:kSFIdentityMobilePolicyKey];
    if (mobilePolicy != nil) {
        id screenLockTimeout = [mobilePolicy objectForKey:kSFIdentityMobileAppScreenLockTimeoutKey];
        return (screenLockTimeout != nil ? [screenLockTimeout intValue] : -1);
    } else {
        return -1;
    }
}

- (NSDictionary *)customAttributes
{
    return [self.dictRepresentation objectForKey:kSFIdentityCustomAttributesKey];
}

- (NSDate *)lastModifiedDate
{
    if ([self.dictRepresentation objectForKey:kSFIdentityLastModifiedDateKey] != nil)
        return [[self class] dateFromRfc822String:[self.dictRepresentation objectForKey:kSFIdentityLastModifiedDateKey]];
    else
        return nil;
}

#pragma mark - Private methods

- (NSURL *)parentExistsOrNilForUrl:(NSString *)parentKey childKey:(NSString *)childKey
{
    NSDictionary *parentDict = [self.dictRepresentation objectForKey:parentKey];
    if (parentDict != nil)
        return [NSURL URLWithString:[parentDict objectForKey:childKey]];
    else
        return nil;
}

- (NSString *)parentExistsOrNilForString:(NSString *)parentKey childKey:(NSString *)childKey
{
    NSDictionary *parentDict = [self.dictRepresentation objectForKey:parentKey];
    if (parentDict != nil)
        return [parentDict objectForKey:childKey];
    else
        return nil;
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
        _dictRepresentation = [aDecoder decodeObjectForKey:kIdJsonDictKey];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:_dictRepresentation forKey:kIdJsonDictKey];
}

@end
