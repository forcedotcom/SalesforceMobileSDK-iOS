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

#import <Foundation/Foundation.h>

@class CSFAction;
@class SFUserAccount;
@protocol CSFNetworkOutputCache;
@protocol CSFNetworkDelegate;

/**
 This is the scheduler and network dispatch class for managing a series of network operations
 on behalf of an application.  Each instance is bound to an individual user account, and manages
 the OAuth2 token refresh, queueing and scheduling of network operations, handling the parsing
 of responses, and aggregation of common actions into batches.
 */
@interface CSFNetwork : NSObject

@property (nonatomic, readonly, strong) NSURLSession *ephemeralSession;

/** Indicates whether the network operation queue is suspended or not.
 
 @discussion
 This value will be automatically updated as network availability or
 OAuth2 access refreshes occur.  It can be manually set to temporarily
 suspend the queue.
 */
@property (nonatomic, assign, getter = isNetworkSuspended) BOOL networkSuspended;
@property (nonatomic, readonly, getter = isOnline) BOOL online;

/** The count of network requests currently queued for processing.
 */
@property (nonatomic, assign, readonly) NSUInteger actionCount;

/** The user account instance this CSFNetwork represents.
 */
@property (nonatomic, strong, readonly) SFUserAccount *account;

/**
 * Indicates if the access token for this user account is being refreshed.
 *
 * During a token refresh, all active operations in the queue are suspended while the
 * token is updated.  When the token is refreshed, the queue will resume.
 *
 * @see networkSuspended
 */
@property (atomic, readonly, getter=isRefreshingAccessToken) BOOL refreshingAccessToken;

/**
 Reports aggregated progress information for all actions currently enqueued in this network instance.
 */
@property (nonatomic, strong, readonly) NSProgress *progress;

/**
 Returns the network instance for the currently active user account.
 
 @see networkForUserAccount:
 */
+ (instancetype)currentNetwork;

/** Returns a reference to the shared instance of this class for the supplied user.
 
 If an instance doesn't yet exist for this user, one will be created.

 @see currentNetwork
 */
+ (instancetype)networkForUserAccount:(SFUserAccount*)account;

/**
 Schedules and executes the supplied action on this network stack.
*/
- (void)executeAction:(CSFAction *)action;

/**
 Executes each action in the array of actions, used for batch mode.
 */
- (void)executeActions:(NSArray *)actions completionBlock:(void(^)(NSArray *actions, NSArray *errors))completionBlock;

/**
 Cancel all operations.
 */
- (void)cancelAllActions;

/**
 * Cancel all operations matching the given context instance.
 *
 * @see [CSFAction context]
 */
- (void)cancelAllActionsWithContext:(id)context;

/**
 * Returns a set of enqueued operations that have the given context.
 *
 * @see [CSFAction context]
 */
- (NSArray*)actionsWithContext:(id)context;

/**
 Cross-site Request Forgery (CSRF) token provided in each server response and required for all Push API
 requests that change state (i.e. POST).
 */
@property (nonatomic, copy) NSString *securityToken;

- (void)addDelegate:(id<CSFNetworkDelegate>)delegate;
- (void)removeDelegate:(id<CSFNetworkDelegate>)delegate;

@end

@interface CSFNetwork (Salesforce)

/** The ID for the Chatter Community that all Connect actions should use.
 
 Not all actions are Chatter Connect requests, nor do all Connect requests need to be
 made against a Chatter Community.  But if a CHConnectAction request is enqueued that
 has a nil [CHConnectAction communityId] value, then this property will be used to set
 the default value that should be used.
 
 If this value is `nil` then all CHConnectAction requests whose communityId value is
 `nil` will not be altered.
 
 @see [CSFChatterAction communityId]
 */
@property (nonatomic, copy) NSString *defaultConnectCommunityId;

@end

@interface CSFNetwork (Caching)

/** Indicates if caching the results of network requests through a local cache is enabled.

 @discussion
 This utilizes the instance supplied to the outputCache property to create a local persistent store
 to serialize the contents of network responses for use in accessing data offline.

 @see CSFNetworkOutputCache
 @see [CSFAction cacheResponse]
 */
@property (nonatomic, assign, getter = isOfflineCacheEnabled) BOOL offlineCacheEnabled;

/** List of output cache handlers that will be used for storing results retrieved from this network instance.

 @discussion
 This array will contain a list of all the cache handlers that should be consulted when results are retrieved.  Each object should conform to the CSFNetworkOutputCache protocol, and will each be interrogated in turn to determine whether or not they are capable of processing the results of each action.
 
 @see addOutputCache:
 @see removeOutputCache:
 */
@property (nonatomic, copy, readonly) NSArray *outputCaches;

/**
 Explicitly adds an output cache handler to this network instance.
 
 @discussion
 Output caches support a plugin architechture where classes that implement the CSFNetworkOutputCache method cacheInstanceForNetwork: are automatically asked whether or not they should be supported within the supplied network instance.  If you don't utilize this mechanism, explicit cache instances can be added using this method here.

 @param outputCache Output cache instance to add.
 */
- (void)addOutputCache:(NSObject<CSFNetworkOutputCache> *)outputCache;

/**
 Explicitly removes the indicated output cache handler from this network instance.

 @param outputCache Output cache instance to remove.
 */
- (void)removeOutputCache:(NSObject<CSFNetworkOutputCache> *)outputCache;

@end

@protocol CSFNetworkDelegate <NSObject>

@optional
/** Called when an action is about to get enqueued.
 
 @discussion
 This method is called synchronously, giving the delegates a chance to inspect the action before CSFNetwork acts on it.
 Perform as little work as possible on this callback to avoid performance degradation.
 */
- (void)network:(CSFNetwork*)network willEnqueueAction:(CSFAction*)action;

/** These methods inform delegates asynchronously about state of actions.
 */
- (void)network:(CSFNetwork*)network didStartAction:(CSFAction*)action;
- (void)network:(CSFNetwork*)network didCancelAction:(CSFAction*)action;
- (void)network:(CSFNetwork*)network didCompleteAction:(CSFAction*)action withError:(NSError*)error;

/** Inform delegates asynchronously about states of tasks for an action
 
 @discussion
 This method enables monitoring states of particular tasks that an action might trigger.
 @see NSURLSessionTaskState
 */
- (void)network:(CSFNetwork*)network
    sessionTask:(NSURLSessionTask*)task
   changedState:(NSURLSessionTaskState)oldState
        toState:(NSURLSessionTaskState)newState
      forAction:(CSFAction*)action;


@end

