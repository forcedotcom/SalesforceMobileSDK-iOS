/*
 Copyright (c) 2015, salesforce.com, inc. All rights reserved.
 
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

#import <objc/runtime.h>
#import <SalesforceSDKCore/SalesforceSDKCore.h>

#import "CSFNetwork+Internal.h"
#import "CSFNetwork+Salesforce.h"
#import "CSFAction+Internal.h"

#import "CSFInternalDefines.h"

// Value transformers used by model objects
#import "CSFDateValueTransformer.h"
#import "CSFURLValueTransformer.h"
#import "CSFPNGImageValueTransformer.h"
#import "CSFJPEGImageValueTransformer.h"
#import "CSFUTF8StringValueTransformer.h"

NSString * const CSFActionsStartedNotification = @"CSFActionsStartedNotification";
NSString * const CSFActionsCompletedNotification = @"CSFActionsCompletedNotification";
NSString * const CSFActionsRequiredByUICompletedNotification = @"CSFActionsRequiredByUICompletedNotification";

NSString * const CSFNetworkErrorDomain = @"CSFNetworkErrorDomain";

static void * kObservingKey = &kObservingKey;

NSString *CSFNetworkInstanceKey(SFUserAccount *user) {
    return [NSString stringWithFormat:@"%@-%@-%@", user.credentials.organizationId, user.credentials.userId, user.communityId];
}

@interface CSFNetwork() <SFAuthenticationManagerDelegate>

// This cache holds all the actions that have a limit per session
@property (nonatomic, retain) NSCache *actionSessionLimitCache;
@property (nonatomic, strong) dispatch_queue_t actionQueue;
@property (nonatomic, readwrite, getter = isOnline) BOOL online;

@property (nonatomic, strong) dispatch_queue_t duplicateActionDetectionQueue; //The queue used to check for duplicate actions
@end


@implementation CSFNetwork
@dynamic outputCachePointers;

#pragma mark -
#pragma mark object lifecycle

static NSMutableDictionary *SharedInstances = nil;

+ (void)initialize {
    if (self == [CSFNetwork class]) {
        SharedInstances = [[NSMutableDictionary alloc] initWithCapacity:1];
        
        [NSValueTransformer setValueTransformer:[[CSFURLValueTransformer alloc] init] forName:CSFURLValueTransformerName];
        [NSValueTransformer setValueTransformer:[[CSFDateValueTransformer alloc] init] forName:CSFDateValueTransformerName];
        [NSValueTransformer setValueTransformer:[[CSFPNGImageValueTransformer alloc] init] forName:CSFPNGImageValueTransformerName];
        [NSValueTransformer setValueTransformer:[[CSFJPEGImageValueTransformer alloc] init] forName:CSFJPEGImageValueTransformerName];
        [NSValueTransformer setValueTransformer:[[CSFUTF8StringValueTransformer alloc] init] forName:CSFUTF8StringValueTransformerName];
    }
}

+ (instancetype)currentNetwork {
    SFUserAccount *currentUser = [SFUserAccountManager sharedInstance].currentUser;
    CSFNetwork *instance = [self networkForUserAccount:currentUser];
    
    return instance;
}

+ (instancetype)networkForUserAccount:(SFUserAccount*)account {
    CSFNetwork *instance = nil;
    if (!account.isTemporaryUser) {
        @synchronized (SharedInstances) {
            instance = [CSFNetwork cachedNetworkForUserAccount:account];
            if (!instance) {
                NSString *key = CSFNetworkInstanceKey(account);
                instance = SharedInstances[key] = [[self alloc] initWithUserAccount:account];
            }
        }
    }
    
    return instance;
}

+ (instancetype)cachedNetworkForUserAccount:(SFUserAccount*)account {
    NSString *key = CSFNetworkInstanceKey(account);
    return SharedInstances[key];
}

+ (void)removeSharedInstance:(SFUserAccount*)userAccount {
    @synchronized (SharedInstances) {
        NSString *key = CSFNetworkInstanceKey(userAccount);
        [SharedInstances removeObjectForKey:key];
    }
}

#pragma mark -
#pragma mark object lifecycle

- (id)init {
    self = [super init];
    if (self) {
        NSString *queueName = [NSString stringWithFormat:@"CSFNetworkDuplicateActionDetectionQueue[%p]", self];
        self.duplicateActionDetectionQueue = dispatch_queue_create([queueName UTF8String], DISPATCH_QUEUE_SERIAL);
        
        self.queue = [NSOperationQueue new];
        [self.queue addObserver:self forKeyPath:@"operationCount" options:NSKeyValueObservingOptionNew context:kObservingKey];
        _online = YES;

        // Start the queue suspended, so we can unsuspend it when the user account object is set
        self.queue.suspended = YES;
        _networkSuspended = YES;
        
        self.progress = [NSProgress progressWithTotalUnitCount:0];
        
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
        self.ephemeralSession = [NSURLSession sessionWithConfiguration:configuration
                                                              delegate:self
                                                         delegateQueue:nil];
        #if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0
        if ([[NSURLSessionConfiguration class] respondsToSelector:@selector(backgroundSessionConfigurationWithIdentifier:)]) {
            self.backgroundSession = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"com.salesforce.network"]
                                                                   delegate:self
                                                              delegateQueue:nil];
        }
        #endif

        self.actionSessionLimitCache = [[NSCache alloc] init];
        
        self.actionQueue = dispatch_queue_create("com.salesforce.network.action", DISPATCH_QUEUE_SERIAL);
        
        NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
        #ifdef SFPlatformiOS
		[notificationCenter addObserver:self
												 selector:@selector(applicationDidBecomeActive:)
													 name:UIApplicationDidBecomeActiveNotification
												   object:nil];
        #endif
        [notificationCenter postNotificationName:CSFNetworkInitializedNotification object:self];
        
        // In Salesforce category
        [self setupSalesforceObserver];
    }
    return self;
}

- (id)initWithUserAccount:(SFUserAccount*)account {
    self = [self init];
    if (self) {
        self.account = account;
        [[SFAuthenticationManager sharedManager] addDelegate:self];
        self.userAgent = [SalesforceSDKManager sharedManager].userAgentString(@"");
    }
    return self;
}

- (void)dealloc {
    [self.queue removeObserver:self forKeyPath:@"operationCount" context:kObservingKey];
    [self.queue cancelAllOperations];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[SFAuthenticationManager sharedManager] removeDelegate:self];
}

- (void)setAccount:(SFUserAccount *)account {
    if (_account != account) {
        _account = account;
        
        self.networkSuspended = NO;
    }
}

- (void)setNetworkSuspended:(BOOL)networkSuspended {
    if (_networkSuspended != networkSuspended) {
        _networkSuspended = networkSuspended;
        self.queue.suspended = networkSuspended;
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == kObservingKey) {
        if (self.queue == object && [keyPath isEqualToString:@"operationCount"]) {
            self.actionCount = self.queue.operationCount;
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)resetSession {
    [self.actionSessionLimitCache removeAllObjects];
}

#pragma mark -
#pragma mark implementation

- (CSFAction*)duplicateActionInFlight:(CSFAction*)action {
    CSFAction *result = nil;
    if ([action.method isEqualToString:@"POST"] || [action.method isEqualToString:@"PUT"]) {
        // bypass duplicate detection for POST and PUT
        return result;
    }
    
    for (CSFAction *operation in self.queue.operations.reverseObjectEnumerator) {
        if (![operation isKindOfClass:[CSFAction class]])
            continue;
        if ([operation.method isEqualToString:@"POST"] || [operation.method isEqualToString:@"PUT"]) {
            // bypass duplicate detection for POST and PUT
            continue;
        }
        
 		if (operation.isFinished || operation.isCancelled) {
            // ignore finshed, cancelled ones
            continue;
        }
        if ([operation isEqualToAction:action]) {
            result = operation;
            break;
        }
    }
    return result;
}

/**
 Executes an action with its completion block. This method will make sure to handle the synchronous action if necessary.
 @param action The action to execute
 */
