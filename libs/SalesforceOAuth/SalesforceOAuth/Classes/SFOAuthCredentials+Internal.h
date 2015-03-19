/*
 Copyright (c) 2011, salesforce.com, inc. All rights reserved.
 
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

#import "SFOAuthCredentials.h"
#import <SalesforceSecurity/SFEncryptionKey.h>

typedef NS_ENUM(NSUInteger, SFOAuthCredsEncryptionType) {
    kSFOAuthCredsEncryptionTypeNotSet,
    kSFOAuthCredsEncryptionTypeMac,
    kSFOAuthCredsEncryptionTypeIdForVendor,
    kSFOAuthCredsEncryptionTypeBaseAppId,
    kSFOAuthCredsEncryptionTypeKeyStore
};

extern NSString * const kSFOAuthEncryptionTypeKey;
extern NSString * const kSFOAuthServiceAccess;
extern NSString * const kSFOAuthServiceRefresh;
extern NSString * const kSFOAuthServiceActivation;

@interface SFOAuthCredentials ()

- (NSData *)keyMacForService:(NSString *)service;
- (NSData *)keyVendorIdForService:(NSString *)service;
- (NSData *)keyBaseAppIdForService:(NSString*)service;
- (SFEncryptionKey *)keyStoreKeyForService:(NSString *)service;
- (NSData *)keyWithSeed:(NSString *)seed service:(NSString *)service;
- (NSString *)refreshTokenWithKey:(NSData *)key;
- (NSString *)refreshTokenWithSFEncryptionKey:(SFEncryptionKey *)encryptionKey;
- (void)setRefreshToken:(NSString *)token withSFEncryptionKey:(SFEncryptionKey *)key;
- (NSString *)accessTokenWithKey:(NSData *)key;
- (NSString *)accessTokenWithSFEncryptionKey:(SFEncryptionKey *)encryptionKey;
- (void)setAccessToken:(NSString *)token withSFEncryptionKey:(SFEncryptionKey *)key;
- (void)updateTokenEncryption;

// These are only for unit tests of legacy functionality.  Do not use in app code!
- (void)setAccessToken:(NSString *)token withKey:(NSData *)key;
- (void)setRefreshToken:(NSString *)token withKey:(NSData *)key;

@end


