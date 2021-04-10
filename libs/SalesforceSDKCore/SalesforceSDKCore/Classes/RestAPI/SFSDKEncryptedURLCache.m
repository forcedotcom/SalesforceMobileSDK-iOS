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

#import "SFSDKEncryptedURLCache.h"
#import "SFKeyStoreManager.h"
#import "NSData+SFAdditions.h"

static NSString * const kURLSchemePrefix = @"sfsdkURLCache://";
static NSString * const kURLCacheEncryptionKeyLabel = @"com.salesforce.URLCache.encryptionKey";

@interface SFSDKEncryptedURLCache()

@property SFEncryptionKey *encryptionKey;

@end

@implementation SFSDKEncryptedURLCache

- (instancetype)initWithMemoryCapacity:(NSUInteger)memoryCapacity
                          diskCapacity:(NSUInteger)diskCapacity
                          directoryURL:(nullable NSURL *)directoryURL {
    self = [super initWithMemoryCapacity:memoryCapacity diskCapacity:diskCapacity directoryURL:directoryURL];
    if (self) {
        _encryptionKey = [[SFKeyStoreManager sharedInstance] retrieveKeyWithLabel:kURLCacheEncryptionKeyLabel autoCreate:YES];
    }
    return self;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _encryptionKey = [[SFKeyStoreManager sharedInstance] retrieveKeyWithLabel:kURLCacheEncryptionKeyLabel autoCreate:YES];
    }
    return self;
}

- (nullable NSCachedURLResponse *)cachedResponseForRequest:(NSURLRequest *)request {
    // For request.URL
    NSURLRequest *requestWithSecureURL = [self requestWithSecureURLForRequest:request];
    if (!requestWithSecureURL) {
        [SFSDKCoreLogger e:[self class] format:@"RequestWithSecureURL is nil, unable to fetch cached response"];
        return nil;
    }

    // For response.data
    NSCachedURLResponse *cachedResponse = [super cachedResponseForRequest:requestWithSecureURL];
    if (cachedResponse) {
        NSData *decryptedResponseData = [self.encryptionKey decryptData:cachedResponse.data];
        if (decryptedResponseData) {
            NSCachedURLResponse *decryptedURLResponse = [[NSCachedURLResponse alloc] initWithResponse:cachedResponse.response data:decryptedResponseData userInfo:cachedResponse.userInfo storagePolicy:cachedResponse.storagePolicy];
            return decryptedURLResponse;
        } else {
             [SFSDKCoreLogger e:[self class] format:@"Unable to decrypt cached response"];
        }
    }
    return nil;
}

- (void)storeCachedResponse:(NSCachedURLResponse *)cachedResponse
                 forRequest:(NSURLRequest *)request {
    // For request.URL
    NSURLRequest *requestWithSecureURL = [self requestWithSecureURLForRequest:request];
    if (!requestWithSecureURL) {
        [SFSDKCoreLogger e:[self class] format:@"RequestWithSecureURL is nil, unable to store response"];
        return;
    }
    
    // For cachedResponse.data
    NSData *encryptedResponseData = [self.encryptionKey encryptData:cachedResponse.data];
    if (!encryptedResponseData) {
        [SFSDKCoreLogger e:[self class] format:@"Unable to encrypt response to store"];
        return;
    }
    NSCachedURLResponse *encryptedURLResponse = [[NSCachedURLResponse alloc] initWithResponse:cachedResponse.response data:encryptedResponseData userInfo:cachedResponse.userInfo storagePolicy:cachedResponse.storagePolicy];

    [super storeCachedResponse:encryptedURLResponse forRequest:requestWithSecureURL];
}

- (void)removeCachedResponseForRequest:(NSURLRequest *)request {
    NSURLRequest *requestWithSecureURL = [self requestWithSecureURLForRequest:request];
    if (!requestWithSecureURL) {
        [SFSDKCoreLogger e:[self class] format:@"RequestWithSecureURL is nil, unable to remove cached response"];
        return;
    }
    [super removeCachedResponseForRequest:requestWithSecureURL];
}

- (nullable NSURLRequest *)requestWithSecureURLForRequest:(nonnull NSURLRequest *)request {
    if (!request.URL) {
        [SFSDKCoreLogger e:[self class] format:@"Request URL is nil"];
        return nil;
    }
    
    NSString *URLHash = [request.URL.dataRepresentation sha256];
    NSString *prefixedURL = [NSString stringWithFormat:@"%@%@", kURLSchemePrefix, URLHash];
    NSURL *secureURL = [[NSURL alloc] initWithString:prefixedURL];
    return [[NSURLRequest alloc] initWithURL:secureURL cachePolicy:request.cachePolicy timeoutInterval:request.timeoutInterval];
}

@end
