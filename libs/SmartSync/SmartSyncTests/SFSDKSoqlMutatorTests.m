/*
Copyright (c) 2019-present, salesforce.com, inc. All rights reserved.

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

#import <XCTest/XCTest.h>
#import "SFSDKSoqlMutator.h"
#import "SFSDKSoqlTokenizer.h"

@interface SFSDKSoqlMutatorTests : XCTestCase

@end


@implementation SFSDKSoqlMutatorTests

- (void) testMutatorNoChange {
    NSString* soql = @"select Id, Name from Account where Id in (select Id from Account) and Name like 'Mad Max' limit 1000";
    XCTAssertEqualObjects(soql, [[[SFSDKSoqlMutator withSoql:soql] asBuilder] build]);
}

- (void) testSelectFieldPresenceWhenPresent {
    NSString* soql = @"SELECT Id, Name FROM Account";
    XCTAssertTrue([[SFSDKSoqlMutator withSoql:soql] isSelectingField:@"Id"]);
    XCTAssertTrue([[SFSDKSoqlMutator withSoql:soql] isSelectingField:@"Name"]);
}

- (void) testSelectFieldPresenceWhenAbsent {
    NSString* soql = @"SELECT Id, Name FROM Account";
    XCTAssertFalse([[SFSDKSoqlMutator withSoql:soql] isSelectingField:@"Description"]);
}

- (void) testSelectFieldPresenceWhenPresentInWhereClause {
    NSString* soql = @"SELECT Id FROM Account WHERE Name like 'James%'";
    XCTAssertFalse([[SFSDKSoqlMutator withSoql:soql] isSelectingField:@"Name"]);
}

- (void) testSelectFieldPresenceWhenPresentInSubquery {
    XCTAssertFalse([[SFSDKSoqlMutator withSoql:@"SELECT Name, (SELECT LastName FROM Contacts) FROM Account"] isSelectingField:@"LastName"]);
}
                    
- (void) testSelectFieldPresenceWhenPresentAsSubstring {
    XCTAssertFalse([[SFSDKSoqlMutator withSoql:@"SELECT LastName FROM Account"] isSelectingField:@"Name"]);
}

- (void) testOrderByPresenceWhenPresent {
    XCTAssertTrue([[SFSDKSoqlMutator withSoql:@"SELECT LastName FROM Account ORDER BY LastModifiedDate"] isOrderingBy:@"LastModifiedDate"]);
}

- (void) testOrderByPresenceWhenPresentInSubquery {
    XCTAssertFalse([[SFSDKSoqlMutator withSoql:@"SELECT LastName FROM Account WHERE Id IN (SELECT Id FROM Account ORDER BY LastModifiedDate)"] isOrderingBy:@"LastModifiedDate"]);
}

- (void) testOrderByPresenceWhenAbsent {
    XCTAssertFalse([[SFSDKSoqlMutator withSoql:@"SELECT LastName FROM Account"] isOrderingBy:@"LastModifiedDate"]);
}

- (void) testOrderByPresenceWhenOrderingBySomethingElse {
    XCTAssertFalse([[SFSDKSoqlMutator withSoql:@"SELECT LastName FROM Account ORDER BY FirstName"] isOrderingBy:@"LastModifiedDate"]);
}

- (void) testAddSelectField {
    NSString* soql = @"SELECT Description FROM Account";
    XCTAssertEqualObjects(@"select Id,Name,Description from Account", [[[[[SFSDKSoqlMutator withSoql:soql] addSelectFields:@"Name"] addSelectFields:@"Id"] asBuilder] build]);
}

- (void) testReplaceSelectField {
    NSString* soql = @"SELECT Description FROM Account";
    XCTAssertEqualObjects(@"select Id from Account", [[[[SFSDKSoqlMutator withSoql:soql] replaceSelectFields:@"Id"] asBuilder] build]);
}

- (void) testAddWherePredicateWhenWhereClausePresent {
    NSString* soql = @"SELECT Description FROM Account WHERE FirstName = 'James'";
    XCTAssertEqualObjects(@"select Description from Account where LastModifiedDate > 123 and FirstName = 'James'", [[[[SFSDKSoqlMutator withSoql:soql] addWherePredicates:@"LastModifiedDate > 123"] asBuilder] build]);
}

- (void) testAddWherePredicateWhenWhereClauseAbsent {
    NSString* soql = @"SELECT Description FROM Account";
    XCTAssertEqualObjects(@"select Description from Account where LastModifiedDate > 123", [[[[SFSDKSoqlMutator withSoql:soql] addWherePredicates:@"LastModifiedDate > 123"] asBuilder] build]);
}

- (void) testReplaceOrderByWhenAbsent {
    NSString* soql = @"SELECT Description FROM Account";
    XCTAssertEqualObjects(@"select Description from Account order by LastModifiedDate", [[[[SFSDKSoqlMutator withSoql:soql] replaceOrderBy:@"LastModifiedDate"] asBuilder] build]);
}

- (void) testReplaceOrderByWhenPresent {
    NSString* soql = @"SELECT Description FROM Account ORDER BY Name";
    XCTAssertEqualObjects(@"select Description from Account order by LastModifiedDate", [[[[SFSDKSoqlMutator withSoql:soql] replaceOrderBy:@"LastModifiedDate"] asBuilder] build]);
}

- (void) testReplaceOrderByWhenLimit {
    NSString* soql = @"SELECT Description FROM Account LIMIT 1000";
    XCTAssertEqualObjects(@"select Description from Account order by LastModifiedDate limit 1000", [[[[SFSDKSoqlMutator withSoql:soql] replaceOrderBy:@"LastModifiedDate"] asBuilder] build]);
}

- (void) testDropOrderBy {
    NSString* soql = @"SELECT Description FROM Account ORDER BY FirstName";
    XCTAssertEqualObjects(@"select Description from Account", [[[[SFSDKSoqlMutator withSoql:soql] replaceOrderBy:@""] asBuilder] build]);
}

- (void) testDropOrderByWhenLimit {
    NSString* soql = @"SELECT Description FROM Account ORDER BY FirstName LIMIT 1000";
    XCTAssertEqualObjects(@"select Description from Account limit 1000", [[[[SFSDKSoqlMutator withSoql:soql] replaceOrderBy:@""] asBuilder] build]);
}

- (void) testHasOrderByWhenPresent {
    NSString* soql = @"SELECT Description FROM Account ORDER BY FirstName LIMIT 1000";
    XCTAssertTrue([[SFSDKSoqlMutator withSoql:soql] hasOrderBy]);
}

- (void) testHasOrderByWhenPresentInSubquery {
    NSString* soql = @"SELECT Description FROM Account WHERE Id IN (SELECT Id FROM Account ORDER BY FirstName) LIMIT 1000";
    XCTAssertFalse([[SFSDKSoqlMutator withSoql:soql] hasOrderBy]);
}

- (void) testHasOrderByWhenPresentInValue {
    NSString* soql = @"SELECT Description FROM Account WHERE Name = ' order by \\\' order by \\\''";
    XCTAssertFalse([[SFSDKSoqlMutator withSoql:soql] hasOrderBy]);
}

- (void) testHasOrderByWhenAbsent {
    NSString* soql = @"SELECT Description FROM Account LIMIT 1000";
    XCTAssertFalse([[SFSDKSoqlMutator withSoql:soql] hasOrderBy]);
}

- (void) testModifyQueryWithInClause {
    NSString* soql = @"select Name from Account where Id IN ('001P000001NQPjJIAX','001P000001NQPkdIAH') order by Name";
    NSString* expectedSoql = @"select Id,LastModifiedDate,Name from Account where Id IN ('001P000001NQPjJIAX','001P000001NQPkdIAH') order by LastModifiedDate";
    XCTAssertEqualObjects(expectedSoql, [[[[[[SFSDKSoqlMutator withSoql:soql] addSelectFields:@"LastModifiedDate"] addSelectFields:@"Id"] replaceOrderBy:@"LastModifiedDate"] asBuilder] build]);
}

- (void) testModifyQueryWithComplexExpressions {
    NSString* soql = @"select Name from Account where ((Name = 'James Bond') or (Name = 'Batman')) and (Description like '%savior%') order by Name";
    NSString* expectedSoql = @"select Id,LastModifiedDate,Name from Account where ((Name = 'James Bond') or (Name = 'Batman')) and (Description like '%savior%') order by LastModifiedDate";
    XCTAssertEqualObjects(expectedSoql, [[[[[[SFSDKSoqlMutator withSoql:soql] addSelectFields:@"LastModifiedDate"] addSelectFields:@"Id"] replaceOrderBy:@"LastModifiedDate"] asBuilder] build]);
}

- (void) testModifyOrderByTwiceInComplexQuery {
    NSString* soql = @"select LastModifiedDate,Id, OwnerId, WhatId, Status, Subject, Priority, Description, ActivityDate, WhoId from Task where (OwnerId = '<<<UserIDHERE>>>' OR (What.Type = 'Account' AND (Account.OwnerId = '<<<UserIDHERE>>>' OR Account.Owner.ManagerId = '<<<UserIDHERE>>>'))) AND (LastModifiedDate > 2019-05-15T07:52:27.000Z ) order by Description";
    NSString* expectedSoql = @"select LastModifiedDate,Id, OwnerId, WhatId, Status, Subject, Priority, Description, ActivityDate, WhoId from Task where (OwnerId = '<<<UserIDHERE>>>' OR (What.Type = 'Account' AND (Account.OwnerId = '<<<UserIDHERE>>>' OR Account.Owner.ManagerId = '<<<UserIDHERE>>>'))) AND (LastModifiedDate > 2019-05-15T07:52:27.000Z ) order by LastModifiedDate";
    XCTAssertEqualObjects(expectedSoql, [[[[[SFSDKSoqlMutator withSoql:soql] replaceOrderBy:@"LastModifiedDate"] replaceOrderBy:@"LastModifiedDate"] asBuilder] build]);
}

- (void) testTokenizeBasic {
    [self tryTokenize:@"hello world" expectedTokensJoined:@"hello# #world"];
    [self tryTokenize:@"hello world: my name is   James    Bond" expectedTokensJoined:@"hello# #world:# #my# #name# #is#   #James#    #Bond"];
}

- (void) testTokenizeWithOrderGroupBy {
    [self tryTokenize:@"hello order by world" expectedTokensJoined:@"hello# #order by# #world"];
    [self tryTokenize:@"hello group by world" expectedTokensJoined:@"hello# #group by# #world"];
    [self tryTokenize:@"hello something by world" expectedTokensJoined:@"hello# #something# #by# #world"];
    [self tryTokenize:@"hello something  by world order  by abc group    by def order" expectedTokensJoined:@"hello# #something#  #by# #world# #order by# #abc# #group by# #def# #order"];
}

- (void) testTokenizeWithQuotes {
    [self tryTokenize:@"hello 'my world'" expectedTokensJoined:@"hello# #'my world'"];
    [self tryTokenize:@"hello 'my world\\''" expectedTokensJoined:@"hello# #'my world\\''"];
}

- (void) testTokenizeWithParentheses {
    [self tryTokenize:@"hello (this is a group)" expectedTokensJoined:@"hello# #(this is a group)"];
    [self tryTokenize:@"hello (a or (b and c) or d),(e or f)" expectedTokensJoined:@"hello# #(a or (b and c) or d)#,#(e or f)"];
}

- (void) testTokenizeWithQuotesInParentheses {
    [self tryTokenize:@"hello (this is a 'group')" expectedTokensJoined:@"hello# #(this is a 'group')"];
    [self tryTokenize:@"hello (a or (b and 'the name of c') or d)" expectedTokensJoined:@"hello# #(a or (b and 'the name of c') or d)"];
}

- (void) testTokenizeWithParenthesesInQuotes {
    [self tryTokenize:@"hello 'oh oh ( ) ( )))'" expectedTokensJoined:@"hello# #'oh oh ( ) ( )))'"];
}


- (void) tryTokenize:(NSString*) soql expectedTokensJoined:(NSString*)expectedTokensJoined {
    SFSDKSoqlTokenizer* tokenizer = [[SFSDKSoqlTokenizer alloc] init:soql];
    NSArray* tokens = [tokenizer tokenize];
    NSString* actualTokensJoined = [tokens componentsJoinedByString:@"#"];
    XCTAssertEqualObjects(expectedTokensJoined, actualTokensJoined);
}


@end
