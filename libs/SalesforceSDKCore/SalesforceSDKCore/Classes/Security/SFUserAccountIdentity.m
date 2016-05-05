/*
 Copyright (c) 2014, salesforce.com, inc. All rights reserved.
 
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

#import "SFUserAccountIdentity.h"
#import "SFUserAccount.h"
#import "NSString+SFAdditions.h"
#import "SFOAuthCredentials.h"

static NSString * const kUserAccountIdentityUserIdKey = @"userIdKey";
static NSString * const kUserAccountIdentityOrgIdKey = @"orgIdKey";

@implementation SFUserAccountIdentity

@synthesize userId = _userId;
@synthesize orgId = _orgId;

+ (BOOL)supportsSecureCoding {
    return YES;
}

+ (SFUserAccountIdentity *)identityWithUserId:(NSString *)userId orgId:(NSString *)orgId
{
    SFUserAccountIdentity *identity = [[self alloc] initWithUserId:userId orgId:orgId];
    return identity;
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
    if (userId != _userId) {
        NSInteger userIdLen = [userId length];
        NSString *shortUserId = [userId substringToIndex:MIN(15,userIdLen)];
        _userId = [shortUserId copy];
    }
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
        self.userId = [aDecoder decodeObjectOfClass:[NSString class] forKey:kUserAccountIdentityUserIdKey];
        self.orgId = [aDecoder decodeObjectOfClass:[NSString class] forKey:kUserAccountIdentityOrgIdKey];
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
    
    BOOL userIdsEqual = ((objectToCompare.userId == nil && self.userId == nil) || [objectToCompare.userId isEqualToEntityId:self.userId]);
    BOOL orgIdsEqual = ((objectToCompare.orgId == nil && self.orgId == nil) || [objectToCompare.orgId isEqualToEntityId:self.orgId]);
    return userIdsEqual && orgIdsEqual;
}

- (BOOL)matchesCredentials:(SFOAuthCredentials *)credentials {
    return ([[self.userId entityId18] isEqualToString:[credentials.userId entityId18]] && [[self.orgId entityId18] isEqualToString:[credentials.organizationId entityId18]]);
}

- (NSUInteger)hash
{
    return [[NSString stringWithFormat:@"%@_%@", self.userId, self.orgId] hash];
}

- (NSComparisonResult)compare:(SFUserAccountIdentity *)otherIdentity
{
    if (otherIdentity == nil)
        return NSOrderedAscending;
    
    NSString *thisStringToCompare = [NSString stringWithFormat:@"%@_%@", [self.orgId entityId18] , [self.userId entityId18]];
    NSString *otherStringToCompare = [NSString stringWithFormat:@"%@_%@", [otherIdentity.orgId entityId18], [otherIdentity.userId entityId18]];
    return [thisStringToCompare localizedCompare:otherStringToCompare];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@:%p userId:%@ orgId:%@>", [self class], self, self.userId, self.orgId];
}

@end
