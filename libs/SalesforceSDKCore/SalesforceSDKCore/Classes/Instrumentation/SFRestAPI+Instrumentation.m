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

@interface SFRestDelegateWrapperWithInstrumentation<SFRestDelegate, SFRestRequestDelegate>: NSObject

- (instancetype)initWithRequestDelegate:(id<SFRestRequestDelegate>)requestDelegate signpost:(os_signpost_id_t)signpostId logger:(os_log_t)logger;

@property (weak, nonatomic, readonly) id<SFRestRequestDelegate> requestDelegate;
@property (nonatomic, readonly) os_signpost_id_t signpostId;
@property (nonatomic, readonly) os_log_t logger;

+ (id<SFRestRequestDelegate>)factoryWith:requestDelegate signpost:(os_signpost_id_t)signpostId logger:(os_log_t)logger;

@end

@implementation SFRestDelegateWrapperWithInstrumentation

- (instancetype)initWithRequestDelegate:(id<SFRestRequestDelegate>)requestDelegate signpost:(os_signpost_id_t)signpostId logger:(os_log_t)logger {
    if (self = [super init]) {
        _requestDelegate = requestDelegate;
        _signpostId = signpostId;
        _logger = logger;
    }
    return self;
}

- (void)request:(SFRestRequest *)request didSucceed:(id)dataResponse rawResponse:(NSURLResponse *)rawResponse {
    sf_os_signpost_interval_end(self.logger, self.signpostId, "Send", "requestDidSucceed %ld %{public}@", (long)request.method, request.path);
    if ([self.requestDelegate respondsToSelector:@selector(request:didSucceed:rawResponse:)]) {
        [self.requestDelegate request:request didSucceed:dataResponse rawResponse:rawResponse];
    }
    request.instrumentationDelegateInternal = nil;
}

- (void)request:(SFRestRequest *)request didFail:(id)dataResponse rawResponse:(NSURLResponse *)rawResponse error:(NSError *)error {
    sf_os_signpost_interval_end(self.logger, self.signpostId, "Send", "requestDidFail %ld %{public}@", (long)request.method, request.path);
    if ([self.requestDelegate respondsToSelector:@selector(request:didFail:rawResponse:error:)]) {
        [self.requestDelegate request:request didFail:dataResponse rawResponse:rawResponse error:error];
    }
    request.instrumentationDelegateInternal = nil;
}

+ (id<SFRestRequestDelegate>)factoryWith:requestDelegate signpost:(os_signpost_id_t)signpostId logger:(os_log_t)logger {
    return (id<SFRestRequestDelegate>) [[SFRestDelegateWrapperWithInstrumentation alloc] initWithRequestDelegate:requestDelegate signpost:signpostId logger:logger];
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

+ (void)load {
    if ([SFSDKInstrumentationHelper isEnabled] && (self == SFRestAPI.self)) {
        [self enableInstrumentation];
    }
}

+ (void)enableInstrumentation {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [self class];
        SEL originalSelector = @selector(send:requestDelegate:);
        SEL swizzledSelector = @selector(instrumentation_send:requestDelegate:);
        [SFSDKInstrumentationHelper swizzleMethod:originalSelector with:swizzledSelector forClass:class isInstanceMethod:YES];
    });
}

- (void)instrumentation_send:(SFRestRequest *)request requestDelegate:(id<SFRestRequestDelegate>)requestDelegate {

    // Begin an os_signpost_interval.
    os_log_t logger = self.class.oslog;
    os_signpost_id_t sid = sf_os_signpost_id_generate(logger);
    sf_os_signpost_interval_begin(logger, sid, "Send", "Method:%ld path:%{public}@", (long)request.method, request.path);
    id<SFRestRequestDelegate> delegateWrapper = [SFRestDelegateWrapperWithInstrumentation factoryWith:requestDelegate signpost:sid logger:logger];
    request.instrumentationDelegateInternal = delegateWrapper;
    return [self instrumentation_send:request requestDelegate:delegateWrapper];
}

@end
