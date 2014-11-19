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
#import "SFObject.h"
#import <SalesforceSDKCore/SFUserAccountManager.h>
#import <SalesforceSDKCore/TestSetupUtils.h>
#import <SalesforceSDKCore/SFJsonUtils.h>
#import <SalesforceRestAPI/SFRestAPI.h>
#import <SalesforceSDKCore/SFAuthenticationManager.h>

@interface SmartSyncTests : XCTestCase
{
    NSInteger _blocksUncompletedCount;  // The number of blocks awaiting completion.
    SFUserAccount *_currentUser;
}
@end

static NSException *authException = nil;

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

+ (void)setUp
{
    @try {
        [SFLogger setLogLevel:SFLogLevelDebug];
        [TestSetupUtils populateAuthCredentialsFromConfigFile];
        [TestSetupUtils synchronousAuthRefresh];
    } @catch (NSException *exception) {
        [self log:SFLogLevelDebug format:@"Populating auth from config failed: %@", exception];
        authException = exception;
    }
    [super setUp];
}

- (void)setUp
{
    if (authException) {
        XCTFail(@"Setting up authentication failed: %@", authException);
    }
    [SFRestAPI setIsTestRun:YES];
    [[SFRestAPI sharedInstance] setCoordinator:[SFAuthenticationManager sharedManager].coordinator];
    _currentUser = [SFUserAccountManager sharedInstance].currentUser;
    [SFSmartSyncCacheManager sharedInstance:_currentUser];
    [SFSmartSyncMetadataManager sharedInstance:_currentUser];
    [super setUp];
}

- (void)tearDown
{
    [[SFSmartSyncCacheManager sharedInstance:_currentUser] cleanCache];
    [SFSmartSyncCacheManager removeSharedInstance:_currentUser];
    [SFSmartSyncMetadataManager removeSharedInstance:_currentUser];
    [[SFRestAPI sharedInstance] cleanup];
    [SFRestAPI setIsTestRun:NO];

    // Some test runs were failing, saying the run didn't complete. This seems to fix that.
    [NSThread sleepForTimeInterval:0.1];
    [super tearDown];
}

- (void)testGlobalMRUObjectsFromServer
{
    _blocksUncompletedCount = 0;
    SFSmartSyncMetadataManager *metadataMgr = [SFSmartSyncMetadataManager sharedInstance:_currentUser];
    
    [metadataMgr markObjectAsViewed:kCaseOneId
                         objectType:@"Case"
                   networkFieldName:nil
                    completionBlock:^() {
                        _blocksUncompletedCount--;
                    }
                              error:^(NSError *error) {
                                  _blocksUncompletedCount--;
                              }
     ];
    _blocksUncompletedCount++;
    BOOL completionTimedOut = [self waitForAllBlockCompletions];
    XCTAssertTrue(!completionTimedOut, @"Timed out waiting for blocks completion");
    
    __block NSArray *mruResults = nil;
    [metadataMgr loadMRUObjects:nil
                          limit:1
                    cachePolicy:SFDataCachePolicyReloadAndReturnCacheOnFailure
        refreshCacheIfOlderThan:kRefreshInterval
               networkFieldName:nil
                        inRetry:NO
                     completion:^(NSArray *results, BOOL isDataFromCache, BOOL needToReloadCache) {
                         mruResults = results;
                         _blocksUncompletedCount--;
                     }
                          error:^(NSError *error) {
                              _blocksUncompletedCount--;
                          }
     ];
    _blocksUncompletedCount++;
    completionTimedOut = [self waitForAllBlockCompletions];
    XCTAssertTrue(!completionTimedOut, @"Timed out waiting for blocks completion");
    XCTAssertNotEqualObjects(mruResults, nil, @"MRU list should not be nil");
    XCTAssertEqual(mruResults.count, 1, @"MRU list size should be 1");
    XCTAssertEqualObjects([[mruResults firstObject] name], kCaseOneName, @"Recently viewed object name is incorrect");
}

