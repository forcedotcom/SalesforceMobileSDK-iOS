/*
 Copyright (c) 2013-present, salesforce.com, inc. All rights reserved.
 
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

#import "SFNativeRestRequestListener.h"
#import <SalesforceSDKCore/SFLogger.h>

int class_uid = 0;

@interface SFNativeRestRequestListener ()
{
    int uid;
}

@end

@implementation SFNativeRestRequestListener

@synthesize request = _request;

- (id)initWithRequest:(SFRestRequest *)request {
    self = [super init];
    if (self) {
        self.request = request;
        self.request.delegate = self;
        self->uid = class_uid++;
    }

    [self log:SFLogLevelDebug format:@"## created listener %d", self->uid];
    
    return self;
}

- (void)dealloc
{
    self.request.delegate = nil;
    self.request = nil;
}

- (NSString *)serviceTypeDescription
{
    return @"SFRestRequest";
}

#pragma mark - SFRestDelegate

- (void)request:(SFRestRequest *)request didLoadResponse:(id)dataResponse {
    self.dataResponse = dataResponse;
    self.returnStatus = kTestRequestStatusDidLoad;
}

- (void)request:(SFRestRequest*)request didFailLoadWithError:(NSError*)error {
    [self log:SFLogLevelDebug format:@"## error for request %d", self->uid];
    
    self.lastError = error;
    self.returnStatus = kTestRequestStatusDidFail;
}

- (void)requestDidCancelLoad:(SFRestRequest *)request {
    [self log:SFLogLevelDebug format:@"## cancel for request %d", self->uid];

    self.returnStatus = kTestRequestStatusDidCancel;
}

- (void)requestDidTimeout:(SFRestRequest *)request {
    self.returnStatus = kTestRequestStatusDidTimeout;
}

@end
