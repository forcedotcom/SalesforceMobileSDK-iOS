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

#import "SFSObjectTree.h"


@interface SFSObjectTree ()

@property (nonatomic, strong) NSString *objectType;
@property (nonatomic, strong) NSString *objectTypePlural;
@property (nonatomic, strong) NSString *referenceId;
@property (nonatomic, strong) NSDictionary<NSString*, id> *fields;
@property (nonatomic, strong) NSArray<SFSObjectTree*> *childrenTrees;

@end

@implementation SFSObjectTree

- (id)initWithObjectType:(NSString *)objectType
        objectTypePlural:(NSString *)objectTypePlural
             referenceId:(NSString *)referenceId
                  fields:(NSDictionary<NSString *, id> *)fields
           childrenTrees:(NSArray<SFSObjectTree *> *)childrenTrees {
    self = [super init];
    if (self) {
        self.objectType = objectType;
        self.objectTypePlural = objectTypePlural;
        self.referenceId = referenceId;
        self.fields = fields;
        self.childrenTrees = childrenTrees;
    }
    return self;
}

- (NSDictionary<NSString*, id>*) asJSON {
    NSMutableDictionary<NSString *, id> *parentJson = [NSMutableDictionary
            dictionaryWithDictionary:[self buildJsonForRecordWithObjectType:self.objectType
                                                                referenceId:self.referenceId
                                                                     fields:self.fields]];

    if (self.childrenTrees) {
        // Grouping children trees by type and figuring out object type to object type plural mapping
        NSMutableDictionary<NSString*, NSString*>* objectTypeToObjectTypePlural = [NSMutableDictionary new];
        NSMutableDictionary<NSString *, NSMutableArray<SFSObjectTree *> *> *objectTypeToChildrenTrees = [NSMutableDictionary new];

        for (SFSObjectTree * childTree in self.childrenTrees) {
            NSString* childObjectType = childTree.objectType;
            if (!objectTypeToObjectTypePlural[childObjectType]) {
                objectTypeToObjectTypePlural[childObjectType] = childTree.objectTypePlural;
            }
            
            if (!objectTypeToChildrenTrees[childObjectType]) {
                objectTypeToChildrenTrees[childObjectType] = [NSMutableArray new];
            }

            [objectTypeToChildrenTrees[childObjectType] addObject:childTree];
        }
        // Iterating through children
        
        for (NSString* childrenObjectType in [objectTypeToChildrenTrees allKeys]) {
            NSMutableArray<SFSObjectTree *> *childrenTreesForType = objectTypeToChildrenTrees[childrenObjectType];
            NSMutableArray<NSDictionary<NSString *, id>*>* childrenJsonArray = [NSMutableArray new];
            for (SFSObjectTree * childTree in childrenTreesForType) {
                [childrenJsonArray addObject:[self buildJsonForRecordWithObjectType:childrenObjectType
                                                                        referenceId:childTree.referenceId
                                                                             fields:childTree.fields]];
            }
            parentJson[objectTypeToObjectTypePlural[childrenObjectType]] = @{@"records": childrenJsonArray};
        }
    }

    // Done
    return parentJson;
}

- (NSDictionary<NSString *, id> *)buildJsonForRecordWithObjectType:(NSString *)objectType
                                                       referenceId:(NSString *)referenceId
                                                            fields:(NSDictionary<NSString *, id> *)fields {

    NSMutableDictionary<NSString*, id>* jsonForRecord = [NSMutableDictionary dictionaryWithDictionary:fields];
    jsonForRecord[@"attributes"] = @{@"referenceId":referenceId, @"type":objectType};
    return jsonForRecord;
}

@end