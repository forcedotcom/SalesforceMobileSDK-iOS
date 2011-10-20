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

#import "RKRequestDelegateWrapper.h"

#import "RKResponse.h"
#import "SBJson.h"
#import "SFRestRequest.h"
#import "SFRestAPI+Internal.h"
#import "SFOAuthCoordinator.h"
#import "SFSessionRefresher.h"
#import "RKRequestSerialization.h"

#define KEY_ERROR_CODE @"errorCode"

@interface RKRequestDelegateWrapper (private)
+ (NSObject<RKRequestSerializable>*)formatParamsAsJson:(NSDictionary *)queryParams;
- (id)initWithRestRequest:(SFRestRequest *)request;

@end

@implementation RKRequestDelegateWrapper

@synthesize request=_request;

#pragma mark - init/setup

- (id)initWithRestRequest:(SFRestRequest *)request {
    self = [super init];
    if (self) {
        self.request = request;
    }
    return self;
}


+ (id)wrapperWithRequest:(SFRestRequest *)request {
    return [[[RKRequestDelegateWrapper alloc] initWithRestRequest:request] autorelease];
}

- (void)dealloc {
    self.request = nil;
    [super dealloc];
}

#pragma mark - helper methods

+ (NSObject<RKRequestSerializable>*)formatParamsAsJson:(NSDictionary *)queryParams {
    if (!([queryParams count] > 0))
        return nil;
    NSData *data = [[queryParams JSONRepresentation] dataUsingEncoding:NSUTF8StringEncoding];
    return [RKRequestSerialization serializationWithData:data MIMEType:@"application/json"];
}

- (void)send {
    RKClient *rkClient = [SFRestAPI sharedInstance].rkClient;
    NSString *url = [NSString stringWithFormat:@"/services/data%@", _request.path];
    SFOAuthCoordinator *coord = [SFRestAPI sharedInstance].coordinator;
    
    //make sure we have the latest access token at the moment we send the request
    [rkClient setValue:[NSString stringWithFormat:@"OAuth %@", coord.credentials.accessToken] 
         forHTTPHeaderField:@"Authorization"];
    
    if (_request.method == SFRestMethodGET) {
        [rkClient get:url queryParams:_request.queryParams delegate:self];
    }
    else if (_request.method == SFRestMethodDELETE) {
        [rkClient delete:url delegate:self];
    }
    else if (_request.method == SFRestMethodPUT) {
        [rkClient put:url params:[[self class] formatParamsAsJson:_request.queryParams] delegate:self];
    }
    else if (_request.method == SFRestMethodPOST) {
        [rkClient post:url params:[[self class] formatParamsAsJson:_request.queryParams] delegate:self];
    }
    else if (_request.method == SFRestMethodPATCH) {
        // PATCH is not fully supported yet so using POST instead
        NSString *delimiter = ([_request.path rangeOfString:@"?"].location == NSNotFound
                               ? @"?"
                               : @"&");
        NSString *newUrl = [NSString stringWithFormat:@"%@%@_HttpMethod=PATCH", url, delimiter];
        [rkClient post:newUrl params:[[self class] formatParamsAsJson:_request.queryParams] delegate:self];
    }

    //Note: requests are now retained by the SFRestAPI in the activeRequests list

}

#pragma mark - RKRequestDelegate

- (void)request:(RKRequest*)request didLoadResponse:(RKResponse*)response {
    // token has expired ?
    if ([response isUnauthorized]) {
        NSLog(@"Got unauthorized response");
        [[SFRestAPI sharedInstance].sessionRefresher requestFailedUnauthorized:self];
        return;
    }

    //TODO use builtin json framework if available?
    SBJsonParser *parser = [[[SBJsonParser alloc] init] autorelease];
    id jsonResponse = [parser objectWithData:response.body];
    if ([jsonResponse isKindOfClass:[NSArray class]]) {
        if ([jsonResponse count] == 1) {
            id potentialError = [jsonResponse objectAtIndex:0];
            if ([potentialError isKindOfClass:[NSDictionary class]]) {
                NSString *potentialErrorCode = [potentialError objectForKey:KEY_ERROR_CODE];
                if (nil != potentialErrorCode) {
                    // we have an error
                    NSError *error = [NSError errorWithDomain:kSFRestErrorDomain code:kSFRestErrorCode userInfo:potentialError];
                    [self request:request didFailLoadWithError:error];
                    return;
                }
            }
        }


    }

    if ([self.request.delegate respondsToSelector:@selector(request:didLoadResponse:)]) {
        [self.request.delegate request:_request didLoadResponse:jsonResponse];
    }
    [[SFRestAPI sharedInstance] removeActiveRequestObject:self];
}

- (void)request:(RKRequest*)request didFailLoadWithError:(NSError*)error {
    // let's see if we have an expired session
    NSLog(@"error: %@", error);
    if ([self.request.delegate respondsToSelector:@selector(request:didFailLoadWithError:)]) {
        [self.request.delegate request:_request didFailLoadWithError:error];
    }
    [[SFRestAPI sharedInstance] removeActiveRequestObject:self];
}

- (void)requestDidCancelLoad:(RKRequest*)request {
    if ([self.request.delegate respondsToSelector:@selector(requestDidCancelLoad:)]) {
        [self.request.delegate requestDidCancelLoad:_request];
    }
    [[SFRestAPI sharedInstance] removeActiveRequestObject:self];
}

- (void)requestDidTimeout:(RKRequest*)request {
    if ([self.request.delegate respondsToSelector:@selector(requestDidTimeout:)]) {
        [self.request.delegate requestDidTimeout:_request];
    }   
    [[SFRestAPI sharedInstance] removeActiveRequestObject:self];
}



@end