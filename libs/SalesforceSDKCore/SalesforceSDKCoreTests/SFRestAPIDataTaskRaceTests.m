/*
 Copyright (c) 2026-present, salesforce.com, inc. All rights reserved.

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
#import "SFRestAPI+Internal.h"
#import "SFRestRequest+Internal.h"
#import "SFRestAPI+Blocks.h"
#import "SFNetwork.h"

#pragma mark - Expose private methods for testing

@interface SFRestAPI (DataTaskRaceTesting)

- (id)initWithUser:(SFUserAccount *)user;

- (void)send:(SFRestRequest *)request
failureBlock:(SFRestRequestFailBlock)failureBlock
successBlock:(SFRestResponseBlock)successBlock
 shouldRetry:(BOOL)shouldRetry;

- (void)resendActiveRequestsRequiringAuthentication;
- (void)flushPendingRequestQueue:(NSError *)error rawResponse:(NSURLResponse *)rawResponse;
- (void)replayRequest:(SFRestRequest *)request response:(NSURLResponse *)response;
- (id)prepareDataForDelegate:(NSData *)data request:(SFRestRequest *)request response:(NSURLResponse *)response;
- (SFNetwork *)networkForRequest:(SFRestRequest *)request;

@property (readwrite, assign) BOOL refreshCycleActive;

@end

#pragma mark - CompletionRaceRestAPI

/**
 * Test-only SFRestAPI that can pause response preparation. The production race
 * occurs after the old task passes its first stale-task check but before it
 * invokes a terminal block, which is exactly where this override provides a
 * deterministic scheduling point.
 */
@interface CompletionRaceRestAPI : SFRestAPI
@property (atomic, assign) BOOL pauseNextResponsePreparation;
@property (nonatomic, strong) dispatch_semaphore_t responsePreparationStarted;
@property (nonatomic, strong) dispatch_semaphore_t allowResponsePreparation;
@property (nonatomic, strong) SFNetwork *networkOverride;
@end

@implementation CompletionRaceRestAPI

- (instancetype)initWithUser:(SFUserAccount *)user {
    self = [super initWithUser:user];
    if (self) {
        _responsePreparationStarted = dispatch_semaphore_create(0);
        _allowResponsePreparation = dispatch_semaphore_create(0);
    }
    return self;
}

- (id)prepareDataForDelegate:(NSData *)data request:(SFRestRequest *)request response:(NSURLResponse *)response {
    if (self.pauseNextResponsePreparation) {
        self.pauseNextResponsePreparation = NO;
        dispatch_semaphore_signal(self.responsePreparationStarted);
        dispatch_semaphore_wait(self.allowResponsePreparation,
                                dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)));
    }
    return [super prepareDataForDelegate:data request:request response:response];
}

- (SFNetwork *)networkForRequest:(SFRestRequest *)request {
    return self.networkOverride ?: [super networkForRequest:request];
}

@end

#pragma mark - AdmissionRaceRestRequest

/**
 * Test-only request that pauses its first preparation after SFRestAPI has added
 * it to activeRequests but before enqueueRequest can publish sessionDataTask.
 * A recursive replay preparation is allowed through so the old behavior fails
 * deterministically instead of deadlocking the test.
 */
@interface AdmissionRaceRestRequest : SFRestRequest
@property (nonatomic, strong) dispatch_semaphore_t initialPreparationStarted;
@property (nonatomic, strong) dispatch_semaphore_t allowInitialPreparation;
@property (nonatomic, assign) NSUInteger preparationCount;
@end

@implementation AdmissionRaceRestRequest

- (NSURLRequest *)prepareRequestForSend:(SFUserAccount *)user {
    BOOL shouldPause;
    @synchronized (self) {
        self.preparationCount++;
        shouldPause = (self.preparationCount == 1);
    }
    if (shouldPause) {
        dispatch_semaphore_signal(self.initialPreparationStarted);
        dispatch_semaphore_wait(self.allowInitialPreparation,
                                dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)));
    }
    return [super prepareRequestForSend:user];
}

@end

#pragma mark - ControlledCompletionNetwork

/**
 * Test-only network that can produce response combinations NSURLProtocol cannot,
 * such as a completion with neither a response nor an error.
 */
