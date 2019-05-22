/*
 SFRestAPI+Instrumentation.m
 SalesforceSDKCore
 Created by Raj Rao on 3/7/19.
 
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

#import "SFRestAPI+Instrumentation.h"
#import "SFRestRequest+Internal.h"
#import "SalesforceSDKConstants.h"
#import "SFSDKInstrumentationHelper.h"
#import <objc/runtime.h>
#import <os/log.h>
#import <os/signpost.h>
#import "SFSDKCoreLogger.h"

@interface SFRestDelegateWrapperWithInstrumentation<SFRestDelegate>: NSObject
- (instancetype)initWithDelegate:(id<SFRestDelegate>) delegate signpost:(os_signpost_id_t)signpostId logger:(os_log_t) logger;
@property (weak,nonatomic,readonly) id<SFRestDelegate> delegate;
@property (nonatomic,readonly) os_signpost_id_t signpostId;
@property (nonatomic,readonly) os_log_t logger;

+(id<SFRestDelegate>)wrapperWith:delegate signpost:(os_signpost_id_t)signpostId logger:(os_log_t) logger;
@end

@implementation SFRestDelegateWrapperWithInstrumentation

- (instancetype)initWithDelegate:(id<SFRestDelegate>)delegate signpost:(os_signpost_id_t)signpostId logger:(os_log_t)logger {
    if (self = [super init]) {
        _delegate = delegate;
        _signpostId = signpostId;
        _logger = logger;
    }
    return self;
}

- (void)request:(SFRestRequest *)request didLoadResponse:(id)dataResponse rawResponse:(NSURLResponse *)rawResponse {
    sf_os_signpost_interval_end(self.logger, self.signpostId, "Send", "Ended - didLoadResponse:rawResponse %ld %{public}@", (long)request.method, request.path);
    if ([self.delegate respondsToSelector:@selector(request:didLoadResponse:rawResponse:)]) {
        [self.delegate request:request didLoadResponse:dataResponse rawResponse:rawResponse];
    }
    request.instrDelegateInternal = nil;
}

- (void)request:(SFRestRequest *)request didLoadResponse:(id)dataResponse {
    sf_os_signpost_interval_end(self.logger, self.signpostId, "Send", "didLoadResponse:didLoadResponse %ld %{public}@", (long)request.method, request.path);
    if ([self.delegate respondsToSelector:@selector(request:didLoadResponse:)]) {
        [self.delegate request:request didLoadResponse:dataResponse];
    }
    request.instrDelegateInternal = nil;
}


- (void)request:(SFRestRequest *)request didFailLoadWithError:(NSError*)error rawResponse:(NSURLResponse *)rawResponse {
    sf_os_signpost_interval_end(self.logger, self.signpostId, "Send", "didFailLoadWithError:rawResponse %ld %{public}@", (long)request.method, request.path);
    if ([self.delegate respondsToSelector:@selector(request:didFailLoadWithError:rawResponse:)]) {
        [self.delegate request:request didFailLoadWithError:error rawResponse:rawResponse];
    }
    request.instrDelegateInternal = nil;
}


- (void)request:(SFRestRequest *)request didFailLoadWithError:(NSError*)error {
    sf_os_signpost_interval_end(self.logger, self.signpostId, "Send", "didFailLoadWithError %ld %{public}@", (long)request.method, request.path);
    if ([self.delegate respondsToSelector:@selector(request:didFailLoadWithError:)]) {
        [self.delegate request:request didFailLoadWithError:error];
    }
    request.instrDelegateInternal = nil;
}


- (void)requestDidCancelLoad:(SFRestRequest *)request {
    sf_os_signpost_interval_end(self.logger, self.signpostId, "Send", "requestDidCancelLoad %ld %{public}@", (long)request.method, request.path);
    if ([self.delegate respondsToSelector:@selector(requestDidCancelLoad:)]) {
        [self.delegate requestDidCancelLoad:request];
    }
    request.instrDelegateInternal = nil;
}

- (void)requestDidTimeout:(SFRestRequest *)request {
    sf_os_signpost_interval_end(self.logger, self.signpostId, "Send", "requestDidTimeout %ld %{public}@", (long)request.method, request.path);
    if ([self.delegate respondsToSelector:@selector(requestDidTimeout:)]) {
        [self.delegate requestDidTimeout:request];
    }
    request.instrDelegateInternal = nil;
}

+(id<SFRestDelegate>)wrapperWith:delegate signpost:(os_signpost_id_t)signpostId logger:(os_log_t) logger {
    return (id<SFRestDelegate>) [[SFRestDelegateWrapperWithInstrumentation alloc] initWithDelegate:delegate  signpost:signpostId logger:logger];
}
@end

@implementation SFRestAPI(Instrumentation)

+ (os_log_t)oslog {
    static os_log_t _logger;
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{
        NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"];
        _logger = os_log_create([appName  cStringUsingEncoding:NSUTF8StringEncoding], [@"SFRestAPI" cStringUsingEncoding:NSUTF8StringEncoding]);
    });
    return _logger;
}


+ (void)load{
    if ([SFSDKInstrumentationHelper isEnabled] && (self == SFRestAPI.self)) {
        [self enableInstrumentation];
    }
}

+ (void)enableInstrumentation {
    if (@available(iOS 12.0, *)) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            Class class = [self class];
            SEL originalSelector = @selector(send:delegate:);
            SEL swizzledSelector = @selector(instr_send:delegate:);
            [SFSDKInstrumentationHelper swizzleMethod:originalSelector with:swizzledSelector forClass:class  isInstanceMethod:YES];
        });
    }
}

- (void)instr_send:(SFRestRequest *)request delegate:(id<SFRestDelegate>)delegate {
    // Begin an os_signpost_interval.
    os_log_t logger = self.class.oslog;
    os_signpost_id_t sid = sf_os_signpost_id_generate(logger);
    sf_os_signpost_interval_begin(logger, sid, "Send", "Method:%ld path:%{public}@", (long)request.method, request.path);
    id<SFRestDelegate> delegateWrapper = [SFRestDelegateWrapperWithInstrumentation wrapperWith:delegate signpost:sid logger:logger];
    request.instrDelegateInternal = delegateWrapper;
    return [self instr_send:request delegate:delegateWrapper];
 
}


@end
