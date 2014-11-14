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

@synthesize description;

- (void)encodeWithCoder:(NSCoder*)encoder {
    [encoder encodeObject:self.entityId forKey:kIdentifierKey];
    [encoder encodeObject:self.name forKey:kNameKey];
    [encoder encodeObject:self.descriptionText forKey:kDescriptionKey];
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
        self.descriptionText = [decoder decodeObjectForKey:kDescriptionKey];
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
