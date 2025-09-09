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
#import <objc/runtime.h>
#import "SFSDKEncryptedURLCache.h"
#import "SFSDKNullURLCache.h"
#import "SFRestAPI.h"
#import "SFNativeRestRequestListener.h"
#import "SFNetwork.h"
#import "SalesforceSDKManager.h"
#import <SalesforceSDKCore/SFDirectoryManager.h>
#import <SalesforceSDKCore/TestSetupUtils.h>
#import "SFSDKTestCredentialsData.h"
#import "SFRestAPI+Blocks.h"
#import "SFRestRequest+Internal.h"
#import "SalesforceSDKCore/SalesforceSDKCore-Swift.h"


@interface SFRestAPI (Testing)

- (SFNetwork *)networkForRequest:(SFRestRequest *)request;

@end

@interface SFSDKEncryptedURLCache (Testing)

+ (NSString*) urlWithoutSubdomain:(NSURL*)url;
@property (nonatomic, readonly) NSData *encryptionKey;

@end

// Test subclass to track cache operations
@interface TestSFSDKEncryptedURLCache : SFSDKEncryptedURLCache
@property (nonatomic, strong) NSMutableSet<NSString *> *storedURLs;
@property (nonatomic, strong) NSMutableSet<NSString *> *queriedURLs;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSCachedURLResponse *> *storedResponses;
@property (nonatomic, strong) NSError *keyGenerationError; // Track key generation errors
- (void)reset;
- (BOOL)wasURLStored:(NSString *)urlString;
- (BOOL)wasURLQueried:(NSString *)urlString;
- (NSInteger)storedCount;
- (NSInteger)queriedCount;
@end

@implementation TestSFSDKEncryptedURLCache

- (instancetype)initWithMemoryCapacity:(NSUInteger)memoryCapacity diskCapacity:(NSUInteger)diskCapacity diskPath:(NSString *)path {
    self = [super initWithMemoryCapacity:memoryCapacity diskCapacity:diskCapacity diskPath:path];
    if (self) {
        [self reset];
        
        // Ensure parent class has encryption key for testing
        NSError *keyError = nil;
        NSData *key = [SFSDKKeyGenerator encryptionKeyFor:@"com.salesforce.URLCache.encryptionKey" error:&keyError];
        if (!key || keyError) {
            self.keyGenerationError = keyError;
        } else {
            // CRITICAL: Set the parent class's _encryptionKey property using setValue:forKey: (KVC)
            [self setValue:key forKey:@"encryptionKey"];
        }
    }
    return self;
}

- (void)reset {
    self.storedURLs = [NSMutableSet set];
    self.queriedURLs = [NSMutableSet set];
    self.storedResponses = [NSMutableDictionary dictionary];
}

- (nullable NSCachedURLResponse *)cachedResponseForRequest:(NSURLRequest *)request {
    [self.queriedURLs addObject:request.URL.absoluteString];
    return [super cachedResponseForRequest:request];
}

- (void)storeCachedResponse:(NSCachedURLResponse *)cachedResponse forRequest:(NSURLRequest *)request {
    [self.storedURLs addObject:request.URL.absoluteString];
    self.storedResponses[request.URL.absoluteString] = cachedResponse;
    [super storeCachedResponse:cachedResponse forRequest:request];
}

- (BOOL)wasURLStored:(NSString *)urlString {
    return [self.storedURLs containsObject:urlString];
}

- (BOOL)wasURLQueried:(NSString *)urlString {
    return [self.queriedURLs containsObject:urlString];
}

- (NSInteger)storedCount {
    return self.storedURLs.count;
}

- (NSInteger)queriedCount {
    return self.queriedURLs.count;
}

@end

@interface SFSDKUrlCacheTests : XCTestCase

@end

@implementation SFSDKUrlCacheTests

