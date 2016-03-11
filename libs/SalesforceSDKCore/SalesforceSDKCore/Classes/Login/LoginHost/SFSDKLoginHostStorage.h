/*
 SFSDKLoginHostStorage.h
 SalesforceSDKCore
 
 Created by Kunal Chitalia on 1/22/16.
 Copyright (c) 2016, salesforce.com, inc. All rights reserved.
 
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

@class SFSDKLoginHost;

/**
 * This class manages the list of login hosts as well its persistence.
 * Currently this list is persisted in the user defaults.
 */
@interface SFSDKLoginHostStorage : NSObject

/**
 * Returns the shared instance of this class.
 */
+ (SFSDKLoginHostStorage *)sharedInstance;

/**
 * Adds a new login host.
 * @param loginHost Login host to be added
 */
- (void)addLoginHost:(SFSDKLoginHost *)loginHost;

/**
 * Removes the login host at the specified index.
 * @param index Index of the login host
 */
- (void)removeLoginHostAtIndex:(NSUInteger)index;

/**
 * Returns the index of the specified host if exists.
 * @param host Requested login host
 */
- (NSUInteger)indexOfLoginHost:(SFSDKLoginHost *)host;

/**
 * Returns the login host at the specified index.
 * @param index Requested index
 */
- (SFSDKLoginHost *)loginHostAtIndex:(NSUInteger)index;

/**
 * Returns the login host with a particular host address, if any.
 * @param hostAddress Address to be queried
 */
- (SFSDKLoginHost *)loginHostForHostAddress:(NSString *)hostAddress;

/**
 * Removes all the login hosts.
 */
- (void)removeAllLoginHosts;

/**
 * Returns the number of login hosts.
 */
- (NSUInteger)numberOfLoginHosts;

/**
 * Stores all the login host except the non-deletable ones in the user defaults.
 */
- (void)save;

@end