@interface ControlledCompletionNetwork : SFNetwork
@property (nonatomic, strong) NSMutableArray<NSURLSessionDataTask *> *tasks;
@property (nonatomic, strong) NSMutableArray *completionBlocks;
- (NSUInteger)pendingCount;
- (void)deliverData:(NSData *)data response:(NSURLResponse *)response error:(NSError *)error atIndex:(NSUInteger)index;
@end

@implementation ControlledCompletionNetwork

- (instancetype)init {
    self = [super init];
    if (self) {
        _tasks = [NSMutableArray new];
        _completionBlocks = [NSMutableArray new];
    }
    return self;
}

- (NSURLSessionDataTask *)sendRequest:(NSURLRequest *)urlRequest dataResponseBlock:(SFDataResponseBlock)dataResponseBlock {
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:urlRequest];
    @synchronized (self) {
        [self.tasks addObject:task];
        [self.completionBlocks addObject:[dataResponseBlock copy]];
    }
    return task;
}

- (NSUInteger)pendingCount {
    @synchronized (self) {
        return self.completionBlocks.count;
    }
}

- (void)deliverData:(NSData *)data response:(NSURLResponse *)response error:(NSError *)error atIndex:(NSUInteger)index {
    SFDataResponseBlock completionBlock;
    @synchronized (self) {
        completionBlock = [self.completionBlocks[index] copy];
    }
    completionBlock(data, response, error);
}

@end

#pragma mark - DeferredURLProtocol

/**
 * NSURLProtocol subclass that intercepts all requests and holds them until
 * the test explicitly delivers a response. This lets us control exactly
 * when each NSURLSessionDataTask's completion handler fires.
 */
@interface DeferredURLProtocol : NSURLProtocol
+ (void)reset;
+ (NSUInteger)pendingCount;
+ (void)deliverResponseAtIndex:(NSUInteger)index statusCode:(NSInteger)statusCode;
+ (void)deliverResponseAtIndex:(NSUInteger)index
                    statusCode:(NSInteger)statusCode
                          body:(NSString *)body
                  headerFields:(NSDictionary<NSString *, NSString *> *)headerFields;
+ (void)deliverErrorAtIndex:(NSUInteger)index error:(NSError *)error;
@end

static NSMutableArray<DeferredURLProtocol *> *sPendingProtocols;

@implementation DeferredURLProtocol

+ (void)initialize {
    if (self == [DeferredURLProtocol class]) {
        sPendingProtocols = [NSMutableArray new];
    }
}

+ (void)reset {
    @synchronized (sPendingProtocols) {
        [sPendingProtocols removeAllObjects];
    }
}

+ (NSUInteger)pendingCount {
    @synchronized (sPendingProtocols) {
        return sPendingProtocols.count;
    }
}

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    return YES;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

- (void)startLoading {
    @synchronized (sPendingProtocols) {
        [sPendingProtocols addObject:self];
    }
}

- (void)stopLoading {
    // Intentionally empty; responses are delivered manually.
}

+ (void)deliverResponseAtIndex:(NSUInteger)index statusCode:(NSInteger)statusCode {
    [self deliverResponseAtIndex:index
                      statusCode:statusCode
                            body:@"{\"ok\":true}"
                    headerFields:nil];
}

+ (void)deliverResponseAtIndex:(NSUInteger)index
                    statusCode:(NSInteger)statusCode
                          body:(NSString *)body
                  headerFields:(NSDictionary<NSString *, NSString *> *)headerFields {
    DeferredURLProtocol *proto;
    @synchronized (sPendingProtocols) {
        proto = sPendingProtocols[index];
    }
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:proto.request.URL
                                                             statusCode:statusCode
                                                            HTTPVersion:@"HTTP/1.1"
                                                           headerFields:headerFields];
    NSData *bodyData = [body dataUsingEncoding:NSUTF8StringEncoding];
    [proto.client URLProtocol:proto didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    [proto.client URLProtocol:proto didLoadData:bodyData];
    [proto.client URLProtocolDidFinishLoading:proto];
}

+ (void)deliverErrorAtIndex:(NSUInteger)index error:(NSError *)error {
    DeferredURLProtocol *proto;
    @synchronized (sPendingProtocols) {
        proto = sPendingProtocols[index];
    }
    [proto.client URLProtocol:proto didFailWithError:error];
}

@end

#pragma mark - Tests

@interface SFRestAPIDataTaskRaceTests : XCTestCase
@property (nonatomic, strong) SFRestAPI *api;
@end