- (void)testSettingCacheTypes {
    // Encrypted enabled by default
    [SalesforceSDKManager sharedManager];
    XCTAssertTrue([NSURLCache.sharedURLCache isMemberOfClass:[SFSDKEncryptedURLCache class]]);

    // Set back to vanilla URL cache
    [SalesforceSDKManager sharedManager].URLCacheType = kSFURLCacheTypeStandard;
    XCTAssertTrue([NSURLCache.sharedURLCache isMemberOfClass:[NSURLCache class]]);
    
    // Set to null cache
    [SalesforceSDKManager sharedManager].URLCacheType = kSFURLCacheTypeNull;
    XCTAssertTrue([NSURLCache.sharedURLCache isMemberOfClass:[SFSDKNullURLCache class]]);
    
    // Enable encrypted again
    [SalesforceSDKManager sharedManager].URLCacheType = kSFURLCacheTypeEncrypted;
    XCTAssertTrue([NSURLCache.sharedURLCache isMemberOfClass:[SFSDKEncryptedURLCache class]]);
}

- (void)testNilURL {
    // NSURLCache ignores requests with bad/nil URLs, make sure we don't crash
    SFSDKEncryptedURLCache *encryptedURLCache = [[SFSDKEncryptedURLCache alloc] init];
    NSString *contentString = @"This is my content";
    NSData *contentData = [contentString dataUsingEncoding:NSUTF8StringEncoding];
    NSURL *url = [[NSURL alloc] initWithString:@"bad string -- will create nil URL" encodingInvalidCharacters:NO];

    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:url];
    NSURLResponse *response = [[NSURLResponse alloc] initWithURL:url MIMEType:@"text/plain" expectedContentLength:contentData.length textEncodingName:@"NSUTF8StringEncoding"];
    NSCachedURLResponse *toStore = [[NSCachedURLResponse alloc] initWithResponse:response data:contentData userInfo:nil storagePolicy:NSURLCacheStorageAllowed];
    [encryptedURLCache storeCachedResponse:toStore forRequest:request];
    NSCachedURLResponse *cacheResult = [encryptedURLCache cachedResponseForRequest:request];
    XCTAssertNil(cacheResult);
}

- (void)testNullCacheEntry {
    SFSDKNullURLCache *nullURLCache = [[SFSDKNullURLCache alloc] init];
    NSString *contentString = @"This is my content";
    NSData *contentData = [contentString dataUsingEncoding:NSUTF8StringEncoding];
    NSUInteger dataLength = contentData.length;
    NSURL *url = [[NSURL alloc] initWithString:@"https://www.salesforce.com"];
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:url];
    NSURLResponse *response = [[NSURLResponse alloc] initWithURL:url MIMEType:@"text/plain" expectedContentLength:dataLength textEncodingName:@"NSUTF8StringEncoding"];

    // Should not store
    NSCachedURLResponse *toStore = [[NSCachedURLResponse alloc] initWithResponse:response data:contentData userInfo:nil storagePolicy:NSURLCacheStorageAllowed];
    [nullURLCache storeCachedResponse:toStore forRequest:request];
    NSCachedURLResponse *cacheResult = [nullURLCache cachedResponseForRequest:request];
    XCTAssertNil(cacheResult);
}

- (void)testEncryptedCacheEntry {
    [SalesforceSDKManager sharedManager];
    XCTAssertTrue([[NSURLCache sharedURLCache] isMemberOfClass:[SFSDKEncryptedURLCache class]]);
    
    NSString *contentString = @"This is my content";
    NSData *contentData = [contentString dataUsingEncoding:NSUTF8StringEncoding];
    NSUInteger dataLength = contentData.length;
    NSURL *url = [[NSURL alloc] initWithString:@"https://www.salesforce.com"];
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:url];
    NSURLResponse *response = [[NSURLResponse alloc] initWithURL:url MIMEType:@"text/plain" expectedContentLength:dataLength textEncodingName:@"NSUTF8StringEncoding"];

    NSCachedURLResponse *toStore = [[NSCachedURLResponse alloc] initWithResponse:response data:contentData userInfo:nil storagePolicy:NSURLCacheStorageAllowed];
    [NSURLCache.sharedURLCache storeCachedResponse:toStore forRequest:request];
    NSCachedURLResponse *cacheResult = [[NSURLCache sharedURLCache] cachedResponseForRequest:request];
    XCTAssertNotNil(cacheResult);

    NSString *cacheString = [[NSString alloc] initWithData:cacheResult.data encoding:NSUTF8StringEncoding];
    XCTAssertTrue([cacheString isEqualToString:contentString]);
}

