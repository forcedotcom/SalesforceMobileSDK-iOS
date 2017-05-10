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

#import "SyncManagerTestCase.h"
#import "SFParentChildrenSyncDownTarget.h"
#import "SFSmartSyncObjectUtils.h"

@interface SFParentChildrenSyncDownTarget ()

- (NSString *)getSoqlForRemoteIds;
- (NSString*) getDirtyRecordIdsSql:(NSString*)soupName idField:(NSString*)idField;
- (NSString*) getNonDirtyRecordIdsSql:(NSString*)soupName idField:(NSString*)idField;

@end

@interface ParentChildrenSyncTests : SyncManagerTestCase

@end

@implementation ParentChildrenSyncTests


/**
 * Test getQuery for SFParentChildrenSyncDownTarget
 */
- (void) testGetQuery {
    SFParentChildrenSyncDownTarget* target = [SFParentChildrenSyncDownTarget
            newSyncTargetWithParentInfo:[SFParentInfo newWithSObjectType:@"Parent" soupName:@"parentsSoup" idFieldName:@"ParentId" modificationDateFieldName:@"ParentModifiedDate"]
                        parentFieldlist:@[@"ParentName", @"Title"]
                       parentSoqlFilter:@"School = 'MIT'"
                           childrenInfo:[SFChildrenInfo newWithSObjectType:@"Child" sobjectTypePlural:@"Children" soupName:@"childrenSoup" parentIdFieldName:@"parentId" idFieldName:@"ChildId" modificationDateFieldName:@"ChildLastModifiedDate"]
                      childrenFieldlist:@[@"ChildName", @"School"]
                       relationshipType:SFParentChildrenRelationpshipLookup];

    NSString *expectedQuery = @"select ParentName, Title, ParentId, ParentModifiedDate, (select ChildName, School, ChildId, ChildLastModifiedDate from Children) from Parent where School = 'MIT'";
    XCTAssertEqualObjects([target getQueryToRun], expectedQuery);

    // With default id and modification date fields
    target = [SFParentChildrenSyncDownTarget
            newSyncTargetWithParentInfo:[SFParentInfo newWithSObjectType:@"Parent" soupName:@"parentsSoup"]
                        parentFieldlist:@[@"ParentName", @"Title"]
                       parentSoqlFilter:@"School = 'MIT'"
                           childrenInfo:[SFChildrenInfo newWithSObjectType:@"Child" sobjectTypePlural:@"Children" soupName:@"childrenSoup" parentIdFieldName:@"parentId"]
                      childrenFieldlist:@[@"ChildName", @"School"]
                       relationshipType:SFParentChildrenRelationpshipLookup];

    expectedQuery = @"select ParentName, Title, Id, LastModifiedDate, (select ChildName, School, Id, LastModifiedDate from Children) from Parent where School = 'MIT'";
    XCTAssertEqualObjects([target getQueryToRun], expectedQuery);
}

/**
 * Test query for reSync by calling getQuery with maxTimeStamp for SFParentChildrenSyncDownTarget
 */
- (void) testGetQueryWithMaxTimeStamp {
    NSDate* date = [NSDate new];
    long long maxTimeStamp = [date timeIntervalSince1970];
    NSString* dateStr = [SFSmartSyncObjectUtils getIsoStringFromMillis:maxTimeStamp];
    
    SFParentChildrenSyncDownTarget* target = [SFParentChildrenSyncDownTarget
            newSyncTargetWithParentInfo:[SFParentInfo newWithSObjectType:@"Parent" soupName:@"parentsSoup" idFieldName:@"ParentId" modificationDateFieldName:@"ParentModifiedDate"]
                        parentFieldlist:@[@"ParentName", @"Title"]
                       parentSoqlFilter:@"School = 'MIT'"
                           childrenInfo:[SFChildrenInfo newWithSObjectType:@"Child" sobjectTypePlural:@"Children" soupName:@"childrenSoup" parentIdFieldName:@"parentId" idFieldName:@"ChildId" modificationDateFieldName:@"ChildLastModifiedDate"]
                      childrenFieldlist:@[@"ChildName", @"School"]
                       relationshipType:SFParentChildrenRelationpshipLookup];

    NSString* expectedQuery = [NSString stringWithFormat:@"select ParentName, Title, ParentId, ParentModifiedDate, (select ChildName, School, ChildId, ChildLastModifiedDate from Children where ChildLastModifiedDate > %@) from Parent where ParentModifiedDate > %@ and School = 'MIT'", dateStr, dateStr];
    XCTAssertEqualObjects([target getQueryToRun:maxTimeStamp], expectedQuery);

    // With default id and modification date fields
    target = [SFParentChildrenSyncDownTarget
            newSyncTargetWithParentInfo:[SFParentInfo newWithSObjectType:@"Parent" soupName:@"parentsSoup"]
                        parentFieldlist:@[@"ParentName", @"Title"]
                       parentSoqlFilter:@"School = 'MIT'"
                           childrenInfo:[SFChildrenInfo newWithSObjectType:@"Child" sobjectTypePlural:@"Children" soupName:@"childrenSoup" parentIdFieldName:@"parentId"]
                      childrenFieldlist:@[@"ChildName", @"School"]
                       relationshipType:SFParentChildrenRelationpshipLookup];

    expectedQuery = [NSString stringWithFormat:@"select ParentName, Title, Id, LastModifiedDate, (select ChildName, School, Id, LastModifiedDate from Children where LastModifiedDate > %@) from Parent where LastModifiedDate > %@ and School = 'MIT'", dateStr, dateStr];
    XCTAssertEqualObjects([target getQueryToRun:maxTimeStamp], expectedQuery);
}