- (void)testAccountMRUObjectsFromServer
{
    _blocksUncompletedCount = 0;
    SFSmartSyncMetadataManager *metadataMgr = [SFSmartSyncMetadataManager sharedInstance:_currentUser];
    [metadataMgr markObjectAsViewed:kAccountOneId objectType:@"Account" networkFieldName:nil
        completionBlock:^() {
            _blocksUncompletedCount--;
        }
        error:^(NSError *error) {
            _blocksUncompletedCount--;
        }
    ];
    _blocksUncompletedCount++;
    BOOL completionTimedOut = [self waitForAllBlockCompletions];
    XCTAssertTrue(!completionTimedOut, @"Timed out waiting for blocks completion");
    __block NSArray *mruResults = nil;
    [metadataMgr loadMRUObjects:@"Account" limit:1 cachePolicy:SFDataCachePolicyReloadAndReturnCacheOnFailure refreshCacheIfOlderThan:kRefreshInterval networkFieldName:nil inRetry:NO
        completion:^(NSArray *results, BOOL isDataFromCache, BOOL needToReloadCache) {
            mruResults = results;
            _blocksUncompletedCount--;
        }
        error:^(NSError *error) {
            _blocksUncompletedCount--;
        }
    ];
    _blocksUncompletedCount++;
    completionTimedOut = [self waitForAllBlockCompletions];
    XCTAssertTrue(!completionTimedOut, @"Timed out waiting for blocks completion");
    XCTAssertNotEqualObjects(mruResults, nil, @"MRU list should not be nil");
    XCTAssertEqual(mruResults.count, 1, @"MRU list size should be 1");
    XCTAssertEqualObjects([[mruResults firstObject] name], kAccountOneName, @"Recently viewed object name is incorrect");
}

- (void)testOpportunityMRUObjectsFromServer
{
    _blocksUncompletedCount = 0;
    SFSmartSyncMetadataManager *metadataMgr = [SFSmartSyncMetadataManager sharedInstance:_currentUser];
    [metadataMgr markObjectAsViewed:kOpportunityOneId objectType:@"Opportunity" networkFieldName:nil
        completionBlock:^() {
            _blocksUncompletedCount--;
        }
        error:^(NSError *error) {
            _blocksUncompletedCount--;
        }
    ];
    _blocksUncompletedCount++;
    BOOL completionTimedOut = [self waitForAllBlockCompletions];
    XCTAssertTrue(!completionTimedOut, @"Timed out waiting for blocks completion");
    __block NSArray *mruResults = nil;
    [metadataMgr loadMRUObjects:@"Opportunity" limit:1 cachePolicy:SFDataCachePolicyReloadAndReturnCacheOnFailure refreshCacheIfOlderThan:kRefreshInterval networkFieldName:nil inRetry:NO
        completion:^(NSArray *results, BOOL isDataFromCache, BOOL needToReloadCache) {
            mruResults = results;
            _blocksUncompletedCount--;
        }
        error:^(NSError *error) {
            _blocksUncompletedCount--;
        }
    ];
    _blocksUncompletedCount++;
    completionTimedOut = [self waitForAllBlockCompletions];
    XCTAssertTrue(!completionTimedOut, @"Timed out waiting for blocks completion");
    XCTAssertNotEqualObjects(mruResults, nil, @"MRU list should not be nil");
    XCTAssertEqual(mruResults.count, 1, @"MRU list size should be 1");
    XCTAssertEqualObjects([[mruResults firstObject] name], kOpportunityOneName, @"Recently viewed object name is incorrect");
}

- (void)testLoadAllObjectTypesFromServer
{
    _blocksUncompletedCount = 0;
    SFSmartSyncMetadataManager *metadataMgr = [SFSmartSyncMetadataManager sharedInstance:_currentUser];
    __block NSArray *objResults = nil;
    [metadataMgr loadAllObjectTypes:SFDataCachePolicyReloadAndReturnCacheOnFailure refreshCacheIfOlderThan:kRefreshInterval
        completion:^(NSArray *results, BOOL isDataFromCache) {
            objResults = results;
            _blocksUncompletedCount--;
        }
        error:^(NSError *error) {
            _blocksUncompletedCount--;
        }
    ];
    _blocksUncompletedCount++;
    BOOL completionTimedOut = [self waitForAllBlockCompletions];
    XCTAssertTrue(!completionTimedOut, @"Timed out waiting for blocks completion");
    XCTAssertNotEqualObjects(objResults, nil, @"All objects list should not be nil");
    NSDictionary *expectedResultDict = [self populateDictionaryFromJSONFile:@"all_objects"];
    NSArray *expectedObjects = [expectedResultDict valueForKey:@"sobjects"];
    XCTAssertEqualObjects(objResults, expectedObjects, @"All objects list does not match expected list");
}

