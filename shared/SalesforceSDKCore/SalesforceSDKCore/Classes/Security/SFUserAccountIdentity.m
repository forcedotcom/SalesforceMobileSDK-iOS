//
//  SFUserAccountIdentity.m
//  SalesforceSDKCore
//
//  Created by Kevin Hawkins on 8/29/14.
//  Copyright (c) 2014 salesforce.com. All rights reserved.
//

#import "SFUserAccountIdentity.h"
#import "SFUserAccount.h"

static NSString * const kUserAccountIdentityUserIdKey = @"userIdKey";
static NSString * const kUserAccountIdentityOrgIdKey = @"orgIdKey";

@implementation SFUserAccountIdentity

@synthesize userId = _userId;
@synthesize orgId = _orgId;

+ (SFUserAccountIdentity *)identityFromUserAccount:(SFUserAccount *)account
{
    if (account.credentials.userId == nil && account.credentials.organizationId == nil)
        return nil;
    
    return [[SFUserAccountIdentity alloc] initWithUserId:account.credentials.userId orgId:account.credentials.organizationId];
}

- (id)initWithUserId:(NSString *)userId orgId:(NSString *)orgId
{
    self = [super init];
    if (self) {
        self.userId = userId;
        self.orgId = orgId;
    }
    return self;
}

- (void)setUserId:(NSString *)userId
{
    NSInteger userIdLen = [userId length];
    NSString *shortUserId = [userId substringToIndex:MIN(15,userIdLen)];
    _userId = [shortUserId copy];
}

#pragma mark - Equality, protocols, etc.

- (id)copyWithZone:(NSZone *)zone
{
    SFUserAccountIdentity *idCopy = [[SFUserAccountIdentity allocWithZone:zone] initWithUserId:self.userId orgId:self.orgId];
    return idCopy;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self) {
        self.userId = [aDecoder decodeObjectForKey:kUserAccountIdentityUserIdKey];
        self.orgId = [aDecoder decodeObjectForKey:kUserAccountIdentityOrgIdKey];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.userId forKey:kUserAccountIdentityUserIdKey];
    [aCoder encodeObject:self.orgId forKey:kUserAccountIdentityOrgIdKey];
}

- (BOOL)isEqual:(id)object
{
    if (object == nil)
        return NO;
    if (self == object)
        return YES;
    
    if (![object isKindOfClass:[SFUserAccountIdentity class]])
        return NO;
    
    SFUserAccountIdentity *objectToCompare = (SFUserAccountIdentity *)object;
    
    BOOL userIdsEqual = ((objectToCompare.userId == nil && self.userId == nil) || [objectToCompare.userId isEqualToString:self.userId]);
    BOOL orgIdsEqual = ((objectToCompare.orgId == nil && self.orgId == nil) || [objectToCompare.orgId isEqualToString:self.orgId]);
    return userIdsEqual && orgIdsEqual;
}

- (NSUInteger)hash
{
    return [[NSString stringWithFormat:@"%@_%@", self.userId, self.orgId] hash];
}

@end