/**
 * Test getSoqlForRemoteIds for SFParentChildrenSyncDownTarget
 */
- (void) testGetSoqlForRemoteIds {
    SFParentChildrenSyncDownTarget* target = [SFParentChildrenSyncDownTarget
            newSyncTargetWithParentInfo:[SFParentInfo newWithSObjectType:@"Parent" soupName:@"parentsSoup" idFieldName:@"ParentId" modificationDateFieldName:@"ParentModifiedDate"]
                        parentFieldlist:@[@"ParentName", @"Title"]
                       parentSoqlFilter:@"School = 'MIT'"
                           childrenInfo:[SFChildrenInfo newWithSObjectType:@"Child" sobjectTypePlural:@"Children" soupName:@"childrenSoup" parentIdFieldName:@"ChildParentId" idFieldName:@"ChildId" modificationDateFieldName:@"ChildLastModifiedDate"]
                      childrenFieldlist:@[@"ChildName", @"School"]
                       relationshipType:SFParentChildrenRelationpshipLookup];

    NSString *expectedQuery = @"select ParentId from Parent where School = 'MIT'";
    XCTAssertEqualObjects([target getSoqlForRemoteIds], expectedQuery);

    // With default id and modification date fields
    target = [SFParentChildrenSyncDownTarget
            newSyncTargetWithParentInfo:[SFParentInfo newWithSObjectType:@"Parent" soupName:@"parentsSoup"]
                        parentFieldlist:@[@"ParentName", @"Title"]
                       parentSoqlFilter:@"School = 'MIT'"
                           childrenInfo:[SFChildrenInfo newWithSObjectType:@"Child" sobjectTypePlural:@"Children" soupName:@"childrenSoup" parentIdFieldName:@"parentId"]
                      childrenFieldlist:@[@"ChildName", @"School"]
                       relationshipType:SFParentChildrenRelationpshipLookup];

    expectedQuery = @"select Id from Parent where School = 'MIT'";
    XCTAssertEqualObjects([target getSoqlForRemoteIds], expectedQuery);
}

/**
 * Test testGetDirtyRecordIdsSql for SFParentChildrenSyncDownTarget
 */
- (void) testGetDirtyRecordIdsSql {
    SFParentChildrenSyncDownTarget *target = [SFParentChildrenSyncDownTarget
            newSyncTargetWithParentInfo:[SFParentInfo newWithSObjectType:@"Parent" soupName:@"parentsSoup" idFieldName:@"ParentId" modificationDateFieldName:@"ParentModifiedDate"]
                        parentFieldlist:@[@"ParentName", @"Title"]
                       parentSoqlFilter:@"School = 'MIT'"
                           childrenInfo:[SFChildrenInfo newWithSObjectType:@"Child" sobjectTypePlural:@"Children" soupName:@"childrenSoup" parentIdFieldName:@"ChildParentId" idFieldName:@"ChildId" modificationDateFieldName:@"ChildLastModifiedDate"]
                      childrenFieldlist:@[@"ChildName", @"School"]
                       relationshipType:SFParentChildrenRelationpshipLookup];

    NSString *expectedQuery = @"SELECT DISTINCT {parentsSoup:IdForQuery} FROM {parentsSoup} WHERE {parentsSoup:__local__} = 1 OR EXISTS (SELECT {childrenSoup:ChildId} FROM {childrenSoup} WHERE {childrenSoup:ChildParentId} = {parentsSoup:ParentId} AND {childrenSoup:__local__} = 1)";
    XCTAssertEqualObjects([target getDirtyRecordIdsSql:@"parentsSoup" idField:@"IdForQuery"], expectedQuery);
}

/**
 * Test testGetNonDirtyRecordIdsSql for SFParentChildrenSyncDownTarget
 */
- (void) testGetNonDirtyRecordIdsSql {
    SFParentChildrenSyncDownTarget *target = [SFParentChildrenSyncDownTarget
            newSyncTargetWithParentInfo:[SFParentInfo newWithSObjectType:@"Parent" soupName:@"parentsSoup" idFieldName:@"ParentId" modificationDateFieldName:@"ParentModifiedDate"]
                        parentFieldlist:@[@"ParentName", @"Title"]
                       parentSoqlFilter:@"School = 'MIT'"
                           childrenInfo:[SFChildrenInfo newWithSObjectType:@"Child" sobjectTypePlural:@"Children" soupName:@"childrenSoup" parentIdFieldName:@"ChildParentId" idFieldName:@"ChildId" modificationDateFieldName:@"ChildLastModifiedDate"]
                      childrenFieldlist:@[@"ChildName", @"School"]
                       relationshipType:SFParentChildrenRelationpshipLookup];

    NSString *expectedQuery = @"SELECT DISTINCT {parentsSoup:IdForQuery} FROM {parentsSoup} WHERE {parentsSoup:__local__} = 0 AND NOT EXISTS (SELECT {childrenSoup:ChildId} FROM {childrenSoup} WHERE {childrenSoup:ChildParentId} = {parentsSoup:ParentId} AND {childrenSoup:__local__} = 1)";
    XCTAssertEqualObjects([target getNonDirtyRecordIdsSql:@"parentsSoup" idField:@"IdForQuery"], expectedQuery);
}

@end
