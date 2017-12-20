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

@interface SFNetwork()

@property (nonatomic, readwrite, strong, nonnull) NSURLSession *ephemeralSession;
@property (nonatomic, readwrite, strong, nonnull) NSURLSession *backgroundSession;

@end

@implementation SFNetwork

static NSURLSessionConfiguration *kSFEphemeralSessionConfig;
static NSURLSessionConfiguration *kSFBackgroundSessionConfig;

- (instancetype)init {
    self = [super init];
    if (self) {
        NSURLSessionConfiguration *ephemeralSessionConfig = [NSURLSessionConfiguration ephemeralSessionConfiguration];
        if (kSFEphemeralSessionConfig) {
            ephemeralSessionConfig = kSFEphemeralSessionConfig;
        }
        self.ephemeralSession = [NSURLSession sessionWithConfiguration:ephemeralSessionConfig];
        
        NSString *identifier = [NSString stringWithFormat:@"com.salesforce.network.%lu", (unsigned long)self.hash];
        NSURLSessionConfiguration *backgroundSessionConfig = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:identifier];
        if (kSFBackgroundSessionConfig) {
            backgroundSessionConfig = kSFBackgroundSessionConfig;
        }
        self.backgroundSession = [NSURLSession sessionWithConfiguration:backgroundSessionConfig];
        self.useBackground = NO;
    }
    return self;
}

- (NSURLSessionDataTask *)sendRequest:(nonnull NSURLRequest *)urlRequest dataResponseBlock:(nullable SFDataResponseBlock)dataResponseBlock {
    NSURLSessionDataTask *dataTask = [[self activeSession] dataTaskWithRequest:urlRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (dataResponseBlock) {
            dataResponseBlock(data, response, error);
        }
    }];
    [dataTask resume];
    return dataTask;
}

- (NSURLSession *)activeSession {
    return (self.useBackground ? self.backgroundSession : self.ephemeralSession);
}

+ (void)setSessionConfiguration:(NSURLSessionConfiguration *)sessionConfig isBackgroundSession:(BOOL)isBackgroundSession {
    if (isBackgroundSession) {
        kSFBackgroundSessionConfig = sessionConfig;
    } else {
        kSFEphemeralSessionConfig = sessionConfig;
    }
}

@end