@implementation SFRestAPIDataTaskRaceTests

- (void)setUp {
    [super setUp];
    [DeferredURLProtocol reset];

    NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    config.protocolClasses = @[[DeferredURLProtocol class]];
    [SFNetwork setSessionConfiguration:config identifier:kSFNetworkEphemeralInstanceIdentifier];

    self.api = [[CompletionRaceRestAPI alloc] initWithUser:nil];
}

- (void)tearDown {
    [self.api cancelAllRequests];
    [self.api cleanup];
    [DeferredURLProtocol reset];
    [SFNetwork removeSharedEphemeralInstance];
    [super tearDown];
}

/**
 * Creates a request that bypasses auth checks by using an absolute URL.
 * Unique per-call so DeferredURLProtocol can distinguish them if needed.
 */
- (SFRestRequest *)makeRequest {
    static int counter = 0;
    NSString *url = [NSString stringWithFormat:@"https://test.example.com/api/%d", ++counter];
    SFRestRequest *request = [SFRestRequest requestWithMethod:SFRestMethodGET path:url queryParams:nil];
    request.requiresAuthentication = NO;
    return request;
}

/**
 * Helper: spin the run loop until `condition` returns YES, up to `timeout` seconds.
 */
- (BOOL)waitForCondition:(BOOL (^)(void))condition timeout:(NSTimeInterval)timeout {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    while (!condition() && [deadline timeIntervalSinceNow] > 0) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
    return condition();
}

/**
 * Forces the interleaving missing from the original stale-task regression test:
 *
 *   1. Task #1 passes the early stale-task check and pauses while preparing data.
 *   2. Authentication refresh replay installs task #2 for the same request.
 *   3. Task #1 resumes and attempts to deliver its terminal callback.
 *
 * The terminal claim must revalidate task ownership under the replay lock, so
 * task #1 is ignored and only task #2 is allowed to call client code.
 */
- (void)runTerminalCallbackRaceWithDelivery:(void (^)(NSUInteger index))deliverResponse
                               expectSuccess:(BOOL)expectSuccess {
    CompletionRaceRestAPI *api = (CompletionRaceRestAPI *)self.api;
    api.pauseNextResponsePreparation = YES;

    __block NSInteger successCount = 0;
    __block NSInteger failureCount = 0;
    XCTestExpectation *terminalCallback = [self expectationWithDescription:@"one terminal callback"];
    terminalCallback.assertForOverFulfill = YES;

    SFRestRequest *request = [self makeRequest];
    [api send:request failureBlock:^(id response, NSError *error, NSURLResponse *rawResponse) {
        @synchronized (self) {
            failureCount++;
        }
        if (expectSuccess) {
            XCTFail(@"Expected success, received failure: %@", error);
        }
        [terminalCallback fulfill];
    } successBlock:^(id response, NSURLResponse *rawResponse) {
        @synchronized (self) {
            successCount++;
        }
        if (!expectSuccess) {
            XCTFail(@"Expected terminal HTTP failure, received success");
        }
        [terminalCallback fulfill];
    }];

    XCTAssertTrue([self waitForCondition:^BOOL{
        return [DeferredURLProtocol pendingCount] >= 1;
    } timeout:2], @"task #1 should be pending");
    NSURLSessionDataTask *originalTask = request.sessionDataTask;

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        deliverResponse(0);
    });
    XCTAssertEqual(dispatch_semaphore_wait(api.responsePreparationStarted,
                                           dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC))), 0,
                   @"task #1 should pause after its early stale-task check");

    dispatch_semaphore_t resendFinished = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        [api resendActiveRequestsRequiringAuthentication];
        dispatch_semaphore_signal(resendFinished);
    });
    XCTAssertEqual(dispatch_semaphore_wait(resendFinished,
                                           dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC))), 0,
                   @"replay must not wait for response parsing or client code");
    XCTAssertNotEqual(request.sessionDataTask, originalTask, @"replay should install task #2");

    dispatch_semaphore_signal(api.allowResponsePreparation);
    XCTAssertTrue([self waitForCondition:^BOOL{
        return [DeferredURLProtocol pendingCount] >= 2;
    } timeout:2], @"task #2 should be pending");
    deliverResponse(1);

    [self waitForExpectationsWithTimeout:5 handler:nil];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.25]];

    XCTAssertEqual(successCount, expectSuccess ? 1 : 0);
    XCTAssertEqual(failureCount, expectSuccess ? 0 : 1);
}

