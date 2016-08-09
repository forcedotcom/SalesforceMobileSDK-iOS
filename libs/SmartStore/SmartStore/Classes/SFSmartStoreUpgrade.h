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

#import <Foundation/Foundation.h>
#import <SalesforceSDKCore/SFUserAccount.h>

/**
 Used internally for upgrading SmartStore.
 */
@interface SFSmartStoreUpgrade : NSObject

/**
 Updates any existing stores from their legacy location to their new user-specific location.
 */
+ (void)updateStoreLocations;

/**
 Updates the encryption scheme of each SmartStore database to the currently supported scheme.
 */
+ (void)updateEncryption;

/**
 Whether or not a given store for the given user is encrypted based on the key store key.
 @param user The user associated with the store.
 @param storeName The store to query.
 @return YES if the store is encrypted with the key store, NO otherwise.
 */
+ (BOOL)usesKeyStoreEncryptionForUser:(SFUserAccount *)user store:(NSString *)storeName;

/**
 Sets a flag denoting whether or not the store for the given user uses encryption based the key store key.
 @param usesKeyStoreEncryption YES if it does, NO if it doesn't.
 @param user The user associated with the store.
 @param storeName The store to which the flag applies.
 */
+ (void)setUsesKeyStoreEncryption:(BOOL)usesKeyStoreEncryption forUser:(SFUserAccount *)user store:(NSString *)storeName;

@end
