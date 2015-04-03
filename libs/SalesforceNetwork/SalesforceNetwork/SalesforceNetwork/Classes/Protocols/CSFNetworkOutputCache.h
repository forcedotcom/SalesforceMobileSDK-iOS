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

@class CSFNetwork, CSFAction;

/**
 Protocol description that allows arbitrary classes to define caching behavior for network output.
 */
@protocol CSFNetworkOutputCache <NSObject>

@required

/** Caches an action response.

 This initiates a cache operation, meant to store the relevant objects and persist them in some form of cache, as determined by the receiver.

 @param action          The completed action to cache
 @param completionBlock Block to be invoked when the cache operation is completed, or `nil`.
 */
- (void)cacheOutputFromAction:(CSFAction*)action completionBlock:(void(^)(NSError *error))completionBlock;

/**
 Informs the network instance whether or not this cache instance is capable of handling the output from the supplied action.
 
 @discussion
 This permits multiple cache handlers to handle requests from a network, but only process the actions that can be accommodated by them.  For example, some information should be stored in a SQLite database vs a flat-file on the file system, or cached as binary images on disk.

 @param action The action that is being processed.

 @return `YES` if the receiver is capable of caching this action, otherwise `NO` if the receiver should be skipped.
 */
- (BOOL)shouldCacheOutputFromAction:(CSFAction*)action;

@optional

/**
 Allows classes conforming CSFNetworkOutputCache to auto-generate and return cache instances to network instances as-needed.
 
 @param network Network instance configuring its cache output instances.

 @return Cache instance appropriate for the supplied network, or `nil` if this class doesn't have an instance available for the given network.Steps
 */
+ (NSObject<CSFNetworkOutputCache>*)cacheInstanceForNetwork:(CSFNetwork*)network;

@end