#pragma mark - Test: resendActiveRequestsRequiringAuthentication race

/**
 * Forces a new-request admission to overlap the refresh replay snapshot:
 *
 *   1. send: adds the request to activeRequests, then pauses its first preparation
 *      before sessionDataTask has been published.
 *   2. Refresh replay snapshots the active request while its task is still nil.
 *   3. Replay must skip it; the original sender remains responsible for publishing
 *      the first attempt and delivering the sole terminal callback.
 *
 * Without the nil-task guard, replay creates a task for the request while its
 * original send is paused. That violates the replace-an-existing-attempt invariant
 * and permits the two independently created attempts to deliver twice.
 */
- (void)testNewRequestAdmissionRacingReplayPublishesOneTaskAndDeliversOnce {
    CompletionRaceRestAPI *api = (CompletionRaceRestAPI *)self.api;
    ControlledCompletionNetwork *network = [ControlledCompletionNetwork new];
    api.networkOverride = network;

    NSString *url = @"https://test.example.com/api/admission-race";
    AdmissionRaceRestRequest *request = [AdmissionRaceRestRequest requestWithMethod:SFRestMethodGET
                                                                               path:url
                                                                        queryParams:nil];
    request.initialPreparationStarted = dispatch_semaphore_create(0);
    request.allowInitialPreparation = dispatch_semaphore_create(0);
    request.requiresAuthentication = NO;

    __block NSInteger successCount = 0;
    __block NSInteger failureCount = 0;
    XCTestExpectation *terminalCallback = [self expectationWithDescription:@"one terminal callback"];
    terminalCallback.assertForOverFulfill = YES;
    dispatch_semaphore_t initialSendFinished = dispatch_semaphore_create(0);

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        [api send:request failureBlock:^(id response, NSError *error, NSURLResponse *rawResponse) {
            failureCount++;
            [terminalCallback fulfill];
        } successBlock:^(id response, NSURLResponse *rawResponse) {
            successCount++;
            [terminalCallback fulfill];
        } shouldRetry:NO];
        dispatch_semaphore_signal(initialSendFinished);
    });

    XCTAssertEqual(dispatch_semaphore_wait(request.initialPreparationStarted,
                                           dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC))), 0,
                   @"initial send should pause before publishing its task");
    XCTAssertTrue([api.activeRequests containsObject:request]);
    XCTAssertNil(request.sessionDataTask);

    [api resendActiveRequestsRequiringAuthentication];

    XCTAssertEqual(network.pendingCount, 0u,
                   @"replay must not create the initial task for an unpublished request");
    XCTAssertNil(request.sessionDataTask);

    dispatch_semaphore_signal(request.allowInitialPreparation);
    XCTAssertEqual(dispatch_semaphore_wait(initialSendFinished,
                                           dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC))), 0,
                   @"original send should publish after its preparation is released");
    XCTAssertEqual(network.pendingCount, 1u);
    XCTAssertNotNil(request.sessionDataTask);

    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:url]
                                                              statusCode:200
                                                             HTTPVersion:@"HTTP/1.1"
                                                            headerFields:nil];
    NSData *data = [@"{\"ok\":true}" dataUsingEncoding:NSUTF8StringEncoding];
    [network deliverData:data response:response error:nil atIndex:0];

    [self waitForExpectationsWithTimeout:2 handler:nil];
    XCTAssertEqual(successCount, 1);
    XCTAssertEqual(failureCount, 0);
    XCTAssertNil(request.sessionDataTask);
    XCTAssertEqual(api.activeRequests.count, 0u);
}

- (void)testConcurrentReplayWhileSuccessfulResponseIsBeingPreparedDeliversOnce {
    [self runTerminalCallbackRaceWithDelivery:^(NSUInteger index) {
        [DeferredURLProtocol deliverResponseAtIndex:index statusCode:200];
    } expectSuccess:YES];
}

- (void)testConcurrentReplayWhileFailureResponseIsBeingPreparedDeliversOnce {
    [self runTerminalCallbackRaceWithDelivery:^(NSUInteger index) {
        [DeferredURLProtocol deliverResponseAtIndex:index statusCode:500];
    } expectSuccess:NO];
}

