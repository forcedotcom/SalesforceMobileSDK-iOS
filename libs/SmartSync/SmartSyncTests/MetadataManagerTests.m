/*
 Copyright (c) 2014-present, salesforce.com, inc. All rights reserved.
 
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
#import <SalesforceSDKCore/SFSDKSoqlBuilder.h>
#import <SalesforceSDKCore/SFUserAccountManager.h>
#import <SalesforceSDKCore/TestSetupUtils.h>
#import <SalesforceSDKCore/SFJsonUtils.h>
#import <SalesforceSDKCore/SFRestAPI+Blocks.h>
#import <SalesforceSDKCore/SFAuthenticationManager.h>

@interface MetadataManagerTests : XCTestCase

@property (nonatomic, strong) SFUserAccount *currentUser;
@property (nonatomic, strong) SFSmartSyncMetadataManager *metadataManager;

@end

static NSException *authException = nil;

@implementation MetadataManagerTests

static NSInteger const kRefreshInterval = 24 * 60 * 60 * 1000;
static NSString* kAccountOneId = @"001S000000cZ1VVIA0";
static NSString* const kAccountOneName = @"Acme";
static NSString* kOpportunityOneId = @"006S0000006luq4IAA";
static NSString* const kOpportunityOneName = @"Acme - 1,200 Widgets";
static NSString* kCaseOneId = @"500S00000031VPwIAM";
static NSString* const kCaseOneName = @"00001001";

+ (void)setUp
{
    @try {
        [SFSDKSmartSyncLogger setLogLevel:DDLogLevelDebug];
        [TestSetupUtils populateAuthCredentialsFromConfigFileForClass:[self class]];
        [TestSetupUtils synchronousAuthRefresh];
    } @catch (NSException *exception) {
        [SFSDKSmartSyncLogger d:[self class] format:@"Populating auth from config failed: %@", exception];
        authException = exception;
    }
    [super setUp];
}

- (void)setUp
{
    [super setUp];
    if (authException) {
        XCTFail(@"Setting up authentication failed: %@", authException);
    }
    [SFRestAPI setIsTestRun:YES];
    self.currentUser = [SFUserAccountManager sharedInstance].currentUser;
    [SFSmartSyncCacheManager sharedInstance:self.currentUser];
    self.metadataManager = [SFSmartSyncMetadataManager sharedInstance:self.currentUser];
}

- (void)tearDown
{
    [[SFSmartSyncCacheManager sharedInstance:self.currentUser] cleanCache];
    [SFSmartSyncCacheManager removeSharedInstance:self.currentUser];
    [SFSmartSyncMetadataManager removeSharedInstance:self.currentUser];
    [[SFRestAPI sharedInstance] cleanup];
    [SFRestAPI setIsTestRun:NO];

    // Some test runs were failing, saying the run didn't complete. This seems to fix that.
    [NSThread sleepForTimeInterval:0.1];
    [super tearDown];
}


- (void)sendQuery:(NSString *)query withCompeletionBlock:(void(^)(NSArray *result))completionBlock {
    XCTestExpectation *expect = [self expectationWithDescription:@"get query result"];
    SFRestDictionaryResponseBlock completeBlock = ^(NSDictionary* responseAsJson) {
        NSArray *records = responseAsJson[@"records"];
        if (records && [records isKindOfClass:[NSArray class]]) {
            NSAssert(records.count>0, @"no entity found");
            completionBlock(records);
            [expect fulfill];
        }
    };
    
    SFRestFailBlock failBlock = ^(NSError *error) {
        [SFSDKSmartSyncLogger e:[self class] format:@"Failed to get query result, error %@", [error localizedDescription]];
    };
    
    // Send request.
    [[SFRestAPI sharedInstance] performSOQLQuery:query failBlock:failBlock completeBlock:completeBlock];
    [self waitForExpectationsWithTimeout:20 handler:nil];
}

- (void)testGlobalMRUObjectsFromServer
{
    SFSDKSoqlBuilder *queryBuilder = [[SFSDKSoqlBuilder withFields:@"Id"] from:@"Case"];
    [queryBuilder whereClause:[NSString stringWithFormat:@"CaseNumber = '%@'", kCaseOneName]];
    NSString *queryString = [queryBuilder build];
    [self sendQuery:queryString withCompeletionBlock:^(NSArray *result){
        kCaseOneId = [result[0] valueForKey:@"Id"];
    }];
    
    [NSThread sleepForTimeInterval:1]; //give server side a second to settle
    XCTestExpectation *objectMarkedAsViewed = [self expectationWithDescription:@"objectMarkedAsViewed"];
    [self.metadataManager markObjectAsViewed:kCaseOneId objectType:@"Case" networkFieldName:nil completionBlock:^() {
        [objectMarkedAsViewed fulfill];
    } error:^(NSError *error) {
        XCTFail(@"Error while marking object as viewed %@", error);
        [objectMarkedAsViewed fulfill];
    }];
    [self waitForExpectationsWithTimeout:30.0 handler:nil];
    XCTestExpectation *objectsLoaded = [self expectationWithDescription:@"objectsLoaded"];
    [self.metadataManager loadMRUObjects:nil limit:1 cachePolicy:SFDataCachePolicyReloadAndReturnCacheOnFailure
                 refreshCacheIfOlderThan:kRefreshInterval networkFieldName:nil inRetry:NO completion:^(NSArray *results, BOOL isDataFromCache, BOOL needToReloadCache) {
                     XCTAssertNotEqualObjects(results, nil, @"MRU list should not be nil");
                     XCTAssertEqual(results.count, 1, @"MRU list size should be 1");
                     XCTAssertEqualObjects([[results firstObject] name], kCaseOneName, @"Recently viewed object name is incorrect");
                     [objectsLoaded fulfill];
                 } error:^(NSError *error) {
                     XCTFail(@"Error while loading objects %@", error);
                     [objectsLoaded fulfill];
    }];
    [self waitForExpectationsWithTimeout:30.0 handler:nil];
}

- (void)testCommonMRUObjectsFromServer
{
    //fetch test data
    SFSDKSoqlBuilder *queryBuilder = [[SFSDKSoqlBuilder withFields:@"Id"] from:@"Account"];
    [queryBuilder whereClause:[NSString stringWithFormat:@"Name = '%@'", kAccountOneName]];
    NSString *queryString = [queryBuilder build];
    [self sendQuery:queryString withCompeletionBlock:^(NSArray *result){
        kAccountOneId = [result[0] valueForKey:@"Id"];
    }];
    
    queryBuilder = [[SFSDKSoqlBuilder withFields:@"Id"] from:@"Opportunity"];
    [queryBuilder whereClause:[NSString stringWithFormat:@"Name = '%@'", kOpportunityOneName]];
    queryString = [queryBuilder build];
    [self sendQuery:queryString withCompeletionBlock:^(NSArray *result){
        kOpportunityOneId = [result[0] valueForKey:@"Id"];
    }];
    
    NSArray *objectTypesIdsNames = @[ @[ @"Account", kAccountOneId, kAccountOneName ], @[ @"Opportunity", kOpportunityOneId, kOpportunityOneName ]];
    for (NSArray *objectTypeIdName in objectTypesIdsNames) {
        NSString *objectType = objectTypeIdName[0];
        NSString *objectId = objectTypeIdName[1];
        NSString *objectName = objectTypeIdName[2];
        XCTestExpectation *objectMarkedAsViewed = [self expectationWithDescription:@"objectMarkedAsViewed"];
        [self.metadataManager markObjectAsViewed:objectId objectType:objectType networkFieldName:nil completionBlock:^() {
            [objectMarkedAsViewed fulfill];
        } error:^(NSError *error) {
            XCTFail(@"Error while marking object %@:%@ as viewed %@", objectName,objectId, error);
            [objectMarkedAsViewed fulfill];
        }];
        [self waitForExpectationsWithTimeout:30.0 handler:nil];
        XCTestExpectation *objectsLoaded = [self expectationWithDescription:@"objectsLoaded"];
        [self.metadataManager loadMRUObjects:objectType limit:1 cachePolicy:SFDataCachePolicyReloadAndReturnCacheOnFailure refreshCacheIfOlderThan:kRefreshInterval networkFieldName:nil inRetry:NO
                                  completion:^(NSArray *results, BOOL isDataFromCache, BOOL needToReloadCache) {
                                      XCTAssertNotEqualObjects(results, nil, @"MRU list should not be nil");
                                      XCTAssertEqual(results.count, 1, @"MRU list size should be 1");
                                      XCTAssertEqualObjects(((SFObject *)results[0]).objectId, objectId, @"Recently viewed object ID for object type '%@' is incorrect", objectType);
                                      XCTAssertEqualObjects(((SFObject *)results[0]).name, objectName, @"Recently viewed object name for object type '%@' is incorrect", objectType);
                                      [objectsLoaded fulfill];
                                  } error:^(NSError *error) {
                                      XCTFail(@"Error while loading objects %@", error);
                                      [objectsLoaded fulfill];
                                  }
         ];
        [self waitForExpectationsWithTimeout:30.0 handler:nil];
    }
}

- (void)testLoadAllObjectTypesFromServer
{
    XCTestExpectation *objectTypesLoaded = [self expectationWithDescription:@"objectTypesLoaded"];
    [self.metadataManager loadAllObjectTypes:SFDataCachePolicyReloadAndReturnCacheOnFailure refreshCacheIfOlderThan:kRefreshInterval
                                       completion:^(NSArray *results, BOOL isDataFromCache) {
                                           XCTAssertNotEqualObjects(results, nil, @"All objects list should not be nil");
                                           [objectTypesLoaded fulfill];
                                        } error:^(NSError *error) {
                                            XCTFail(@"Error while loading object types %@", error);
                                            [objectTypesLoaded fulfill];
                                        }
    ];
    [self waitForExpectationsWithTimeout:30.0 handler:nil];
}

- (void)testLoadCommonObjectTypesFromServer
{
    for (NSString *objectTypeName in @[ @"Case", @"Account", @"Opportunity" ]) {
        XCTestExpectation *objectTypeLoaded = [self expectationWithDescription:@"objectTypeLoaded"];
        [self.metadataManager loadObjectType:objectTypeName cachePolicy:SFDataCachePolicyReloadAndReturnCacheOnFailure refreshCacheIfOlderThan:kRefreshInterval
                                  completion:^(SFObjectType *result, BOOL isDataFromCache) {
                                      XCTAssertNotEqualObjects(result, nil, @"%@ metadata should not be nil", objectTypeName);
                                      [objectTypeLoaded fulfill];
                                  } error:^(NSError *error) {
                                      XCTFail(@"Error while loading object type %@", error);
                                      [objectTypeLoaded fulfill];
                                  }
        ];
        [self waitForExpectationsWithTimeout:30.0 handler:nil];
    }
}

- (void)testLoadUnknownObjectTypeFromServer
{
    XCTestExpectation *objectTypeLoaded = [self expectationWithDescription:@"objectTypeLoaded"];
    NSString *objectTypeName = [NSString stringWithFormat:@"RandomNonexistentObject_%u", arc4random()];
    [self.metadataManager loadObjectType:objectTypeName cachePolicy:SFDataCachePolicyReloadAndReturnCacheOnFailure refreshCacheIfOlderThan:kRefreshInterval
                              completion:^(SFObjectType *result, BOOL isDataFromCache) {
                                  XCTAssertNil(result, @"Unknown object type (%@) metadata should be nil", objectTypeName);
                                  [objectTypeLoaded fulfill];
                              } error:^(NSError *error) {
                                  XCTFail(@"Error while loading object type %@", error);
                                  [objectTypeLoaded fulfill];
                              }
    ];
    [self waitForExpectationsWithTimeout:30.0 handler:nil];
}

- (void)testLoadObjectTypeLayoutsFromServer
{
    XCTestExpectation *caseTypeLoaded = [self expectationWithDescription:@"caseTypeLoaded"];
    NSMutableArray *objectsToLoad = [NSMutableArray new];
    [self.metadataManager loadObjectType:@"Case" cachePolicy:SFDataCachePolicyReloadAndReturnCacheOnFailure refreshCacheIfOlderThan:kRefreshInterval
                              completion:^(SFObjectType *result, BOOL isDataFromCache) {
                                  if (result) {
                                      [objectsToLoad addObject:result];
                                  }
                                  [caseTypeLoaded fulfill];
                                } error:^(NSError *error) {
                                    XCTFail(@"Error while loading case type %@", error);
                                    [caseTypeLoaded fulfill];
                                }
    ];
    [self waitForExpectationsWithTimeout:30.0 handler:nil];
    XCTestExpectation *accountTypeLoaded = [self expectationWithDescription:@"accountTypeLoaded"];
    [self.metadataManager loadObjectType:@"Account" cachePolicy:SFDataCachePolicyReloadAndReturnCacheOnFailure refreshCacheIfOlderThan:kRefreshInterval
                                   completion:^(SFObjectType *result, BOOL isDataFromCache) {
                                       if (result) {
                                           [objectsToLoad addObject:result];
                                       }
                                       [accountTypeLoaded fulfill];
                                    } error:^(NSError *error) {
                                        XCTFail(@"Error while loading account type %@", error);
                                        [accountTypeLoaded fulfill];
                                    }
    ];
    [self waitForExpectationsWithTimeout:30.0 handler:nil];
    XCTestExpectation *opportunityTypeLoaded = [self expectationWithDescription:@"opportunityTypeLoaded"];
    [self.metadataManager loadObjectType:@"Opportunity" cachePolicy:SFDataCachePolicyReloadAndReturnCacheOnFailure refreshCacheIfOlderThan:kRefreshInterval
                                   completion:^(SFObjectType *result, BOOL isDataFromCache) {
                                       if (result) {
                                           [objectsToLoad addObject:result];
                                       }
                                       [opportunityTypeLoaded fulfill];
                                    } error:^(NSError *error) {
                                        XCTFail(@"Error while loading opportunity type %@", error);
                                        [opportunityTypeLoaded fulfill];
                                    }
    ];
    [self waitForExpectationsWithTimeout:30.0 handler:nil];
    XCTestExpectation *layoutsLoaded = [self expectationWithDescription:@"layoutsLoaded"];
    [self.metadataManager loadObjectTypesLayout:objectsToLoad cachePolicy:SFDataCachePolicyReloadAndReturnCacheOnFailure refreshCacheIfOlderThan:kRefreshInterval
                                          completion:^(NSArray *results, BOOL isDataFromCache) {
                                              XCTAssertNotEqualObjects(results, nil, @"Layout list should not be nil");
                                              XCTAssertEqual(results.count, 3, @"Layout list size should be 3");
                                              [layoutsLoaded fulfill];
                                            } error:^(NSError *error) {
                                                XCTFail(@"Error while loading layouts %@", error);
                                                [layoutsLoaded fulfill];
                                            }
    ];
    [self waitForExpectationsWithTimeout:30.0 handler:nil];
}

- (void)testRemoveMRUCache
{
    XCTestExpectation *objectsLoaded = [self expectationWithDescription:@"objectsLoaded"];
    [self.metadataManager loadMRUObjects:nil limit:1 cachePolicy:SFDataCachePolicyReloadAndReturnCacheOnFailure refreshCacheIfOlderThan:kRefreshInterval networkFieldName:nil inRetry:NO
                                   completion:^(NSArray *results, BOOL isDataFromCache, BOOL needToReloadCache) {
                                       XCTAssertNotEqualObjects(results, nil, @"MRU list should not be nil");
                                       XCTAssertEqual(results.count, 1, @"MRU list size should be 1");
                                       [objectsLoaded fulfill];
                                    } error:^(NSError *error) {
                                        XCTFail(@"Error while loading objects %@", error);
                                        [objectsLoaded fulfill];
                                    }
    ];
    [self waitForExpectationsWithTimeout:30.0 handler:nil];
    SFSmartSyncCacheManager *cacheMgr = [SFSmartSyncCacheManager sharedInstance:self.currentUser];
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
    XCTestExpectation *objectsLoaded = [self expectationWithDescription:@"objectsLoaded"];
    [self.metadataManager loadMRUObjects:nil limit:1 cachePolicy:SFDataCachePolicyReloadAndReturnCacheOnFailure refreshCacheIfOlderThan:kRefreshInterval networkFieldName:nil inRetry:NO
                                   completion:^(NSArray *results, BOOL isDataFromCache, BOOL needToReloadCache) {
                                       XCTAssertNotEqualObjects(results, nil, @"MRU list should not be nil");
                                       XCTAssertEqual(results.count, 1, @"MRU list size should be 1");
                                       [objectsLoaded fulfill];
                                    } error:^(NSError *error) {
                                        XCTFail(@"Error while loading objects %@", error);
                                        [objectsLoaded fulfill];
                                    }
    ];
    [self waitForExpectationsWithTimeout:30.0 handler:nil];
    SFSmartSyncCacheManager *cacheMgr = [SFSmartSyncCacheManager sharedInstance:self.currentUser];
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
    XCTestExpectation *objectTypesLoaded = [self expectationWithDescription:@"objectTypesLoaded"];
    [self.metadataManager loadAllObjectTypes:SFDataCachePolicyReloadAndReturnCacheOnFailure refreshCacheIfOlderThan:kRefreshInterval
                                       completion:^(NSArray *results, BOOL isDataFromCache) {
                                           XCTAssertNotEqualObjects(results, nil, @"All objects list should not be nil");
                                           [objectTypesLoaded fulfill];
                                        } error:^(NSError *error) {
                                            XCTFail(@"Error while loading object types %@", error);
                                            [objectTypesLoaded fulfill];
                                        }
    ];
    [self waitForExpectationsWithTimeout:30.0 handler:nil];
    SFSmartSyncCacheManager *cacheMgr = [SFSmartSyncCacheManager sharedInstance:self.currentUser];
    NSDate *cachedTime = nil;
    NSArray *cachedObjects = [cacheMgr readDataWithCacheType:kSFMetadataCacheType
                                                    cacheKey:kSFAllObjectsCacheKey
                                                 cachePolicy:SFDataCachePolicyReturnCacheDataDontReload
                                                 objectClass:[SFObjectType class]
                                                  cachedTime:&cachedTime];
    XCTAssertNotEqualObjects(cachedObjects, nil, @"Cached objects list should not be nil");
    XCTAssertNotEqual(cachedObjects.count, 0, @"Cached objects list should not be empty");
}

@end
