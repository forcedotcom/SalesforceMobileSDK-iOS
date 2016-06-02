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

#import "SFRestAPI.h"
#import <SalesforceSDKCore/SFUserAccountManager.h>
#import <SalesforceSDKCore/SFAuthenticationManager.h>
#import <SalesforceNetwork/CSFNetwork.h>

/**
 We declare here a set of interfaces that are meant to be used by code running internally
 to SFRestAPI or close "friend" classes such as unit test helpers. You SHOULD NOT access these interfaces
 from application code.  If you find yourself accessing properties or calling methods
 declared in this file from app code, you're probably doing something wrong.
 */
@interface SFRestAPI () <SFUserAccountManagerDelegate>
{
    SFUserAccountManager *_accountMgr;
    SFAuthenticationManager *_authMgr;
}

@property (nonatomic, readonly) CSFNetwork *currentNetwork;

/**
 * Active requests property
 */
@property (nonatomic, readonly, strong) NSMutableSet	*activeRequests;

- (void)removeActiveRequestObject:(SFRestRequest *)request;

/**
 Force a request to timeout: for testing only!
 
 @param req The request to force a timeout on, or nil to grab any active request and force it to timeout
 @return YES if we were able to find and timeout the request, NO if the request could not be found
 */
- (BOOL)forceTimeoutRequest:(SFRestRequest*)req;

@end