- (void)executeAction:(CSFAction *)action {
    if (!action)
        return;

    BOOL contributeProgress = [action shouldReportProgressToParent];
    if (contributeProgress) {
        [self.progress becomeCurrentWithPendingUnitCount:self.queue.operationCount + 1];
    }

    // Need to assign our network queue to the action so that the equality test
    // performed in duplicateActionInFlight: will match.
    action.enqueuedNetwork = self;
    
    
    if (contributeProgress) {
        [self.progress resignCurrent];
    }
    
    // bypass duplicate detection for POST and PUT
    if ([action.method isEqualToString:@"POST"] || [action.method isEqualToString:@"PUT"]) {
        [self.queue addOperation:action];
    }
    else {
        dispatch_async(self.duplicateActionDetectionQueue, ^{
            CSFAction *duplicateAction = [self duplicateActionInFlight:action];
            if (duplicateAction) {
                action.duplicateParentAction = duplicateAction;
                [action addDependency:duplicateAction];
            }
            [self.queue addOperation:action];
        });
    }
}

- (void)executeActions:(NSArray *)actions completionBlock:(void(^)(NSArray *actions, NSArray *errors))completionBlock {
    if (actions || actions.count == 0) {
        if (completionBlock) {
            completionBlock(nil, nil);
        }

        return;
    }

    NSBlockOperation *parentOperation = [NSBlockOperation blockOperationWithBlock:^{
        if (completionBlock) {
            // TODO: Iterate through the operations to assemble the error and action objects again
            completionBlock(nil, nil);
        }
    }];

    NSMutableArray *otherActions = [actions mutableCopy];
    if (otherActions.count > 0) {
        for (CSFAction *action in otherActions) {
            [parentOperation addDependency:action];
            [self executeAction:action];
        }
    }
    if (!(parentOperation.isCancelled || parentOperation.isFinished)) {
        [self.queue addOperation:parentOperation];
    }
}

