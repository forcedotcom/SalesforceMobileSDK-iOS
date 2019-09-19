/*
 SFMetadata.m
 SmartSync
 
 Created by Bharath Hariharan on 5/24/18.
 
 Copyright (c) 2018-present, salesforce.com, inc. All rights reserved.
 
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

#import "SFMetadata.h"

static NSString * const kSFActivateable = @"activateable";
static NSString * const kSFCompactLayoutable = @"compactLayoutable";
static NSString * const kSFCreateable = @"createable";
static NSString * const kSFCustom = @"custom";
static NSString * const kSFCustomSetting = @"customSetting";
static NSString * const kSFDeletable = @"deletable";
static NSString * const kSFDeprecatedAndHidden = @"deprecatedAndHidden";
static NSString * const kSFFeedEnabled = @"feedEnabled";
static NSString * const kSFChildRelationships = @"childRelationships";
static NSString * const kSFHasSubtypes = @"hasSubtypes";
static NSString * const kSFIsSubtype = @"isSubtype";
static NSString * const kSFKeyPrefix = @"keyPrefix";
static NSString * const kSFLabel = @"label";
static NSString * const kSFLabelPlural = @"labelPlural";
static NSString * const kSFLayoutable = @"layoutable";
static NSString * const kSFMergeable = @"mergeable";
static NSString * const kSFMruEnabled = @"mruEnabled";
static NSString * const kSFName = @"name";
static NSString * const kSFFields = @"fields";
static NSString * const kSFNetworkScopeFieldName = @"networkScopeFieldName";
static NSString * const kSFQueryable = @"queryable";
static NSString * const kSFReplicateable = @"replicateable";
static NSString * const kSFRetrieveable = @"retrieveable";
static NSString * const kSFSearchLayoutable = @"searchLayoutable";
static NSString * const kSFSearchable = @"searchable";
static NSString * const kSFTriggerable = @"triggerable";
static NSString * const kSFUndeletable = @"undeletable";
static NSString * const kSFUpdateable = @"updateable";
static NSString * const kSFUrls = @"urls";

@interface SFMetadata ()

@property (nonatomic, readwrite, assign) BOOL activateable;
@property (nonatomic, readwrite, assign) BOOL compactLayoutable;
@property (nonatomic, readwrite, assign) BOOL createable;
@property (nonatomic, readwrite, assign) BOOL custom;
@property (nonatomic, readwrite, assign) BOOL customSetting;
@property (nonatomic, readwrite, assign) BOOL deletable;
@property (nonatomic, readwrite, assign) BOOL deprecatedAndHidden;
@property (nonatomic, readwrite, assign) BOOL feedEnabled;
@property (nonatomic, strong, readwrite) NSArray<NSDictionary *> *childRelationships;
@property (nonatomic, readwrite, assign) BOOL hasSubtypes;
@property (nonatomic, readwrite, assign) BOOL isSubtype;
@property (nonatomic, strong, readwrite) NSString *keyPrefix;
@property (nonatomic, strong, readwrite) NSString *label;
@property (nonatomic, strong, readwrite) NSString *labelPlural;
@property (nonatomic, readwrite, assign) BOOL layoutable;
@property (nonatomic, readwrite, assign) BOOL mergeable;
@property (nonatomic, readwrite, assign) BOOL mruEnabled;
@property (nonatomic, strong, readwrite) NSString *name;
@property (nonatomic, strong, readwrite) NSArray<NSDictionary *> *fields;
@property (nonatomic, strong, readwrite) NSString *networkScopeFieldName;
@property (nonatomic, readwrite, assign) BOOL queryable;
@property (nonatomic, readwrite, assign) BOOL replicateable;
@property (nonatomic, readwrite, assign) BOOL retrieveable;
@property (nonatomic, readwrite, assign) BOOL searchLayoutable;
@property (nonatomic, readwrite, assign) BOOL searchable;
@property (nonatomic, readwrite, assign) BOOL triggerable;
@property (nonatomic, readwrite, assign) BOOL undeletable;
@property (nonatomic, readwrite, assign) BOOL updateable;
@property (nonatomic, strong, readwrite) NSDictionary *urls;
@property (nonatomic, strong, readwrite) NSDictionary *rawData;

@end

@implementation SFMetadata

+ (instancetype)fromJSON:(NSDictionary *)data {
    SFMetadata *metadata = nil;
    if (data) {
        metadata = [[SFMetadata alloc] init];
        metadata.rawData = data;
        metadata.activateable = data[kSFActivateable];
        metadata.compactLayoutable = data[kSFCompactLayoutable];
        metadata.createable = data[kSFCreateable];
        metadata.custom = data[kSFCustom];
        metadata.customSetting = data[kSFCustomSetting];
        metadata.deletable = data[kSFDeletable];
        metadata.deprecatedAndHidden = data[kSFDeprecatedAndHidden];
        metadata.feedEnabled = data[kSFFeedEnabled];
        metadata.childRelationships = data[kSFChildRelationships];
        metadata.hasSubtypes = data[kSFHasSubtypes];
        metadata.isSubtype = data[kSFIsSubtype];
        metadata.keyPrefix = data[kSFKeyPrefix];
        metadata.label = data[kSFLabel];
        metadata.labelPlural = data[kSFLabelPlural];
        metadata.layoutable = data[kSFLayoutable];
        metadata.mergeable = data[kSFMergeable];
        metadata.mruEnabled = data[kSFMruEnabled];
        metadata.name = data[kSFName];
        metadata.fields = data[kSFFields];
        metadata.networkScopeFieldName = data[kSFNetworkScopeFieldName];
        metadata.queryable = data[kSFQueryable];
        metadata.replicateable = data[kSFReplicateable];
        metadata.retrieveable = data[kSFRetrieveable];
        metadata.searchLayoutable = data[kSFSearchLayoutable];
        metadata.searchable = data[kSFSearchable];
        metadata.triggerable = data[kSFTriggerable];
        metadata.undeletable = data[kSFUndeletable];
        metadata.updateable = data[kSFUpdateable];
        metadata.urls = data[kSFUrls];
    }
    return metadata;
}

@end