- (void)testLoadAccountObjectTypeFromServer
{
    _blocksUncompletedCount = 0;
    SFSmartSyncMetadataManager *metadataMgr = [SFSmartSyncMetadataManager sharedInstance:_currentUser];
    __block SFObjectType *objResult = nil;
    [metadataMgr loadObjectType:@"Account" cachePolicy:SFDataCachePolicyReloadAndReturnCacheOnFailure refreshCacheIfOlderThan:kRefreshInterval
        completion:^(SFObjectType *result, BOOL isDataFromCache) {
            objResult = result;
            _blocksUncompletedCount--;
        }
        error:^(NSError *error) {
            _blocksUncompletedCount--;
        }
    ];
    _blocksUncompletedCount++;
    BOOL completionTimedOut = [self waitForAllBlockCompletions];
    XCTAssertTrue(!completionTimedOut, @"Timed out waiting for blocks completion");
    XCTAssertNotEqualObjects(objResult, nil, @"Account metadata should not be nil");
    NSDictionary *expectedResult = [self populateDictionaryFromJSONFile:@"account_metadata"];
    XCTAssertEqualObjects([objResult rawData], expectedResult, @"Account metadata does not match expected metadata");
}

- (void)testLoadCaseObjectTypeFromServer
{
    _blocksUncompletedCount = 0;
    SFSmartSyncMetadataManager *metadataMgr = [SFSmartSyncMetadataManager sharedInstance:_currentUser];
    __block SFObjectType *objResult = nil;
    [metadataMgr loadObjectType:@"Case" cachePolicy:SFDataCachePolicyReloadAndReturnCacheOnFailure refreshCacheIfOlderThan:kRefreshInterval
        completion:^(SFObjectType *result, BOOL isDataFromCache) {
            objResult = result;
            _blocksUncompletedCount--;
        }
        error:^(NSError *error) {
            _blocksUncompletedCount--;
        }
    ];
    _blocksUncompletedCount++;
    BOOL completionTimedOut = [self waitForAllBlockCompletions];
    XCTAssertTrue(!completionTimedOut, @"Timed out waiting for blocks completion");
    XCTAssertNotEqualObjects(objResult, nil, @"Account metadata should not be nil");
    NSDictionary *expectedResult = [self populateDictionaryFromJSONFile:@"case_metadata"];
    XCTAssertEqualObjects([objResult rawData], expectedResult, @"Case metadata does not match expected metadata");
}

