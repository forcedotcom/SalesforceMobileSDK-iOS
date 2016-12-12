/*
 Copyright (c) 2013-present, salesforce.com, inc. All rights reserved.
 
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
#import <SmartStore/SmartStore.h>
#import "FMResultSet.h"
#import <SalesforceSDKCore/SFUserAccountManager.h>

@interface SFSmartStoreTestCase : XCTestCase

- (void) assertSameJSONWithExpected:(id)expected actual:(id) actual message:(NSString*) message;
- (void) assertSameJSONArrayWithExpected:(NSArray*)expected actual:(NSArray*) actual message:(NSString*) message;
- (void) assertSameJSONMapWithExpected:(NSDictionary*)expected actual:(NSDictionary*) actual message:(NSString*) message;

- (NSDictionary*) createStringIndexSpec:(NSString*) path;
- (NSDictionary*) createIntegerIndexSpec:(NSString*) path;
- (NSDictionary*) createFloatingIndexSpec:(NSString*) path;
- (NSDictionary*) createFullTextIndexSpec:(NSString*) path;
- (NSDictionary*) createJSON1IndexSpec:(NSString*) path;
- (NSDictionary*) createSimpleIndexSpec:(NSString*) path withType:(NSString*) pathType;

- (BOOL) hasTable:(NSString*)tableName store:(SFSmartStore*)store;
- (NSString*) getSoupTableName:(NSString*)soupName store:(SFSmartStore*)store;

- (void) checkExplainQueryPlan:(NSString*) soupName index:(NSUInteger)index covering:(BOOL) covering dbOperation:(NSString*)dbOperation store:(SFSmartStore*)store;
- (void) checkColumns:(NSString*)tableName expectedColumns:(NSArray*)expectedColumns store:(SFSmartStore*)store;
- (void) checkDatabaseIndexes:(NSString*)tableName expectedSqlStatements:(NSArray*)expectedSqlStatements store:(SFSmartStore*)store;
- (void) checkCreateTableStatment:(NSString*)tableName expectedSqlStatementPrefix:(NSString*)expectedSqlStatementPrefix store:(SFSmartStore*)store;
- (void) checkSoupIndex:(SFSoupIndex*)indexSpec expectedPath:(NSString*)expectedPath expectedType:(NSString*)expectedType expectedColumnName:(NSString*)expectedColumnName ;

- (void) checkSoupRow:(FMResultSet*) frs withExpectedEntry:(NSDictionary*)expectedEntry withSoupIndexes:(NSArray*)arraySoupIndexes;
- (void) checkFtsRow:(FMResultSet*) frs withExpectedEntry:(NSDictionary*)expectedEntry withSoupIndexes:(NSArray*)arraySoupIndexes;

- (void) checkSoupTable:(NSArray*)expectedEntries shouldExist:(BOOL)shouldExist store:(SFSmartStore*)store soupName:(NSString*)soupName;

-(void) checkFileSystem:(NSArray*)expectedEntries shouldExist:(BOOL)shouldExist store:(SFSmartStore*)store soupName:(NSString*)soupName;

- (SFUserAccount*) setUpSmartStoreUser;
- (void) tearDownSmartStoreUser:(SFUserAccount*)user;

@end
