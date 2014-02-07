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
static NSString * const kSiteUrlKey = @"siteUrl";
static NSString * const kEnabledKey = @"enabled";

@interface SFCommunityData ()

@end

@implementation SFCommunityData

+ (instancetype)communityData {
    SFCommunityData *data = [[SFCommunityData alloc] init];
    return data;
}

- (void)encodeWithCoder:(NSCoder*)encoder {
    [encoder encodeObject:self.identifier forKey:kIdentifierKey];
    [encoder encodeObject:self.name forKey:kNameKey];
    [encoder encodeObject:self.siteUrl forKey:kSiteUrlKey];
    [encoder encodeBool:self.enabled forKey:kEnabledKey];
}

- (id)initWithCoder:(NSCoder*)decoder {
	self = [super init];
	if (self) {
        self.identifier = [decoder decodeObjectForKey:kIdentifierKey];
        self.name = [decoder decodeObjectForKey:kNameKey];
        self.siteUrl = [decoder decodeObjectForKey:kSiteUrlKey];
        self.enabled = [decoder decodeBoolForKey:kEnabledKey];
	}
	return self;
}

@end
