/*
 Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.
 
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

#import "SFParentInfo.h"
#import "SFSmartSyncConstants.h"

NSString * const kSFParentInfoSObjectType = @"sobjectType";
NSString * const kSFParentInfoSoupName = @"soupName";
NSString * const kSFParentInfoIdFieldName = @"idFieldName";
NSString * const kSFParentInfoModifificationDateFieldName = @"modificationDateFieldName";

@interface SFParentInfo ()

@property (nonatomic, readwrite) NSString* sobjectType;
@property (nonatomic, readwrite) NSString* idFieldName;
@property (nonatomic, readwrite) NSString* modificationDateFieldName;
@property (nonatomic, readwrite) NSString* soupName;

@end

@implementation SFParentInfo

- (instancetype)initWithSObjectType:(NSString *)sobjectType soupName:(NSString *)soupName idFieldName:(NSString *)idFieldName modificationDateFieldName:(NSString *)modificationDateFieldName {
    self = [self init];
    if (self) {
        self.sobjectType = sobjectType;
        self.idFieldName = idFieldName;
        self.modificationDateFieldName = modificationDateFieldName;
        self.soupName = soupName;
    }
    return self;
}

#pragma mark - Factory methods

+ (SFParentInfo *)newWithSObjectType:(NSString *)sobjectType
                            soupName:(NSString *)soupName
{
    return [SFParentInfo newWithSObjectType:sobjectType soupName:soupName idFieldName:kId modificationDateFieldName:kLastModifiedDate];
}


+ (SFParentInfo *)newWithSObjectType:(NSString *)sobjectType soupName:(NSString *)soupName idFieldName:(NSString *)idFieldName modificationDateFieldName:(NSString *)modificationDateFieldName {
    return [[SFParentInfo alloc] initWithSObjectType:sobjectType soupName:soupName idFieldName:idFieldName modificationDateFieldName:modificationDateFieldName];
}

+ (SFParentInfo*) newFromDict:(NSDictionary*)dict {
    return [SFParentInfo newWithSObjectType:dict[kSFParentInfoSObjectType]
                                   soupName:dict[kSFParentInfoSoupName]
                                idFieldName:dict[kSFParentInfoIdFieldName]
                  modificationDateFieldName:dict[kSFParentInfoModifificationDateFieldName]];
}

#pragma mark - To dictionary

- (NSDictionary *)asDict
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[kSFParentInfoSObjectType] = self.sobjectType;
    dict[kSFParentInfoIdFieldName] = self.idFieldName;
    dict[kSFParentInfoModifificationDateFieldName] = self.modificationDateFieldName;
    dict[kSFParentInfoSoupName] = self.soupName;
    return dict;
}


@end
