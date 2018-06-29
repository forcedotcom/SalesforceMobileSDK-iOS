/*
 SFSDKOAuthClientCache.h
 SalesforceSDKCore

 Created by Raj Rao on 9/27/17.

 Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.

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

/**
 Enumeration of types of different types of client maintained in cache.
 */
typedef NS_ENUM(NSUInteger, SFOAuthClientKeyType) {
    /**
     The default server target, which uses standard REST requests to post updates.
     */
    SFOAuthClientKeyTypeBasic = 0,
    
    /**
     Server target is a custom target, that manages its own server update logic.
     */
    SFOAuthClientKeyTypeAdvanced,
    
    /**
     Server target is a custom target, that manages its own server update logic.
     */
    SFOAuthClientKeyTypeIDP,
};


@class SFSDKOAuthClient;
@class SFOAuthCredentials;

@interface SFSDKOAuthClientCache : NSObject

/** Fetch A Client from the cache given key
 * @param key to use for lookup
 * @return a cached instance of SFSDKOAuthClient
 */
- (SFSDKOAuthClient *)clientForKey:(NSString *)key;

/** Add A Client to the cache given key
 *
 * @param client instance to add
 */
- (void)addClient:(SFSDKOAuthClient *)client;

/** Add A Client to the cache given key
 *
 * @param client instance to add
 */
- (void)addClient:(SFSDKOAuthClient *)client forKey:(NSString *)key;

/** Remove A Cached Client given key
 * @param key to use for looking up client
 */
- (void)removeClientForKey:(NSString *)key;

/** Remove a Cached Client
 * @param client being removed
 */
- (void)removeClient:(SFSDKOAuthClient *)client;

/** Remove All Cached Clients
 */
- (void)removeAllClients;

/** Shared Singleton
 */
+ (instancetype) sharedInstance;


/** Get unique key from a client instance
 */
+ (NSString *)keyFromClient:(SFSDKOAuthClient *)client;

/** Get unique key from SFOAuthCredentials
 */
+ (NSString *)keyFromCredentials:(SFOAuthCredentials *)credentials;

/** Get unique key from SFOAuthCredentials
 */
+ (NSString *)keyFromCredentials:(SFOAuthCredentials *)client type:(SFOAuthClientKeyType) clientType;
;

/** Get a state identifier key encode for type of client specified
 */
+ (NSString *)keyFromIdentifierPrefixWithType:(NSString *)prefix type:(SFOAuthClientKeyType)clientType;

@end