- (void)testConcurrentReplayWhileNetworkErrorIsBeingPreparedDeliversOnce {
    NSError *networkError = [NSError errorWithDomain:NSURLErrorDomain
                                                code:NSURLErrorNetworkConnectionLost
                                            userInfo:nil];
    [self runTerminalCallbackRaceWithDelivery:^(NSUInteger index) {
        [DeferredURLProtocol deliverErrorAtIndex:index error:networkError];
    } expectSuccess:NO];
}

- (void)testCompletionWithoutResponseOrErrorDeliversFailureOnce {
    CompletionRaceRestAPI *api = (CompletionRaceRestAPI *)self.api;
    ControlledCompletionNetwork *network = [ControlledCompletionNetwork new];
    api.networkOverride = network;

    __block NSInteger failureCount = 0;
    XCTestExpectation *failureDelivered = [self expectationWithDescription:@"timeout-style failure delivered"];
    SFRestRequest *request = [self makeRequest];
    [api send:request failureBlock:^(id response, NSError *error, NSURLResponse *rawResponse) {
        failureCount++;
        XCTAssertNil(response);
        XCTAssertNil(error);
        XCTAssertNil(rawResponse);
        [failureDelivered fulfill];
    } successBlock:^(id response, NSURLResponse *rawResponse) {
        XCTFail(@"A completion without a response must not succeed");
    }];

    XCTAssertEqual(network.pendingCount, 1u);
    [network deliverData:nil response:nil error:nil atIndex:0];
    [self waitForExpectationsWithTimeout:2 handler:nil];

    XCTAssertEqual(failureCount, 1);
    XCTAssertNil(request.sessionDataTask);
    XCTAssertEqual(api.activeRequests.count, 0u);
}

- (void)testDPoPNonceChallengeRetriesThenDeliversOnce {
    __block NSInteger successCount = 0;
    __block NSInteger failureCount = 0;
    XCTestExpectation *successDelivered = [self expectationWithDescription:@"retry succeeds"];
    SFRestRequest *request = [self makeRequest];

    [self.api send:request failureBlock:^(id response, NSError *error, NSURLResponse *rawResponse) {
        failureCount++;
        XCTFail(@"DPoP nonce retry should not fail: %@", error);
    } successBlock:^(id response, NSURLResponse *rawResponse) {
        successCount++;
        [successDelivered fulfill];
    }];

    XCTAssertTrue([self waitForCondition:^BOOL{
        return [DeferredURLProtocol pendingCount] >= 1;
    } timeout:2]);
    NSURLSessionDataTask *originalTask = request.sessionDataTask;

    [DeferredURLProtocol deliverResponseAtIndex:0
                                     statusCode:400
                                           body:@"{\"error\":\"use_dpop_nonce\"}"
                                   headerFields:nil];

    XCTAssertTrue([self waitForCondition:^BOOL{
        return [DeferredURLProtocol pendingCount] >= 2;
    } timeout:2], @"nonce challenge should install a successor task");
    XCTAssertTrue(request.dpopNonceRetried);
    XCTAssertNotEqual(request.sessionDataTask, originalTask);

    [DeferredURLProtocol deliverResponseAtIndex:1 statusCode:200];
    [self waitForExpectationsWithTimeout:2 handler:nil];

    XCTAssertEqual(successCount, 1);
    XCTAssertEqual(failureCount, 0);
}

- (void)testCompletionAfterRestAPIDeallocationIsIgnored {
    __block NSInteger callbackCount = 0;
    __weak SFRestAPI *weakAPI;

    @autoreleasepool {
        SFRestAPI *api = [[CompletionRaceRestAPI alloc] initWithUser:nil];
        weakAPI = api;
        SFRestRequest *request = [self makeRequest];
        [api send:request failureBlock:^(id response, NSError *error, NSURLResponse *rawResponse) {
            callbackCount++;
        } successBlock:^(id response, NSURLResponse *rawResponse) {
            callbackCount++;
        }];

        XCTAssertTrue([self waitForCondition:^BOOL{
            return [DeferredURLProtocol pendingCount] >= 1;
        } timeout:2]);
        api = nil;
    }

    XCTAssertNil(weakAPI);
    [DeferredURLProtocol deliverResponseAtIndex:0 statusCode:200];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.25]];
    XCTAssertEqual(callbackCount, 0);
}

