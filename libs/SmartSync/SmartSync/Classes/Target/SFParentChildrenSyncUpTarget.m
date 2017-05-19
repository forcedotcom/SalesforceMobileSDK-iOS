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

#import "SFSyncTarget+Internal.h"
#import "SFParentChildrenSyncUpTarget.h"

@interface SFParentChildrenSyncUpTarget ()

@property (nonatomic) SFParentInfo* parentInfo;
@property (nonatomic) NSArray<NSString*>* parentCreateFieldlist;
@property (nonatomic) NSArray<NSString*>* parentUpdateFieldlist;
@property (nonatomic) SFChildrenInfo* childrenInfo;
@property (nonatomic) NSArray<NSString*>* childrenCreateFieldlist;
@property (nonatomic) NSArray<NSString*>* childrenUpdateFieldlist;
@property (nonatomic) SFParentChildrenRelationshipType relationshipType;

@end

@implementation SFParentChildrenSyncUpTarget

- (instancetype)initWithParentInfo:(SFParentInfo *)parentInfo
             parentCreateFieldlist:(NSArray<NSString *> *)parentCreateFieldlist
             parentUpdateFieldlist:(NSArray<NSString *> *)parentUpdateFieldlist
                      childrenInfo:(SFChildrenInfo *)childrenInfo
           childrenCreateFieldlist:(NSArray<NSString *> *)childrenCreateFieldlist
           childrenUpdateFieldlist:(NSArray<NSString *> *)childrenUpdateFieldlist
                  relationshipType:(SFParentChildrenRelationshipType)relationshipType {
    self = [super init];
    if (self) {
        self.parentInfo = parentInfo;
        self.idFieldName = parentInfo.idFieldName;
        self.modificationDateFieldName = parentInfo.modificationDateFieldName;
        self.parentCreateFieldlist = parentCreateFieldlist;
        self.parentUpdateFieldlist = parentUpdateFieldlist;
        self.childrenInfo = childrenInfo;
        self.childrenCreateFieldlist = childrenCreateFieldlist;
        self.childrenUpdateFieldlist = childrenUpdateFieldlist;
        self.relationshipType = relationshipType;
    }
    return self;
}

- (instancetype)initWithDict:(NSDictionary *)dict {
    return [self initWithParentInfo:[SFParentInfo newFromDict:dict[kSFParentChildrenSyncTargetParent]]
              parentCreateFieldlist:dict[kSFParentChildrenSyncTargetParentCreateFieldlist]
              parentUpdateFieldlist:dict[kSFParentChildrenSyncTargetParentUpdateFieldlist]
                       childrenInfo:[SFChildrenInfo newFromDict:dict[kSFParentChildrenSyncTargetChildren]]
            childrenCreateFieldlist:dict[kSFParentChildrenSyncTargetChildrenCreateFieldlist]
            childrenUpdateFieldlist:dict[kSFParentChildrenSyncTargetChildrenUpdateFieldlist]
                   relationshipType:[SFParentChildrenSyncHelper relationshipTypeFromString:dict[kSFParentChildrenSyncTargetRelationshipType]]];
}


#pragma mark - Factory methods

+ (instancetype)newSyncTargetWithParentInfo:(SFParentInfo *)parentInfo
                      parentCreateFieldlist:(NSArray<NSString *> *)parentCreateFieldlist
                      parentUpdateFieldlist:(NSArray<NSString *> *)parentUpdateFieldlist
                               childrenInfo:(SFChildrenInfo *)childrenInfo
                    childrenCreateFieldlist:(NSArray<NSString *> *)childrenCreateFieldlist
                    childrenUpdateFieldlist:(NSArray<NSString *> *)childrenUpdateFieldlist
                           relationshipType:(SFParentChildrenRelationshipType)relationshipType {
    return [[SFParentChildrenSyncUpTarget alloc] initWithParentInfo:parentInfo
                                              parentCreateFieldlist:parentCreateFieldlist
                                              parentUpdateFieldlist:parentUpdateFieldlist
                                                       childrenInfo:childrenInfo
                                            childrenCreateFieldlist:childrenCreateFieldlist
                                            childrenUpdateFieldlist:childrenUpdateFieldlist
                                                   relationshipType:relationshipType];
}

+ (instancetype)newFromDict:(NSDictionary *)dict {
    return [[SFParentChildrenSyncUpTarget alloc] initWithDict:dict];
}

#pragma mark - To dictionary

- (NSMutableDictionary *)asDict {
    NSMutableDictionary *dict = [super asDict];
    dict[kSFParentChildrenSyncTargetParent] = [self.parentInfo asDict];
    dict[kSFParentChildrenSyncTargetParentCreateFieldlist] = self.parentCreateFieldlist;
    dict[kSFParentChildrenSyncTargetParentUpdateFieldlist] = self.parentUpdateFieldlist;
    dict[kSFParentChildrenSyncTargetChildren] = [self.childrenInfo asDict];
    dict[kSFParentChildrenSyncTargetChildrenCreateFieldlist] = self.childrenCreateFieldlist;
    dict[kSFParentChildrenSyncTargetChildrenUpdateFieldlist] = self.childrenUpdateFieldlist;
    dict[kSFParentChildrenSyncTargetRelationshipType] = [SFParentChildrenSyncHelper relationshipTypeToString:self.relationshipType];
    return dict;
}

#pragma mark - Other public methods

- (void)syncUpRecord:(SFSmartSyncSyncManager *)syncManager
              record:(NSDictionary*)record
           fieldlist:(NSArray*)fieldlist
           mergeMode:(SFSyncStateMergeMode)mergeMode
     completionBlock:(SFSyncUpTargetCompleteBlock)completionBlock
           failBlock:(SFSyncUpTargetErrorBlock)failBlock
{
    // TODO
}

- (NSString*) getDirtyRecordIdsSql:(NSString*)soupName idField:(NSString*)idField {
     return [SFParentChildrenSyncHelper getDirtyRecordIdsSql:self.parentInfo childrenInfo:self.childrenInfo parentFieldToSelect:idField];
}

@end