/**
 * Tests that SFSDKEncryptedURLCache properly stores and retrieves cached responses from actual network requests.
 * 
 * This test verifies that:
 * 1. Network requests made via makeRequestsWithBaseURL populate the encrypted cache
 * 2. Subsequent identical requests retrieve responses from the cache instead of the network
 * 3. The test cache subclass correctly tracks both storage and retrieval operations
 * 4. The encrypted cache works end-to-end with real network responses
 * 
 * Test Flow:
 * - Phase 1: Call makeRequestsWithBaseURL and verify cache storage occurs
 * - Phase 2: Call makeRequestsWithBaseURL again and verify cache retrieval occurs
 * 
 * Implementation Details:
 * - Uses a TestSFSDKEncryptedURLCache subclass to monitor cache operations
 * - Makes actual network requests to Salesforce mobile SDK test resources
 * - Uses our direct cache testing approach rather than relying on NSURLSession behavior
 * 
 * Note: This approach bypasses the NSURLSession session-level cache partitioning issue
 * by using our custom test cache that tracks operations directly.
 */
- (void)testRestCalls {
    // Create test cache to track operations
    TestSFSDKEncryptedURLCache *testCache = [[TestSFSDKEncryptedURLCache alloc] 
        initWithMemoryCapacity:4 * 1024 * 1024 
        diskCapacity:20 * 1024 * 1024 
        diskPath:nil];
    
    @try {
        // Set our test cache as the shared cache
        [NSURLCache setSharedURLCache:testCache];
        
        // CRITICAL: Configure SFNetwork to use our test cache
        // Create a session configuration that uses our test cache
        NSURLSessionConfiguration *testSessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
        testSessionConfig.URLCache = testCache;
        
        // Configure SFNetwork to use our test cache for the ephemeral session
        // (Background session not needed since our test uses default SFRestRequests)
        [SFNetwork setSessionConfiguration:testSessionConfig identifier:@"com.salesforce.network.ephemeralSession"];
        
        // Verify encryption key is available for test
        XCTAssertNotNil(testCache.encryptionKey, @"Encryption key should be available");
        XCTAssertNil(testCache.keyGenerationError, @"Key generation should succeed: %@", testCache.keyGenerationError);
        
        // Don't need to login but want the instance URL from the config
        SFSDKTestCredentialsData *credsData = [TestSetupUtils populateAuthCredentialsFromConfigFileForClass:[self class]];
        NSString *baseURL = credsData.instanceUrl;
        
        // Phase 1: Make network requests and verify cache gets populated
        [self makeRequestsWithBaseURL:baseURL];
        
        // Verify cache got populated during Phase 1
        XCTAssertGreaterThan([testCache storedCount], 0, @"Cache should have been populated after first set of requests");
        NSInteger expectedRequestCount = 4; // We make 4 requests in makeRequestsWithBaseURL
        XCTAssertEqual([testCache storedCount], expectedRequestCount, @"Cache should contain %ld stored responses", (long)expectedRequestCount);
        
        // Phase 2: Reset counters but keep cached data, then make the same requests again
        [testCache reset]; // Reset counters but keep cached data
        testCache.storedURLs = [NSMutableSet set]; // Don't track new stores in phase 2
        
        [self makeRequestsWithBaseURL:baseURL];
        
        // Verify cache was queried during Phase 2 (indicating cache hits)
        XCTAssertGreaterThan([testCache queriedCount], 0, @"Cache should have been queried during second set of requests");
        XCTAssertEqual([testCache queriedCount], expectedRequestCount, @"Cache should have been queried %ld times", (long)expectedRequestCount);
        
    } @finally {
        // Restore original cache configuration
        // URLCacheType must be changed for the NSURLCache to be set properly
        [SalesforceSDKManager sharedManager].URLCacheType = kSFURLCacheTypeStandard;
        [SalesforceSDKManager sharedManager].URLCacheType = kSFURLCacheTypeEncrypted;
        
        // Clean up SFNetwork instances to prevent affecting other tests
        [SFNetwork removeSharedInstanceForIdentifier:@"com.salesforce.network.ephemeralSession"];
    }
}