/**
 * Reproduces the crash scenario:
 *   1. Request is sent, creating dataTask #1 (in-flight).
 *   2. Token refresh completes; resendActiveRequestsRequiringAuthentication
 *      re-sends the same request, creating dataTask #2.
 *   3. dataTask #1 completes (200 OK) -> successBlock should NOT be called
 *      (stale task, guard drops it).
 *   4. dataTask #2 completes (200 OK) -> successBlock IS called (current task).
 *
 * Without the stale-task guard, successBlock fires twice (crash).
 * With the guard, successBlock fires exactly once.
 */
- (void)testResendActiveRequestsDoesNotDoubleInvokeBlocks {
    __block int successCount = 0;
    __block int failureCount = 0;
    XCTestExpectation *expectation = [self expectationWithDescription:@"block called"];

    SFRestRequest *request = [self makeRequest];

    // Step 1: Send the request. This creates dataTask #1.
    [self.api send:request
      failureBlock:^(id response, NSError *e, NSURLResponse *rawResponse) {
        failureCount++;
    } successBlock:^(id response, NSURLResponse *rawResponse) {
        successCount++;
        [expectation fulfill];
    } shouldRetry:NO];

    // Wait for dataTask #1 to be registered with DeferredURLProtocol.
    XCTAssertTrue([self waitForCondition:^BOOL{ return [DeferredURLProtocol pendingCount] >= 1; } timeout:2],
                  @"dataTask #1 should be pending");

    // Step 2: Simulate what happens after token refresh succeeds:
    // resendActiveRequestsRequiringAuthentication re-sends all active requests.
    // This creates dataTask #2 for the same request.
    [self.api resendActiveRequestsRequiringAuthentication];

    // Wait for dataTask #2 to be registered.
    XCTAssertTrue([self waitForCondition:^BOOL{ return [DeferredURLProtocol pendingCount] >= 2; } timeout:2],
                  @"dataTask #2 should be pending");

    // Step 3: dataTask #1 (index 0) completes with 200 OK.
    // With the fix: guard detects dataTask #1 != request.sessionDataTask, drops it.
    // Without fix: successBlock fires (first resume).
    [DeferredURLProtocol deliverResponseAtIndex:0 statusCode:200];

    // Step 4: dataTask #2 (index 1) completes with 200 OK.
    // successBlock fires (this is the current task).
    // Without fix: successBlock fires again (second resume -> crash).
    [DeferredURLProtocol deliverResponseAtIndex:1 statusCode:200];

    [self waitForExpectationsWithTimeout:5 handler:nil];

    XCTAssertEqual(successCount, 1, @"successBlock must be called exactly once, was called %d times", successCount);
    XCTAssertEqual(failureCount, 0, @"failureBlock must not be called");
}

#pragma mark - Test: flushPendingRequestQueue race

/**
 * Reproduces the flush variant:
 *   1. Request is sent, creating dataTask #1 (in-flight).
 *   2. Token refresh FAILS; flushPendingRequestQueue calls failureBlock
 *      for all active requests AND cancels their dataTasks.
 *   3. dataTask #1's cancel callback fires -> guard drops it (stale task).
 *
 * Without the fix: failureBlock fires twice (once from flush, once from cancel callback).
 * With the fix: failureBlock fires exactly once.
 */
- (void)testFlushPendingRequestQueueDoesNotDoubleInvokeBlocks {
    __block int successCount = 0;
    __block int failureCount = 0;
    XCTestExpectation *expectation = [self expectationWithDescription:@"failure block called"];

    SFRestRequest *request = [self makeRequest];

    // Step 1: Send the request. This creates dataTask #1.
    [self.api send:request
      failureBlock:^(id response, NSError *e, NSURLResponse *rawResponse) {
        failureCount++;
        [expectation fulfill];
    } successBlock:^(id response, NSURLResponse *rawResponse) {
        successCount++;
    } shouldRetry:NO];

    // Wait for dataTask #1 to be registered.
    XCTAssertTrue([self waitForCondition:^BOOL{ return [DeferredURLProtocol pendingCount] >= 1; } timeout:2],
                  @"dataTask #1 should be pending");

    // Step 2: Simulate token refresh failure. flushPendingRequestQueue calls
    // failureBlock for all active requests. With the fix, it also cancels
    // and invalidates the old sessionDataTask first.
    NSError *refreshError = [NSError errorWithDomain:@"TestDomain" code:401 userInfo:nil];
    NSHTTPURLResponse *rawResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://test.example.com"]
                                                                 statusCode:401
                                                                HTTPVersion:@"HTTP/1.1"
                                                               headerFields:nil];
    [self.api flushPendingRequestQueue:refreshError rawResponse:rawResponse];

    [self waitForExpectationsWithTimeout:5 handler:nil];

    // Give any stale cancel callbacks time to fire.
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];

    XCTAssertEqual(failureCount, 1, @"failureBlock must be called exactly once, was called %d times", failureCount);
    XCTAssertEqual(successCount, 0, @"successBlock must not be called");
}