- (void)testLoadObjectTypeLayoutsFromServer
{
    _blocksUncompletedCount = 0;
    SFSmartSyncMetadataManager *metadataMgr = [SFSmartSyncMetadataManager sharedInstance:_currentUser];
    NSMutableArray *objectsToLoad = [NSMutableArray new];
    [metadataMgr loadObjectType:@"Case" cachePolicy:SFDataCachePolicyReloadAndReturnCacheOnFailure refreshCacheIfOlderThan:kRefreshInterval
        completion:^(SFObjectType *result, BOOL isDataFromCache) {
            if (nil != result) {
                [objectsToLoad addObject:result];
            }
            _blocksUncompletedCount--;
        }
        error:^(NSError *error) {
            _blocksUncompletedCount--;
        }
    ];
    _blocksUncompletedCount++;
    BOOL completionTimedOut = [self waitForAllBlockCompletions];
    XCTAssertTrue(!completionTimedOut, @"Timed out waiting for blocks completion");
    [metadataMgr loadObjectType:@"Account" cachePolicy:SFDataCachePolicyReloadAndReturnCacheOnFailure refreshCacheIfOlderThan:kRefreshInterval
        completion:^(SFObjectType *result, BOOL isDataFromCache) {
            if (nil != result) {
                [objectsToLoad addObject:result];
            }
            _blocksUncompletedCount--;
        }
        error:^(NSError *error) {
            _blocksUncompletedCount--;
        }
    ];
    _blocksUncompletedCount++;
    completionTimedOut = [self waitForAllBlockCompletions];
    XCTAssertTrue(!completionTimedOut, @"Timed out waiting for blocks completion");
    [metadataMgr loadObjectType:@"Opportunity" cachePolicy:SFDataCachePolicyReloadAndReturnCacheOnFailure refreshCacheIfOlderThan:kRefreshInterval
        completion:^(SFObjectType *result, BOOL isDataFromCache) {
            if (nil != result) {
                [objectsToLoad addObject:result];
            }
            _blocksUncompletedCount--;
        }
        error:^(NSError *error) {
            _blocksUncompletedCount--;
        }
    ];
    _blocksUncompletedCount++;
    completionTimedOut = [self waitForAllBlockCompletions];
    XCTAssertTrue(!completionTimedOut, @"Timed out waiting for blocks completion");
    __block NSArray *layoutResults = nil;
    [metadataMgr loadObjectTypesLayout:objectsToLoad cachePolicy:SFDataCachePolicyReloadAndReturnCacheOnFailure refreshCacheIfOlderThan:kRefreshInterval
        completion:^(NSArray *results, BOOL isDataFromCache) {
            layoutResults = results;
            _blocksUncompletedCount--;
        }
        error:^(NSError *error) {
            _blocksUncompletedCount--;
        }
    ];
    _blocksUncompletedCount++;
    completionTimedOut = [self waitForAllBlockCompletions];
    XCTAssertTrue(!completionTimedOut, @"Timed out waiting for blocks completion");
    XCTAssertNotEqualObjects(layoutResults, nil, @"Layout list should not be nil");
    XCTAssertEqual(layoutResults.count, 3, @"Layout list size should be 3");
    NSDictionary *caseLayout = [self populateDictionaryFromJSONFile:@"case_layout"];
    XCTAssertEqualObjects([layoutResults objectAtIndex:0], caseLayout, @"Case layout does not match expected layout");
    NSDictionary *accountLayout = [self populateDictionaryFromJSONFile:@"account_layout"];
    XCTAssertEqualObjects([layoutResults objectAtIndex:1], accountLayout, @"Account layout does not match expected layout");
    NSDictionary *opportunityLayout = [self populateDictionaryFromJSONFile:@"opportunity_layout"];
    XCTAssertEqualObjects([layoutResults objectAtIndex:2], opportunityLayout, @"Opportunity layout does not match expected layout");
}

- (void)testRemoveMRUCache
{
    _blocksUncompletedCount = 0;
    SFSmartSyncMetadataManager *metadataMgr = [SFSmartSyncMetadataManager sharedInstance:_currentUser];
    __block NSArray *mruResults = nil;
    [metadataMgr loadMRUObjects:nil limit:1 cachePolicy:SFDataCachePolicyReloadAndReturnCacheOnFailure refreshCacheIfOlderThan:kRefreshInterval networkFieldName:nil inRetry:NO
        completion:^(NSArray *results, BOOL isDataFromCache, BOOL needToReloadCache) {
            mruResults = results;
            _blocksUncompletedCount--;
        }
        error:^(NSError *error) {
            _blocksUncompletedCount--;
        }
    ];
    _blocksUncompletedCount++;
    BOOL completionTimedOut = [self waitForAllBlockCompletions];
    XCTAssertTrue(!completionTimedOut, @"Timed out waiting for blocks completion");
    XCTAssertNotEqualObjects(mruResults, nil, @"MRU list should not be nil");
    XCTAssertEqual(mruResults.count, 1, @"MRU list size should be 1");
    SFSmartSyncCacheManager *cacheMgr = [SFSmartSyncCacheManager sharedInstance:_currentUser];
    [cacheMgr removeCache:@"recent_objects" cacheKey:@"mru_for_global"];
    NSDate *cachedTime = nil;
    NSArray *cachedObjects = [cacheMgr readDataWithCacheType:kSFMRUCacheType
                                                    cacheKey:[SFSmartSyncMetadataManager globalMruCacheKey]
                                                 cachePolicy:SFDataCachePolicyReturnCacheDataDontReload
                                                 objectClass:[SFObject class]
                                                  cachedTime:&cachedTime];
    XCTAssertEqualObjects(cachedObjects, nil, @"MRU list should be nil");
}

