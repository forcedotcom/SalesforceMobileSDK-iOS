/*
 Copyright (c) 2012, salesforce.com, inc. All rights reserved.
 
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

#import "SFSDKTestRequestListener.h"
#import "TestSetupUtils.h"
#import "SFAuthenticationManager.h"
#import "SFUserAccountManager.h"


NSString* const kTestRequestStatusWaiting = @"waiting";
NSString* const kTestRequestStatusDidLoad = @"didLoad";
NSString* const kTestRequestStatusDidFail = @"didFail";
NSString* const kTestRequestStatusDidCancel = @"didCancel";
NSString* const kTestRequestStatusDidTimeout = @"didTimeout";

@interface SFSDKTestRequestListener ()
{
    SFAuthenticationManager *_authMgr;
    SFAccountManagerServiceType _serviceType;
}

- (id)initInternal;
- (void)configureAccountServiceDelegate;
- (void)clearAccountManagerDelegate;

@end

@implementation SFSDKTestRequestListener

@synthesize dataResponse = _dataResponse;
@synthesize lastError = _lastError;
@synthesize returnStatus = _returnStatus;

@synthesize maxWaitTime = _maxWaitTime;

- (id)init
{
    return [self initInternal];
}

- (id)initWithServiceType:(SFAccountManagerServiceType)serviceType
{
    self = [self initInternal];
    if (nil != self) {
        _serviceType = serviceType;
        [self configureAccountServiceDelegate];
    }
    
    return self;
}

- (id)initInternal
{
    self = [super init];
    if (nil != self) {
        _authMgr = [SFAuthenticationManager sharedManager];
        self.maxWaitTime = 30.0;
        self.returnStatus = kTestRequestStatusWaiting;
    }
    
    return self;
}

- (void)dealloc {
    
    if (_serviceType != SFAccountManagerServiceTypeNone) {
        [self clearAccountManagerDelegate];
    }
    
    self.dataResponse = nil;
    self.lastError = nil;
    self.returnStatus = nil;
}


- (NSString *)waitForCompletion {
    
    NSDate *startTime = [NSDate date] ;
        
    while ([self.returnStatus isEqualToString:kTestRequestStatusWaiting]) {
        NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:startTime];
        if (elapsed > self.maxWaitTime) {
            [self log:SFLogLevelDebug format:@"'%@' Request took too long (> %f secs) to complete.", [self serviceTypeDescription], elapsed];
            return kTestRequestStatusDidTimeout;
        }
        
        [self log:SFLogLevelDebug msg:@"## sleeping..."];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }
    
    return self.returnStatus;
}

#pragma mark - Private methods

- (void)configureAccountServiceDelegate
{
    if (_serviceType == SFAccountManagerServiceTypeIdentity) {
        _authMgr.idCoordinator.delegate = self;
    } else if (_serviceType == SFAccountManagerServiceTypeOAuth) {
        _authMgr.coordinator.delegate = self;
    } else {
        NSAssert1(NO, @"Service type '%lu' is not supported as a service object.", (unsigned long)_serviceType);
    }
}

- (void)clearAccountManagerDelegate
{
    if (_serviceType == SFAccountManagerServiceTypeIdentity) {
        _authMgr.idCoordinator.delegate = nil;
    } else if (_serviceType == SFAccountManagerServiceTypeOAuth) {
        _authMgr.coordinator.delegate = nil;
    }
}

- (NSString *)serviceTypeDescription
{
    if (_serviceType == SFAccountManagerServiceTypeIdentity) {
        return @"SFIdentityCoordinator";
    } else if (_serviceType == SFAccountManagerServiceTypeOAuth) {
        return @"SFOAuthCoordinator";
    } else {
        return @"Unknown";
    }
}

#pragma mark - SFIdentityCoordinatorDelegate

- (void)identityCoordinatorRetrievedData:(SFIdentityCoordinator *)coordinator
{
    [self log:SFLogLevelInfo format:@"%@", NSStringFromSelector(_cmd)];
    self.returnStatus = kTestRequestStatusDidLoad;
}

- (void)identityCoordinator:(SFIdentityCoordinator *)coordinator didFailWithError:(NSError *)error
{
    [self log:SFLogLevelInfo format:@"%@ with error: %@", NSStringFromSelector(_cmd), error];
    self.lastError = error;
    self.returnStatus = kTestRequestStatusDidFail;
}

#pragma mark - SFOAuthCoordinatorDelegate

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator willBeginAuthenticationWithView:(WKWebView *)view
{
    NSAssert(NO, @"User Agent flow not supported in this class.");
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didStartLoad:(WKWebView *)view
{
    NSAssert(NO, @"User Agent flow not supported in this class.");
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didFinishLoad:(WKWebView *)view error:(NSError*)errorOrNil
{
    NSAssert(NO, @"User Agent flow not supported in this class.");
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didBeginAuthenticationWithView:(WKWebView *)view
{
    NSAssert(NO, @"User Agent flow not supported in this class.");
}

- (void)oauthCoordinatorDidAuthenticate:(SFOAuthCoordinator *)coordinator authInfo:(SFOAuthInfo *)info
{
    [self log:SFLogLevelInfo format:@"%@ with authInfo: %@", NSStringFromSelector(_cmd), info];
    self.returnStatus = kTestRequestStatusDidLoad;
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didFailWithError:(NSError *)error authInfo:(SFOAuthInfo *)info
{
    [self log:SFLogLevelInfo format:@"%@ with authInfo: %@, error: %@", NSStringFromSelector(_cmd), info, error];
    self.lastError = error;
    self.returnStatus = kTestRequestStatusDidFail;
}

@end