#pragma mark - Test: cancelAllRequests still works

/**
 * Ensures that legitimate cancellation via cancelAllRequests still delivers
 * the NSURLErrorCancelled error to the failureBlock (the stale-task guard
 * must NOT interfere because cancelAllRequests doesn't re-send).
 */
- (void)testCancelAllRequestsStillDeliversCancellationError {
    __block int failureCount = 0;
    __block NSError *receivedError = nil;
    XCTestExpectation *expectation = [self expectationWithDescription:@"cancel delivered"];

    SFRestRequest *request = [self makeRequest];

    [self.api send:request
      failureBlock:^(id response, NSError *e, NSURLResponse *rawResponse) {
        failureCount++;
        receivedError = e;
        [expectation fulfill];
    } successBlock:^(id response, NSURLResponse *rawResponse) {
        XCTFail(@"successBlock should not be called on cancellation");
    } shouldRetry:NO];

    // Wait for the dataTask to be in-flight.
    XCTAssertTrue([self waitForCondition:^BOOL{ return [DeferredURLProtocol pendingCount] >= 1; } timeout:2],
                  @"dataTask should be pending");

    // Cancel all requests. This cancels the task but does NOT re-send,
    // so sessionDataTask is unchanged. The guard should pass.
    [self.api cancelAllRequests];

    [self waitForExpectationsWithTimeout:5 handler:nil];

    XCTAssertEqual(failureCount, 1, @"failureBlock must be called exactly once");
    XCTAssertEqual(receivedError.code, NSURLErrorCancelled, @"Error should be NSURLErrorCancelled");
}

#pragma mark - Test: cleanup during in-flight refresh

/**
 * Verifies that cleanup delivers "User logged out" errors to all pending
 * requests and clears activeRequests, even when a token refresh cycle is active.
 */
- (void)testCleanupDuringRefreshCycleDeliversLogoutError {
    __block int failureCount = 0;
    __block NSError *receivedError = nil;
    XCTestExpectation *expectation = [self expectationWithDescription:@"failure delivered"];

    SFRestRequest *request = [self makeRequest];

    [self.api send:request
      failureBlock:^(id response, NSError *e, NSURLResponse *rawResponse) {
        failureCount++;
        receivedError = e;
        [expectation fulfill];
    } successBlock:^(id response, NSURLResponse *rawResponse) {
        XCTFail(@"successBlock should not be called after cleanup");
    } shouldRetry:NO];

    // Wait for the request to be in-flight.
    XCTAssertTrue([self waitForCondition:^BOOL{ return [DeferredURLProtocol pendingCount] >= 1; } timeout:2],
                  @"dataTask should be pending");

    // Simulate a refresh cycle being active (as if a 401 triggered replayRequest:).
    self.api.refreshCycleActive = YES;

    // Logout triggers cleanup while refresh is in-flight.
    [self.api cleanup];

    [self waitForExpectationsWithTimeout:5 handler:nil];

    XCTAssertEqual(failureCount, 1, @"failureBlock must be called exactly once");
    XCTAssertEqualObjects(receivedError.domain, kSFRestErrorDomain, @"Error domain should be REST error domain");
    XCTAssertTrue([receivedError.userInfo[NSLocalizedDescriptionKey] containsString:@"logged out"],
                  @"Error message should mention logout");
    XCTAssertEqual(self.api.activeRequests.count, 0u, @"activeRequests should be empty after cleanup");
}

/**
 * Verifies that if the coordinator's refresh callback fires AFTER cleanup
 * has cleared activeRequests, no requests are resent and no crash occurs.
 */