- (NSArray*)actionsWithContext:(id)context {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"context = %@", context];
    return [self.queue.operations filteredArrayUsingPredicate:predicate];
}

- (void)cancelAllActions {
    [self.queue cancelAllOperations];
}

- (void)cancelAllActionsWithContext:(id)context {
    NSArray *operations = [self actionsWithContext:context];
    [operations makeObjectsPerformSelector:@selector(cancel)];
}

- (CSFAction*)actionForSessionTask:(NSURLSessionTask*)task {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"sessionTask = %@ OR downloadTask = %@", task, task];
    return [[self.queue.operations filteredArrayUsingPredicate:predicate] firstObject];
}

#pragma mark -

#pragma mark NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    CSFAction *action = [self actionForSessionTask:task];
    [action sessionTask:task didCompleteWithError:error];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    CSFAction *action = [self actionForSessionTask:dataTask];
    [action sessionDataTask:dataTask didReceiveData:data];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didBecomeDownloadTask:(NSURLSessionDownloadTask *)downloadTask {
    CSFAction *action = [self actionForSessionTask:dataTask];
    action.downloadTask = downloadTask;
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location {
    CSFAction *action = [self actionForSessionTask:downloadTask];
    [action sessionDownloadTask:downloadTask didFinishDownloadingToURL:location];
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    CSFAction *action = [self actionForSessionTask:downloadTask];
    [action sessionDownloadTask:downloadTask didWriteData:bytesWritten totalBytesWritten:totalBytesWritten totalBytesExpectedToWrite:totalBytesExpectedToWrite];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend {
    CSFAction *action = [self actionForSessionTask:task];
    [action sessionUploadTask:task didSendBodyData:bytesSent totalBytesSent:totalBytesSent totalBytesExpectedToSend:totalBytesExpectedToSend];
}

#pragma mark - Device Authorization support

// TODO: This should probably be relocated to the CSFSalesforceAction logic, and cleaned up
//       so that it fires a notification of some sort so we can decouple the alert view work.
//       This way we don't ahve to reference UIKit from the network stack, and the consumer
//       is capable of handling the unauthorized response.
- (void)receivedDevicedUnauthorizedError:(CSFAction *)action {
}

#pragma mark - SFAuthenticationManagerDelegate

- (void)authManager:(SFAuthenticationManager *)manager willLogoutUser:(SFUserAccount *)user {
    [[self class] removeSharedInstance:user];
}


@end