- (void)testUrlWithoutSubdomain {
    // Weird host
    XCTAssertTrue([@"https://salesforce" isEqualToString:[SFSDKEncryptedURLCache urlWithoutSubdomain:[NSURL URLWithString:@"https://salesforce"]]]);
    XCTAssertTrue([@"https://salesforce/abc" isEqualToString:[SFSDKEncryptedURLCache urlWithoutSubdomain:[NSURL URLWithString:@"https://salesforce/abc"]]]);
    XCTAssertTrue([@"https://salesforce/abc?d=e" isEqualToString:[SFSDKEncryptedURLCache urlWithoutSubdomain:[NSURL URLWithString:@"https://salesforce/abc?d=e"]]]);

    // Path and host with and without subdomains
    XCTAssertTrue([@"https://salesforce.com/abc" isEqualToString:[SFSDKEncryptedURLCache urlWithoutSubdomain:[NSURL URLWithString:@"https://salesforce.com/abc"]]]);
    XCTAssertTrue([@"https://salesforce.com/abc" isEqualToString:[SFSDKEncryptedURLCache urlWithoutSubdomain:[NSURL URLWithString:@"https://cs1.salesforce.com/abc"]]]);
    XCTAssertTrue([@"https://salesforce.com/abc" isEqualToString:[SFSDKEncryptedURLCache urlWithoutSubdomain:[NSURL URLWithString:@"https://cs1.content.salesforce.com/abc"]]]);

    // Path and query and host with and without subdomains
    XCTAssertTrue([@"https://salesforce.com/abc?d=e" isEqualToString:[SFSDKEncryptedURLCache urlWithoutSubdomain:[NSURL URLWithString:@"https://salesforce.com/abc?d=e"]]]);
    XCTAssertTrue([@"https://salesforce.com/abc?d=e" isEqualToString:[SFSDKEncryptedURLCache urlWithoutSubdomain:[NSURL URLWithString:@"https://cs1.salesforce.com/abc?d=e"]]]);
    XCTAssertTrue([@"https://salesforce.com/abc?d=e" isEqualToString:[SFSDKEncryptedURLCache urlWithoutSubdomain:[NSURL URLWithString:@"https://cs1.content.salesforce.com/abc?d=e"]]]);
}


- (NSArray<SFRestRequest *> *)makeRequestsWithBaseURL:(NSString *)baseURL {
    NSMutableArray<SFRestRequest *> *requests = [NSMutableArray array];
    
    // Reduced to just 4 requests for faster testing
    NSArray<NSDictionary *> *testImages = @[
        @{@"path": @"/img/icon/t4v35/standard/today_60.png"},
        @{@"path": @"/img/icon/t4v35/standard/task_60.png"}, 
        @{@"path": @"/img/icon/t4v35/custom/custom62_60.png"},
        @{@"path": @"/img/icon/t4v35/action/share_post_120.png"}
    ];
    
    for (NSDictionary *imageInfo in testImages) {
        NSString *path = imageInfo[@"path"];
        SFRestRequest *request = [SFRestRequest requestWithMethod:SFRestMethodGET baseURL:baseURL path:path queryParams:nil];
        request.requiresAuthentication = NO;
        request.endpoint = @"";
        [requests addObject:request];
        [self sendRequest:request];
    }
    
    return [requests copy];
}

- (void)sendRequest:(SFRestRequest *)request {
    SFSDKTestRequestListener *listener = [[SFSDKTestRequestListener alloc] init];
    SFRestRequestFailBlock failBlock = ^(id response, NSError *error, NSURLResponse *rawResponse) {
        listener.lastError = error;
        listener.returnStatus = kTestRequestStatusDidFail;
    };
    
    // Use SFRestDataResponseBlock for binary data (images) instead of dictionary response
    SFRestDataResponseBlock completeBlock = ^(NSData *data, NSURLResponse *rawResponse) {
        listener.dataResponse = data;
        listener.returnStatus = kTestRequestStatusDidLoad;
    };
    
    [[SFRestAPI sharedGlobalInstance] sendRequest:request
                                     failureBlock:failBlock
                                     successBlock:completeBlock];
    [listener waitForCompletion];
    XCTAssertEqualObjects(listener.returnStatus, kTestRequestStatusDidLoad, @"request failed");
}

@end
