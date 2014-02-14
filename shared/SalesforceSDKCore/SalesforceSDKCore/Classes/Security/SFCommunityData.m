//
//  SFCommunityData.m
//  SalesforceSDKCore
//
//  Created by Jean Bovet on 2/5/14.
//  Copyright (c) 2014 salesforce.com. All rights reserved.
//

#import "SFCommunityData.h"

static NSString * const kIdentifierKey = @"id";
static NSString * const kNameKey = @"name";
static NSString * const kDescriptionKey = @"description";
static NSString * const kSiteUrlKey = @"siteUrl";
static NSString * const kUrlKey = @"url";
static NSString * const kUrlPathPrefixKey = @"urlPathPrefix";
static NSString * const kEnabledKey = @"enabled";
static NSString * const kInvitationsEnabledKey = @"invitationsEnabled";
static NSString * const kSendWelcomeEmailKey = @"sendWelcomeEmail";

@interface SFCommunityData ()

@end

@implementation SFCommunityData

- (void)encodeWithCoder:(NSCoder*)encoder {
    [encoder encodeObject:self.entityId forKey:kIdentifierKey];
    [encoder encodeObject:self.name forKey:kNameKey];
    [encoder encodeObject:self.description forKey:kDescriptionKey];
    [encoder encodeObject:self.siteUrl forKey:kSiteUrlKey];
    [encoder encodeObject:self.url forKey:kUrlKey];
    [encoder encodeObject:self.urlPathPrefix forKey:kUrlPathPrefixKey];
    [encoder encodeBool:self.enabled forKey:kEnabledKey];
    [encoder encodeBool:self.invitationsEnabled forKey:kInvitationsEnabledKey];
    [encoder encodeBool:self.sendWelcomeEmail forKey:kSendWelcomeEmailKey];
}

- (id)initWithCoder:(NSCoder*)decoder {
	self = [super init];
	if (self) {
        self.entityId = [decoder decodeObjectForKey:kIdentifierKey];
        self.name = [decoder decodeObjectForKey:kNameKey];
        self.description = [decoder decodeObjectForKey:kDescriptionKey];
        self.url = [decoder decodeObjectForKey:kUrlKey];
        self.urlPathPrefix = [decoder decodeObjectForKey:kUrlPathPrefixKey];
        self.siteUrl = [decoder decodeObjectForKey:kSiteUrlKey];
        self.enabled = [decoder decodeBoolForKey:kEnabledKey];
        self.invitationsEnabled = [decoder decodeBoolForKey:kInvitationsEnabledKey];
        self.sendWelcomeEmail = [decoder decodeBoolForKey:kSendWelcomeEmailKey];
	}
	return self;
}

@end
