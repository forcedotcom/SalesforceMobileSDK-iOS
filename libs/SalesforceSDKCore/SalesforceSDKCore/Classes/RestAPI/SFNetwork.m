/*
 SFNetwork.m
 SalesforceSDKCore
 
 Created by Bharath Hariharan on 2/15/17.
 
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

#import "SFNetwork.h"
#import "SalesforceSDKManager.h"
#import <SalesforceSDKCommon/SFSDKSafeMutableDictionary.h>

NSString * const kSFNetworkEphemeralSessionIdentifier = @"com.salesforce.network.ephemeralSession";
NSString * const kSFNetworkBackgroundSessionIdentifier = @"com.salesforce.network.backgroundSession";

@interface SFNetwork()<NSURLSessionDelegate>

@property (nonatomic, readwrite, strong) NSURLSession *activeSession;

@end

@implementation SFNetwork

static NSURLSessionConfiguration *kSFSessionConfig;
__weak static id<SFNetworkSessionManaging> kSFNetworkManager;

+ (instancetype)defaultEphemeralNetwork {
    NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    return [[self alloc] initWithSessionIdentifier:kSFNetworkEphemeralSessionIdentifier sessionConfiguration:sessionConfiguration];
}

+ (instancetype)defaultBackgroundNetwork {
    NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:kSFNetworkBackgroundSessionIdentifier];
    return [[self alloc] initWithSessionIdentifier:kSFNetworkBackgroundSessionIdentifier sessionConfiguration:sessionConfiguration];
}

+ (instancetype)networkWithSessionIdentifier:(nonnull NSString *)identifier sessionConfiguration:(nullable NSURLSessionConfiguration *)sessionConfiguration {
    return [[self alloc] initWithSessionIdentifier:identifier sessionConfiguration:sessionConfiguration];
}

- (instancetype)initWithSessionIdentifier:(nonnull NSString *)identifier sessionConfiguration:(nullable NSURLSessionConfiguration *)sessionConfiguration {
    self = [super init];
    if (self) {
        if (kSFNetworkManager) {
            self.activeSession = [kSFNetworkManager sessionWithIdentifier:identifier sessionConfiguration:sessionConfiguration];
            return self;
        }

        NSURLSession *session = [[self class] sharedSessions][identifier];
        if (!session) {
            if (!sessionConfiguration) {
                sessionConfiguration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
            }
            session = [NSURLSession sessionWithConfiguration:sessionConfiguration delegate:self delegateQueue:nil];
            [[self class] mutableSharedSessions][identifier] = session;
        }
        self.activeSession = session;
    }
    return self;
}

- (instancetype)initWithEphemeralSession {
    self = [super init];
    if (self) {
        NSURLSessionConfiguration *ephemeralSessionConfig = [NSURLSessionConfiguration ephemeralSessionConfiguration];
        if (kSFSessionConfig) {
            ephemeralSessionConfig = kSFSessionConfig;
        }
        if (kSFNetworkManager) {
            self.activeSession = [kSFNetworkManager ephemeralSession:ephemeralSessionConfig];
        } else {
            self.activeSession = [NSURLSession sessionWithConfiguration:ephemeralSessionConfig];
        }
    }
    return self;
}

- (instancetype)initWithBackgroundSession {
    self = [super init];
    if (self) {
        NSString *identifier = [NSString stringWithFormat:@"com.salesforce.network.%lu", (unsigned long)self.hash];
        NSURLSessionConfiguration *backgroundSessionConfig = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:identifier];
        if (kSFSessionConfig) {
            backgroundSessionConfig = kSFSessionConfig;
        }
        if (kSFNetworkManager) {
            self.activeSession = [kSFNetworkManager backgroundSession:backgroundSessionConfig];
        } else {
            self.activeSession = [NSURLSession sessionWithConfiguration:backgroundSessionConfig];
        }
    }
    return self;
}

- (NSURLSessionDataTask *)sendRequest:(NSMutableURLRequest *)urlRequest dataResponseBlock:(SFDataResponseBlock)dataResponseBlock {

    // Sets Mobile SDK user agent if it hasn't been set already elsewhere.
    if (![urlRequest.allHTTPHeaderFields.allKeys containsObject:@"User-Agent"]) {
        [urlRequest setValue:[SalesforceSDKManager sharedManager].userAgentString(@"") forHTTPHeaderField:@"User-Agent"];
    }
    NSURLSessionDataTask *dataTask = [self.activeSession dataTaskWithRequest:urlRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (dataResponseBlock) {
            dataResponseBlock(data, response, error);
        }
    }];
    [dataTask resume];
    return dataTask;
}

+ (void)setSessionConfiguration:(nonnull NSURLSessionConfiguration *)sessionConfig identifier:(nonnull NSString *)identifier {
    [SFNetwork removeSharedSessionForIdentifier:identifier];
    [SFNetwork networkWithSessionIdentifier:identifier sessionConfiguration:sessionConfig];
}

+ (void)setSessionConfiguration:(NSURLSessionConfiguration *)sessionConfig {
    kSFSessionConfig = sessionConfig;
}

+ (void)setSessionManager:(id<SFNetworkSessionManaging>)manager {
    kSFNetworkManager = manager;
}

+ (NSDictionary *)sharedSessions {
    return [[self mutableSharedSessions] dictionary];
}

+ (void)removeSharedEphemeralSession {
    [[self class] removeSharedSessionForIdentifier:kSFNetworkEphemeralSessionIdentifier];
}

+ (void)removeSharedBackgroundSession {
    [[self class] removeSharedSessionForIdentifier:kSFNetworkBackgroundSessionIdentifier];
}

+ (void)removeSharedSessionForIdentifier:(nullable NSString *)identifier {
    if (identifier) {
        [[self mutableSharedSessions] removeObject:identifier];
    }
}

+ (void)removeAllSharedSessions {
    [[self mutableSharedSessions] removeAllObjects];
}

+ (NSString *)uniqueSessionIdentifier  {
    return [NSString stringWithFormat:@"com.salesforce.network.%@", [[NSUUID UUID] UUIDString]];
}

#pragma mark - NSURLSessionDelegate

- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(nullable NSError *)error {
    SFSDKSafeMutableDictionary *sharedSessions = [[self class] mutableSharedSessions];
    for (NSString *identifier in [sharedSessions allKeys]) {
        NSURLSession *storedSession = sharedSessions[identifier];
        if (session == storedSession) {
            [sharedSessions removeObject:identifier];
        }
    }
}

#pragma mark - Private

+ (SFSDKSafeMutableDictionary *)mutableSharedSessions {
    static SFSDKSafeMutableDictionary *sharedSessions;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedSessions = [SFSDKSafeMutableDictionary new];
    });
    return sharedSessions;
}

@end
