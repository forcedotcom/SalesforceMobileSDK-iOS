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

@interface MetadataManagerTests : XCTestCase
{
    NSInteger _blocksUncompletedCount;  // The number of blocks awaiting completion.
    SFUserAccount *_currentUser;
}
@end

static NSException *authException = nil;

@implementation MetadataManagerTests

static NSInteger const kRefreshInterval = 24 * 60 * 60 * 1000;
static NSString* const kAccountOneId = @"001S000000fkJKmIAM";
static NSString* const kAccountOneName = @"Alpha4";
static NSString* const kOpportunityOneId = @"006S0000007182bIAA";
static NSString* const kOpportunityOneName = @"Test";
static NSString* const kCaseOneId = @"500S0000003s6SfIAI";
static NSString* const kCaseOneName = @"00001007";

+ (void)setUp
{
    @try {
        [SFLogger setLogLevel:SFLogLevelDebug];
        [TestSetupUtils populateAuthCredentialsFromConfigFileForClass:[self class]];
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

- (void)testCommonMRUObjectsFromServer
{
    NSArray *objectTypesIdsNames = @[ @[ @"Account", kAccountOneId, kAccountOneName ], @[ @"Opportunity", kOpportunityOneId, kOpportunityOneName ]];
    _blocksUncompletedCount = 0;
    SFSmartSyncMetadataManager *metadataMgr = [SFSmartSyncMetadataManager sharedInstance:_currentUser];
    for (NSArray *objectTypeIdName in objectTypesIdsNames) {
        NSString *objectType = objectTypeIdName[0];
        NSString *objectId = objectTypeIdName[1];
        NSString *objectName = objectTypeIdName[2];
        [metadataMgr markObjectAsViewed:objectId objectType:objectType networkFieldName:nil
                        completionBlock:^() {
                            _blocksUncompletedCount--;
                        }
                                  error:^(NSError *error) {
                                      _blocksUncompletedCount--;
                                  }
         ];
        _blocksUncompletedCount++;
        BOOL completionTimedOut = [self waitForAllBlockCompletions];
        XCTAssertTrue(!completionTimedOut, @"Timed out waiting for blocks completion on object type '%@'", objectType);
        __block NSArray *mruResults = nil;
        [metadataMgr loadMRUObjects:objectType limit:1 cachePolicy:SFDataCachePolicyReloadAndReturnCacheOnFailure refreshCacheIfOlderThan:kRefreshInterval networkFieldName:nil inRetry:NO
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
        XCTAssertTrue(!completionTimedOut, @"Timed out waiting for blocks completion for object type '%@'.", objectType);
        XCTAssertNotEqualObjects(mruResults, nil, @"MRU list should not be nil");
        XCTAssertEqual(mruResults.count, 1, @"MRU list size should be 1");
        XCTAssertEqualObjects(((SFObject *)mruResults[0]).objectId, objectId, @"Recently viewed object ID for object type '%@' is incorrect", objectType);
        XCTAssertEqualObjects(((SFObject *)mruResults[0]).name, objectName, @"Recently viewed object name for object type '%@' is incorrect", objectType);
    }
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
}

- (void)testLoadCommonObjectTypesFromServer
{
    for (NSString *objectTypeName in @[ @"Case", @"Account", @"Opportunity" ]) {
        _blocksUncompletedCount = 0;
        SFSmartSyncMetadataManager *metadataMgr = [SFSmartSyncMetadataManager sharedInstance:_currentUser];
        __block SFObjectType *objResult = nil;
        [metadataMgr loadObjectType:objectTypeName cachePolicy:SFDataCachePolicyReloadAndReturnCacheOnFailure refreshCacheIfOlderThan:kRefreshInterval
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
        XCTAssertNotEqualObjects(objResult, nil, @"%@ metadata should not be nil", objectTypeName);
    }
}

- (void)testLoadUnknownObjectTypeFromServer
{
    _blocksUncompletedCount = 0;
    SFSmartSyncMetadataManager *metadataMgr = [SFSmartSyncMetadataManager sharedInstance:_currentUser];
    __block SFObjectType *objResult = nil;
    __block NSError *errorResult = nil;
    NSString *objectTypeName = [NSString stringWithFormat:@"RandomNonexistentObject_%u", arc4random()];
    [metadataMgr loadObjectType:objectTypeName cachePolicy:SFDataCachePolicyReloadAndReturnCacheOnFailure refreshCacheIfOlderThan:kRefreshInterval
                     completion:^(SFObjectType *result, BOOL isDataFromCache) {
                         objResult = result;
                         _blocksUncompletedCount--;
                     }
                          error:^(NSError *error) {
                              errorResult = error;
                              _blocksUncompletedCount--;
                          }
     ];
    _blocksUncompletedCount++;
    BOOL completionTimedOut = [self waitForAllBlockCompletions];
    XCTAssertTrue(!completionTimedOut, @"Timed out waiting for blocks completion");
    XCTAssertNil(errorResult, @"Unknown object type should not generate an error.  Error decription: %@", [errorResult localizedDescription]);
    XCTAssertNil(objResult, @"Unknown object type (%@) metadata should be nil", objectTypeName);
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
    [cacheMgr removeCache:kSFMRUCacheType cacheKey:[SFSmartSyncMetadataManager globalMruCacheKey]];
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
    NSFileManager *fm = [[NSFileManager alloc] init];
    NSData *jsonData = [fm contentsAtPath:dirPath];
    id jsonResponse = [SFJsonUtils objectFromJSONData:jsonData];
    NSAssert(jsonResponse != nil, @"Error parsing JSON from config file: %@", [SFJsonUtils lastError]);
    NSDictionary *response = (NSDictionary *)jsonResponse;
    return response;
}

@end
