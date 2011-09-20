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
#import "SFRestAPI.h"
#import "SFOAuthCoordinator.h"
#import "RKRequestSerialization.h"

#define KEY_ERROR_CODE @"errorCode"

@interface RKRequestDelegateWrapper (private)
- (NSObject<RKRequestSerializable>*)formatParamsAsJson:(NSDictionary *)queryParams;
- (id)initWithRestRequest:(SFRestRequest *)request;

@end

@implementation RKRequestDelegateWrapper

@synthesize request=_request;
@synthesize previousOauthDelegate=_previousOauthDelegate;

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

- (NSObject<RKRequestSerializable>*)formatParamsAsJson:(NSDictionary *)queryParams {
    if (!queryParams)
        return nil;
    NSData *data = [[queryParams JSONRepresentation] dataUsingEncoding:NSUTF8StringEncoding];
    return [RKRequestSerialization serializationWithData:data MIMEType:@"application/json"];
}

- (void)send {
    RKClient *rkClient = [SFRestAPI sharedInstance].rkClient;
    NSString *url = [NSString stringWithFormat:@"/services/data%@", _request.path];

    if (_request.method == SFRestMethodGET) {
        [rkClient get:url queryParams:_request.queryParams delegate:self];
    }
    else if (_request.method == SFRestMethodDELETE) {
        [rkClient delete:url delegate:self];
    }
    else if (_request.method == SFRestMethodPUT) {
        [rkClient put:url params:[self formatParamsAsJson:_request.queryParams] delegate:self];
    }
    else if (_request.method == SFRestMethodPOST) {
        [rkClient post:url params:[self formatParamsAsJson:_request.queryParams] delegate:self];
    }
    else if (_request.method == SFRestMethodPATCH) {
        // PATCH is not fully supported yet so using POST instead
        NSString *delimiter = ([_request.path rangeOfString:@"?"].location == NSNotFound
                               ? @"?"
                               : @"&");
        NSString *newUrl = [NSString stringWithFormat:@"%@%@_HttpMethod=PATCH", url, delimiter];
        [rkClient post:newUrl params:[self formatParamsAsJson:_request.queryParams] delegate:self];
    }

    // Note:
    // We are retaining self,
    // Otherwise its retain count would be 0 (the RKClient post/get/delete methods
    // don't retain the delegate) and its memory will get reclaimed.
    // Instead the callback delegate methods (RKRequestDelegate) will release the object as needed    
    [self retain];
}

#pragma mark - RKRequestDelegate

- (void)request:(RKRequest*)request didLoadResponse:(RKResponse*)response {
    // token has expired ?
    if ([response isUnauthorized]) {
        // let's refresh the token
        // but first, let's save the previous delegate
        self.previousOauthDelegate = [SFRestAPI sharedInstance].coordinator.delegate;
        [SFRestAPI sharedInstance].coordinator.credentials.accessToken = nil;
        [SFRestAPI sharedInstance].coordinator.delegate = self;
        [[SFRestAPI sharedInstance].coordinator authenticate];
        return;
    }

    //TODO use builtin json framework if available?
    SBJsonParser *parser = [[[SBJsonParser alloc] init] autorelease];
    id jsonResponse = [parser objectWithData:response.body];
    if ([jsonResponse isKindOfClass:[NSArray class]]
        && ([(NSArray *)jsonResponse count] == 1)
        && [[(NSArray*)jsonResponse objectAtIndex:0] isKindOfClass:[NSDictionary class]]) {
        NSDictionary *potentialError = [jsonResponse objectAtIndex:0];
        NSString *potentialErrorCode = [potentialError objectForKey:KEY_ERROR_CODE];
        if (potentialErrorCode) {
            // we have an error
            NSError *error = [NSError errorWithDomain:kSFRestErrorDomain code:kSFRestErrorCode userInfo:potentialError];
            [self request:request didFailLoadWithError:error];
            return;
        }
    }

    if ([self.request.delegate respondsToSelector:@selector(request:didLoadResponse:)]) {
        [self.request.delegate request:_request didLoadResponse:jsonResponse];
    }
    [self release];
}

- (void)request:(RKRequest*)request didFailLoadWithError:(NSError*)error {
    // let's see if we have an expired session
    NSLog(@"error: %@", error);
    if ([self.request.delegate respondsToSelector:@selector(request:didFailLoadWithError:)]) {
        [self.request.delegate request:_request didFailLoadWithError:error];
    }
    [self release];
}

- (void)requestDidCancelLoad:(RKRequest*)request {
    if ([self.request.delegate respondsToSelector:@selector(requestDidCancelLoad:)]) {
        [self.request.delegate requestDidCancelLoad:_request];
    }
    [self release];
}

- (void)requestDidTimeout:(RKRequest*)request {
    if ([self.request.delegate respondsToSelector:@selector(requestDidTimeout:)]) {
        [self.request.delegate requestDidTimeout:_request];
    }   
    [self release];
}

#pragma mark - SFOAuthCoordinatorDelegate

- (void)restoreOAuthDelegate {
    [SFRestAPI sharedInstance].coordinator.delegate = self.previousOauthDelegate;
    self.previousOauthDelegate = nil;
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator willBeginAuthenticationWithView:(UIWebView *)view {
    NSLog(@"oauthCoordinator:willBeginAuthenticationWithView");
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didBeginAuthenticationWithView:(UIWebView *)view {
    NSLog(@"oauthCoordinator:didBeginAuthenticationWithView");    
    // we are in the token exchange flow so this should never happen
    [self restoreOAuthDelegate];
    [coordinator stopAuthentication];
    NSError *error = [NSError errorWithDomain:kSFOAuthErrorDomain code:kSFRestErrorCode userInfo:nil];
    [self request:nil didFailLoadWithError:error];    

    // we are creating a temp view here since the oauth library verifies that the view
    // has a subview after calling oauthCoordinator:didBeginAuthenticationWithView:
    UIView *tempView = [[[UIView alloc] initWithFrame:CGRectZero] autorelease];
    [tempView addSubview:view];    
}

- (void)oauthCoordinatorDidAuthenticate:(SFOAuthCoordinator *)coordinator {
    NSLog(@"oauthCoordinatorDidAuthenticate");

    // the token exchange worked. Let's update the HTTP headers
    [self restoreOAuthDelegate];
    NSString *newAccessToken = coordinator.credentials.accessToken;
    [[SFRestAPI sharedInstance].rkClient setValue:[NSString stringWithFormat:@"OAuth %@", newAccessToken] forHTTPHeaderField:@"Authorization"];

    // replay the request now
    [self send];
    [self release];
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didFailWithError:(NSError *)error {
    NSLog(@"oauthCoordinator:didFailWithError: %@", error);

    // oauth error
    [self restoreOAuthDelegate];
    [coordinator stopAuthentication];
    NSError *newError = [NSError errorWithDomain:kSFOAuthErrorDomain code:kSFRestErrorCode userInfo:[error userInfo]];
    [self request:nil didFailLoadWithError:newError];    
}

@end