- (void)testCleanCache
{
    _blocksUncompletedCount = 0;
    SFSmartSyncMetadataManager *metadataMgr = [SFSmartSyncMetadataManager sharedInstance:_currentUser];
    __block NSArray *mruResults = nil;
    [metadataMgr loadMRUObjects:nil limit:1 cachePolicy:SFDataCachePolicyReloadAndReturnCacheOnFailure refreshCacheIfOlderThan:kRefreshInterval networkFieldName:nil inRetry:NO
        completion:^(NSArray *results, BOOL isDataFromCache, BOOL needToReloadCache) {
            mruResults = results;
            _blocksUncompletedCount--;
        }
        error:^(NSError *error) {
            _blocksUncompletedCount--;
        }
    ];
    _blocksUncompletedCount++;
    BOOL completionTimedOut = [self waitForAllBlockCompletions];
    XCTAssertTrue(!completionTimedOut, @"Timed out waiting for blocks completion");
    XCTAssertNotEqualObjects(mruResults, nil, @"MRU list should not be nil");
    XCTAssertEqual(mruResults.count, 1, @"MRU list size should be 1");
    SFSmartSyncCacheManager *cacheMgr = [SFSmartSyncCacheManager sharedInstance:_currentUser];
    [cacheMgr cleanCache];
    NSDate *cachedTime = nil;
    NSArray *cachedObjects = [cacheMgr readDataWithCacheType:kSFMRUCacheType
                                                    cacheKey:[SFSmartSyncMetadataManager globalMruCacheKey]
                                                 cachePolicy:SFDataCachePolicyReturnCacheDataDontReload
                                                 objectClass:[SFObject class]
                                                  cachedTime:&cachedTime];
    XCTAssertEqualObjects(cachedObjects, nil, @"MRU list should be nil");
}

- (void)testReadAllObjectTypesFromCache
{
    _blocksUncompletedCount = 0;
    SFSmartSyncMetadataManager *metadataMgr = [SFSmartSyncMetadataManager sharedInstance:_currentUser];
    __block NSArray *objResults = nil;
    [metadataMgr loadAllObjectTypes:SFDataCachePolicyReloadAndReturnCacheOnFailure refreshCacheIfOlderThan:kRefreshInterval
        completion:^(NSArray *results, BOOL isDataFromCache) {
            objResults = results;
            _blocksUncompletedCount--;
        }
        error:^(NSError *error) {
            _blocksUncompletedCount--;
        }
    ];
    _blocksUncompletedCount++;
    BOOL completionTimedOut = [self waitForAllBlockCompletions];
    XCTAssertTrue(!completionTimedOut, @"Timed out waiting for blocks completion");
    XCTAssertNotEqualObjects(objResults, nil, @"All objects list should not be nil");
    SFSmartSyncCacheManager *cacheMgr = [SFSmartSyncCacheManager sharedInstance:_currentUser];
    NSDate *cachedTime = nil;
    NSArray *cachedObjects = [cacheMgr readDataWithCacheType:kSFMetadataCacheType
                                                    cacheKey:kSFAllObjectsCacheKey
                                                 cachePolicy:SFDataCachePolicyReturnCacheDataDontReload
                                                 objectClass:[SFObjectType class]
                                                  cachedTime:&cachedTime];
    XCTAssertNotEqualObjects(cachedObjects, nil, @"Cached objects list should not be nil");
    XCTAssertNotEqual(cachedObjects.count, 0, @"Cached objects list should not be empty");
}

- (BOOL)waitForAllBlockCompletions
{
    NSDate *startTime = [NSDate date];
    BOOL completionTimedOut = NO;
    while (_blocksUncompletedCount > 0) {
        NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:startTime];
        if (elapsed > 30.0) {
            [self log:SFLogLevelDebug format:@"Request took too long (%f) to complete: %d", elapsed, _blocksUncompletedCount];
            completionTimedOut = YES;
            break;
        }
        [self log:SFLogLevelDebug format:@"## Sleeping...%d", _blocksUncompletedCount];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }
    return completionTimedOut;
}

- (NSDictionary *)populateDictionaryFromJSONFile:(NSString *)filePath
{
    NSString *dirPath = [[NSBundle bundleForClass:[self class]] pathForResource:filePath ofType:@"json"];
    NSAssert(nil != dirPath, @"Test config file not found!");
    NSData *jsonData = [[NSFileManager defaultManager] contentsAtPath:dirPath];
    id jsonResponse = [SFJsonUtils objectFromJSONData:jsonData];
    NSAssert(jsonResponse != nil, @"Error parsing JSON from config file: %@", [SFJsonUtils lastError]);
    NSDictionary *response = (NSDictionary *)jsonResponse;
    return response;
}

@end