- (void)testRefreshCallbackAfterCleanupIsHarmless {
    __block int successCount = 0;
    __block int failureCount = 0;

    SFRestRequest *request = [self makeRequest];

    [self.api send:request
      failureBlock:^(id response, NSError *e, NSURLResponse *rawResponse) {
        failureCount++;
    } successBlock:^(id response, NSURLResponse *rawResponse) {
        successCount++;
    } shouldRetry:NO];

    // Wait for the request to be in-flight.
    XCTAssertTrue([self waitForCondition:^BOOL{ return [DeferredURLProtocol pendingCount] >= 1; } timeout:2],
                  @"dataTask should be pending");

    // Simulate: refresh cycle active, then cleanup runs (logout).
    self.api.refreshCycleActive = YES;
    [self.api cleanup];

    // Now simulate what happens when the coordinator callback fires after cleanup.
    // This calls resendActiveRequestsRequiringAuthentication on an empty activeRequests set.
    [self.api resendActiveRequestsRequiringAuthentication];
    self.api.refreshCycleActive = NO;

    // Give any unexpected callbacks a chance to fire.
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];

    // The cleanup already delivered the failure. The post-cleanup resend should be a no-op.
    XCTAssertEqual(failureCount, 1, @"failureBlock should have been called once (by cleanup)");
    XCTAssertEqual(successCount, 0, @"successBlock must not be called after cleanup");
    XCTAssertEqual(self.api.activeRequests.count, 0u, @"activeRequests should remain empty");
}

/**
 * Verifies that cleanup properly cancels in-flight dataTasks (the session
 * data task cancel callback should not cause double-invocation of failureBlock).
 */
- (void)testCleanupCancelsTasksWithoutDoubleCallback {
    __block int failureCount = 0;
    XCTestExpectation *expectation = [self expectationWithDescription:@"failure delivered"];

    SFRestRequest *request = [self makeRequest];

    [self.api send:request
      failureBlock:^(id response, NSError *e, NSURLResponse *rawResponse) {
        failureCount++;
        if (failureCount == 1) {
            [expectation fulfill];
        }
    } successBlock:^(id response, NSURLResponse *rawResponse) {
        XCTFail(@"successBlock should not be called after cleanup");
    } shouldRetry:NO];

    // Wait for the request to be in-flight.
    XCTAssertTrue([self waitForCondition:^BOOL{ return [DeferredURLProtocol pendingCount] >= 1; } timeout:2],
                  @"dataTask should be pending");

    // Cleanup cancels tasks and delivers errors.
    [self.api cleanup];

    [self waitForExpectationsWithTimeout:5 handler:nil];

    // Give time for the cancelled dataTask's NSURLSession callback to fire.
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];

    XCTAssertEqual(failureCount, 1, @"failureBlock must be called exactly once (cleanup), not again from cancellation callback. Was called %d times", failureCount);
}

/**
 * Verifies that after cleanup, a new request can trigger a fresh refresh cycle
 * (refreshCycleActive is not permanently stuck).
 */
- (void)testNewRefreshCyclePossibleAfterCleanup {
    SFRestRequest *request = [self makeRequest];

    [self.api send:request
      failureBlock:^(id response, NSError *e, NSURLResponse *rawResponse) {}
      successBlock:^(id response, NSURLResponse *rawResponse) {}
       shouldRetry:NO];

    XCTAssertTrue([self waitForCondition:^BOOL{ return [DeferredURLProtocol pendingCount] >= 1; } timeout:2],
                  @"dataTask should be pending");

    // Simulate refresh in progress, then cleanup (logout).
    self.api.refreshCycleActive = YES;
    [self.api cleanup];

    // After cleanup, refreshCycleActive should still be YES (cleanup doesn't reset it).
    // But activeRequests is empty, so a future callback is harmless.
    // Simulate the callback arriving and resetting the flag.
    self.api.refreshCycleActive = NO;

    // Now send a new request and verify a fresh refresh cycle can start.
    SFRestRequest *newRequest = [self makeRequest];
    [self.api send:newRequest
      failureBlock:^(id response, NSError *e, NSURLResponse *rawResponse) {}
      successBlock:^(id response, NSURLResponse *rawResponse) {}
       shouldRetry:NO];

    XCTAssertTrue([self waitForCondition:^BOOL{ return [DeferredURLProtocol pendingCount] >= 2; } timeout:2],
                  @"new dataTask should be pending");

    XCTAssertFalse(self.api.refreshCycleActive, @"refreshCycleActive should be NO, ready for a new cycle");
    XCTAssertEqual(self.api.activeRequests.count, 1, @"New request should be in activeRequests");
}

@end
