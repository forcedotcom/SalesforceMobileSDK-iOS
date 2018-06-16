/*
 SFMetadata.h
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

#import <Foundation/Foundation.h>

/**
 * Represents the metadata of a Salesforce object.
 *
 * @see https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/dome_sobject_describe.htm
 */
@interface SFMetadata : NSObject

@property (nonatomic, readonly, assign) BOOL activateable;
@property (nonatomic, readonly, assign) BOOL compactLayoutable;
@property (nonatomic, readonly, assign) BOOL createable;
@property (nonatomic, readonly, assign) BOOL custom;
@property (nonatomic, readonly, assign) BOOL customSetting;
@property (nonatomic, readonly, assign) BOOL deletable;
@property (nonatomic, readonly, assign) BOOL deprecatedAndHidden;
@property (nonatomic, readonly, assign) BOOL feedEnabled;
@property (nonatomic, strong, readonly, nullable) NSArray<NSDictionary *> *childRelationships;
@property (nonatomic, readonly, assign) BOOL hasSubtypes;
@property (nonatomic, readonly, assign) BOOL isSubtype;
@property (nonatomic, strong, readonly, nonnull) NSString *keyPrefix;
@property (nonatomic, strong, readonly, nullable) NSString *label;
@property (nonatomic, strong, readonly, nullable) NSString *labelPlural;
@property (nonatomic, readonly, assign) BOOL layoutable;
@property (nonatomic, readonly, assign) BOOL mergeable;
@property (nonatomic, readonly, assign) BOOL mruEnabled;
@property (nonatomic, strong, readonly, nonnull) NSString *name;
@property (nonatomic, strong, readonly, nullable) NSArray<NSDictionary *> *fields;
@property (nonatomic, strong, readonly, nullable) NSString *networkScopeFieldName;
@property (nonatomic, readonly, assign) BOOL queryable;
@property (nonatomic, readonly, assign) BOOL replicateable;
@property (nonatomic, readonly, assign) BOOL retrieveable;
@property (nonatomic, readonly, assign) BOOL searchLayoutable;
@property (nonatomic, readonly, assign) BOOL searchable;
@property (nonatomic, readonly, assign) BOOL triggerable;
@property (nonatomic, readonly, assign) BOOL undeletable;
@property (nonatomic, readonly, assign) BOOL updateable;
@property (nonatomic, strong, readonly, nonnull) NSDictionary *urls;
@property (nonatomic, strong, readonly, nonnull) NSDictionary *rawData;

/**
 * Creates an instance of this class from its JSON representation.
 *
 * @param data JSON data.
 * @return Instance of this class.
 */
+ (nonnull instancetype)fromJSON:(nonnull NSDictionary *)data;

@end
