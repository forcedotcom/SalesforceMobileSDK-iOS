/*
 Copyright (c) 2016-present, salesforce.com, inc. All rights reserved.
 
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

#import "SFSmartStoreFTSWithExternalStorageTests.h"
#import "SFSmartSqlHelper.h"
#import "SFSmartStore+Internal.h"
#import "SFSoupIndex.h"
#import "SFQuerySpec.h"
#import <SalesforceSDKCore/SFJsonUtils.h>
#import "SFSoupSpec.h"

@interface SFSmartStoreFTSWithExternalStorageTests ()

@property (nonatomic, strong) SFSmartStore *store;

@end

@implementation SFSmartStoreFTSWithExternalStorageTests

- (void) setupSoup:(SFSmartStoreFtsExtension) ftsExtension
{
    NSArray *features = @[kSoupFeatureExternalStorage];

    self.store.ftsExtension = ftsExtension;
    NSArray* soupIndices = [SFSoupIndex asArraySoupIndexes:
                            @[[self createFullTextIndexSpec:kFirstName],    // should be TABLE_1_0
                              [self createFullTextIndexSpec:kLastName],     // should be TABLE_1_1
                              [self createStringIndexSpec:kEmployeeId]]];   // should be TABLE_1_2
    // Employees soup
    [self.store registerSoupWithSpec:[SFSoupSpec newSoupSpec:kEmployeesSoup withFeatures:features]  //
                      withIndexSpecs:soupIndices
                       error:nil];
}

#pragma mark - tests
// All code under test must be linked into the Unit Test bundle

- (void) testRegisterDropSoupFts4
{
    [super testRegisterDropSoupFts4];
}

- (void) testRegisterDropSoupFts5
{
    [super testRegisterDropSoupFts5];
}

- (void) testInsertWithFts4
{
    [super testInsertWithFts4];
}

- (void) testInsertWithFts5
{
    [super testInsertWithFts5];
}

- (void) testUpdateWithFts4
{
    [super testUpdateWithFts4];
}

- (void) testUpdateWithFts5
{
    [super testUpdateWithFts5];
}

- (void) testDeleteWithFts4
{
    [super testDeleteWithFts4];
}

- (void) testDeleteWithFts5
{
    [super testDeleteWithFts5];
}

- (void) testClearWithFts4
{
    [super testClearWithFts4];
}

- (void) testClearWithFts5
{
    [super testClearWithFts5];
}

- (void) testSearchSingleFielNoResultsWithFts4
{
    [super testSearchSingleFielNoResultsWithFts4];
}

- (void) testSearchSingleFielNoResultsWithFts5
{
    [super testSearchSingleFielNoResultsWithFts5];
}

- (void) testSearchSingleFieldSingleResultWithFts4
{
    [super testSearchSingleFieldSingleResultWithFts4];
}

- (void) testSearchSingleFieldSingleResultWithFts5
{
    [super testSearchSingleFieldSingleResultWithFts5];
}

- (void) testSearchSingleFieldMultipleResultsWithFts4
{
    [super testSearchSingleFieldMultipleResultsWithFts4];
}

- (void) testSearchSingleFieldMultipleResultsWithFts5
{
    [super testSearchSingleFieldMultipleResultsWithFts5];
}

- (void) testSearchAllFieldsNoResultsWithFts4
{
    [super testSearchAllFieldsNoResultsWithFts4];
}

- (void) testSearchAllFieldsNoResultsWithFts5
{
    [super testSearchAllFieldsNoResultsWithFts5];
}

- (void) testSearchAllFieldsSingleResultWithFts4
{
    [super testSearchAllFieldsSingleResultWithFts4];
}

- (void) testSearchAllFieldsSingleResultWithFts5
{
    [super testSearchAllFieldsSingleResultWithFts5];
}

- (void) testSearchAllFieldMultipleResultsWithFts4
{
    [super testSearchAllFieldMultipleResultsWithFts4];
}

- (void) testSearchAllFieldMultipleResultsWithFts5
{
    [super testSearchAllFieldMultipleResultsWithFts5];
}

- (void) testSearchWithFieldColonQueriesWithFts4
{
    [super testSearchWithFieldColonQueriesWithFts4];
}

- (void) testSearchWithFieldColonQueriesWithFts5
{
    [super testSearchWithFieldColonQueriesWithFts5];
}

@end
