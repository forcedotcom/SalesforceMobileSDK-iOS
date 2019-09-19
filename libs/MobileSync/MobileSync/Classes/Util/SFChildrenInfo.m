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

#import "SFChildrenInfo.h"
#import "SFSmartSyncConstants.h"

NSString * const kSFChildrenInfoSObjectTypePlural = @"sobjectTypePlural";
NSString * const kSFChildrenInfoParentIdFieldName = @"parentIdFieldName"; // name of field on  holding parent server id

@interface SFParentInfo ()

- (instancetype)initWithSObjectType:(NSString *)sobjectType soupName:(NSString *)soupName idFieldName:(NSString *)idFieldName modificationDateFieldName:(NSString *)modificationDateFieldName;

@end

@interface SFChildrenInfo ()

@property (nonatomic, readwrite) NSString* sobjectTypePlural;
@property (nonatomic, readwrite) NSString* parentIdFieldName;

@end

@implementation SFChildrenInfo

- (instancetype)initWithSObjectType:(NSString *)sobjectType sobjectTypePlural:(NSString *)sobjectTypePlural soupName:(NSString *)soupName parentIdFieldName:(NSString *)parentIdFieldName idFieldName:(NSString *)idFieldName modificationDateFieldName:(NSString *)modificationDateFieldName {
    self = [super initWithSObjectType:sobjectType soupName:soupName idFieldName:idFieldName modificationDateFieldName:modificationDateFieldName];

    if (self) {
        self.sobjectTypePlural = sobjectTypePlural;
        self.parentIdFieldName = parentIdFieldName;
    }
    return self;

}
#pragma mark Factory methods

+ (SFChildrenInfo *)newWithSObjectType:(NSString *)sobjectType sobjectTypePlural:(NSString *)sobjectTypePlural soupName:(NSString *)soupName parentIdFieldName:(NSString *)parentIdFieldName {
    return [SFChildrenInfo newWithSObjectType:sobjectType sobjectTypePlural:sobjectTypePlural soupName:soupName parentIdFieldName:parentIdFieldName idFieldName:kId modificationDateFieldName:kLastModifiedDate];
}


+ (SFChildrenInfo *)newWithSObjectType:(NSString *)sobjectType sobjectTypePlural:(NSString *)sobjectTypePlural soupName:(NSString *)soupName parentIdFieldName:(NSString *)parentIdFieldName idFieldName:(NSString *)idFieldName modificationDateFieldName:(NSString *)modificationDateFieldName {
    return [[SFChildrenInfo alloc] initWithSObjectType:sobjectType sobjectTypePlural:sobjectTypePlural soupName:soupName parentIdFieldName:parentIdFieldName idFieldName:idFieldName modificationDateFieldName:modificationDateFieldName];
}

+ (SFChildrenInfo*) newFromDict:(NSDictionary*)dict {
    return [SFChildrenInfo newWithSObjectType:dict[kSFParentInfoSObjectType] sobjectTypePlural:dict[kSFChildrenInfoSObjectTypePlural] soupName:dict[kSFParentInfoSoupName] parentIdFieldName:dict[kSFChildrenInfoParentIdFieldName] idFieldName:dict[kSFParentInfoIdFieldName] modificationDateFieldName:dict[kSFParentInfoModifificationDateFieldName]];
}

#pragma mark - To dictionary

- (NSDictionary *)asDict
{
    NSMutableDictionary *dict = [[super asDict] mutableCopy];
    dict[kSFChildrenInfoSObjectTypePlural] = self.sobjectTypePlural;
    dict[kSFChildrenInfoParentIdFieldName] = self.parentIdFieldName;
    return dict;
}

@end
