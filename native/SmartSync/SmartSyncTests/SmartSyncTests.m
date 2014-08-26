/*
 Copyright (c) 2014, salesforce.com, inc. All rights reserved.
 
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
#import "SFSmartSyncMetadataManager.h"
#import "SFSmartSyncCacheManager.h"
#import "SFSmartSyncNetworkManager.h"
#import <SalesforceSDKCore/SFUserAccountManager.h>

@interface SmartSyncTests : XCTestCase

@end

@implementation SmartSyncTests

static NSInteger const kRefreshInterval = 24 * 60 * 60 * 1000;
static NSString* const kAccountOneId = @"001S000000fkJKm";
static NSString* const kAccountOneName = @"Alpha4";
static NSString* const kAccountTwoId = @"001S000000gyAaj";
static NSString* const kOpportunityOneId = @"006S0000007182b";
static NSString* const kOpportunityOneName = @"Test";
static NSString* const kOpportunityTwoId = @"006S0000007182l";
static NSString* const kCaseOneId = @"500S0000003s6Sf";
static NSString* const kCaseOneName = @"00001007";
static NSString* const kCaseTwoId = @"500S0000004O7fd";

- (void)setUp
{
    [super setUp];
    SFUserAccount *curAccount = [SFUserAccountManager sharedInstance].currentUser;
    [SFSmartSyncMetadataManager sharedInstance:curAccount];
}

- (void)tearDown
{
    SFUserAccount *curAccount = [SFUserAccountManager sharedInstance].currentUser;
    [SFSmartSyncMetadataManager removeSharedInstance:curAccount];
    [super tearDown];
}

- (void)testGlobalMRUObjectsFromServer
{
    SFUserAccount *curAccount = [SFUserAccountManager sharedInstance].currentUser;
    SFSmartSyncMetadataManager *metadataMgr = [SFSmartSyncMetadataManager sharedInstance:curAccount];
    [metadataMgr markObjectAsViewed:kCaseOneId objectType:@"Case" networkFieldName:nil
        completionBlock:^() {
            [metadataMgr loadMRUObjects:nil limit:1 cachePolicy:SFDataCachePolicyReloadAndReturnCacheOnFailure refreshCacheIfOlderThan:kRefreshInterval networkFieldName:nil inRetry:NO
                completion:^(NSArray *results, BOOL isDataFromCache, BOOL needToReloadCache) {
                    XCTAssertNotEqualObjects(results, nil, @"MRU list should not be nil");
                    XCTAssertEqual(results.count, 1, @"MRU list size should be 1");
                    XCTAssertEqualObjects([[results firstObject] name], kCaseOneName, @"Recently viewed object name is incorrect");
                }
                error:nil
             ];
        }
        error:nil
    ];
}

- (void)testAccountMRUObjectsFromServer
{
    SFUserAccount *curAccount = [SFUserAccountManager sharedInstance].currentUser;
    SFSmartSyncMetadataManager *metadataMgr = [SFSmartSyncMetadataManager sharedInstance:curAccount];
    [metadataMgr markObjectAsViewed:kAccountOneId objectType:@"Account" networkFieldName:nil
        completionBlock:^() {
            [metadataMgr loadMRUObjects:@"Account" limit:1 cachePolicy:SFDataCachePolicyReloadAndReturnCacheOnFailure refreshCacheIfOlderThan:kRefreshInterval networkFieldName:nil inRetry:NO
                completion:^(NSArray *results, BOOL isDataFromCache, BOOL needToReloadCache) {
                    XCTAssertNotEqualObjects(results, nil, @"MRU list should not be nil");
                    XCTAssertEqual(results.count, 1, @"MRU list size should be 1");
                    XCTAssertEqualObjects([[results firstObject] name], kAccountOneName, @"Recently viewed object name is incorrect");
                }
                error:nil
            ];
        }
        error:nil
     ];
}

- (void)testOpportunityMRUObjectsFromServer
{
    SFUserAccount *curAccount = [SFUserAccountManager sharedInstance].currentUser;
    SFSmartSyncMetadataManager *metadataMgr = [SFSmartSyncMetadataManager sharedInstance:curAccount];
    [metadataMgr markObjectAsViewed:kOpportunityOneId objectType:@"Opportunity" networkFieldName:nil
        completionBlock:^() {
            [metadataMgr loadMRUObjects:@"Opportunity" limit:1 cachePolicy:SFDataCachePolicyReloadAndReturnCacheOnFailure refreshCacheIfOlderThan:kRefreshInterval networkFieldName:nil inRetry:NO
                completion:^(NSArray *results, BOOL isDataFromCache, BOOL needToReloadCache) {
                    XCTAssertNotEqualObjects(results, nil, @"MRU list should not be nil");
                    XCTAssertEqual(results.count, 1, @"MRU list size should be 1");
                    XCTAssertEqualObjects([[results firstObject] name], kOpportunityOneName, @"Recently viewed object name is incorrect");
                }
                error:nil
            ];
        }
        error:nil
     ];
}

@end