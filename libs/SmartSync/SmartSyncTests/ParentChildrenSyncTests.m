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

@interface ParentChildrenSyncTests : SyncManagerTestCase

@end

@implementation ParentChildrenSyncTests


/**
 * Test getQuery SFfor ParentChildrenSyncDownTarget
 */
- (void) testGetQuery {
    SFParentChildrenSyncDownTarget* target = [SFParentChildrenSyncDownTarget
            newSyncTargetWithParentInfo:[SFParentInfo newWithSObjectType:@"Parent" soupName:@"parentsSoup" idFieldName:@"ParentId" modificationDateFieldName:@"ParentModifiedDate"]
                        parentFieldlist:@[@"ParentName", @"Title"]
                       parentSoqlFilter:@"School = 'MIT'"
                           childrenInfo:[SFChildrenInfo newWithSObjectType:@"Child" sobjectTypePlural:@"Children" soupName:@"childrenSoup" parentIdFieldName:@"parentId" idFieldName:@"ChildId" modificationDateFieldName:@"ChildLastModifiedDate"]
                      childrenFieldlist:@[@"ChildName", @"School"]
                       relationshipType:SFParentChildrenRelationpshipLookup];

    XCTAssert([target getQueryToRun], @"select ParentName, Title, ParentId, ParentModifiedDate, (select ChildName, School, ChildId, ChildLastModifiedDate from Children) from Parent where School = 'MIT'");

    /*
    // With default id and modification date fields
    target = new ParentChildrenSyncDownTarget(
            new ParentInfo("Parent", "parentsSoup"),
            Arrays.asList("ParentName", "Title"),
            "School = 'MIT'",
            new ChildrenInfo("Child", "Children", "childrenSoup", "parentId"),
            Arrays.asList("ChildName", "School"),
            RelationshipType.LOOKUP);


    assertEquals("select ParentName, Title, Id, LastModifiedDate, (select ChildName, School, Id, LastModifiedDate from Children) from Parent where School = 'MIT'", target.getQuery());

     */
}

@end
