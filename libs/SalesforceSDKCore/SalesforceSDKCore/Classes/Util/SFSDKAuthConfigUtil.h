/*
 SFSDKAuthConfigUtil.h
 SalesforceSDKCore
 
 Created by Bharath Hariharan on 2/4/18.
 Copyright (c) 2018-present, salesforce.com, inc. All rights reserved.
 
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

#import <SalesforceSDKCore/SFOAuthOrgAuthConfiguration.h>
#import <SalesforceSDKCore/SFOAuthCredentials.h>
#import <SalesforceSDKCore/SalesforceSDKConstants.h>

/// Salesforce pool-server host strings. Exact-match constants used by
/// `SFSDKAuthConfigUtil` and by DPoP `dpop_jkt` gating to distinguish
/// pool hosts from my-domain hosts.
FOUNDATION_EXTERN NSString * _Nonnull const kSFSDKSandboxLoginURL;      // test.salesforce.com
FOUNDATION_EXTERN NSString * _Nonnull const kSFSDKProductionLoginURL;   // login.salesforce.com
FOUNDATION_EXTERN NSString * _Nonnull const kSFSDKWelcomeLoginURL;      // welcome.salesforce.com/discovery

@interface SFSDKAuthConfigUtil : NSObject

typedef void (^ _Nonnull MyDomainAuthConfigBlock)(SFOAuthOrgAuthConfiguration * _Nullable authConfig, NSError * _Nullable error);

+ (void)getMyDomainAuthConfig:(nonnull MyDomainAuthConfigBlock)authConfigBlock loginDomain:(nonnull NSString *)loginDomain;

/// YES when `host` is one of the three Salesforce pool servers
/// (login.salesforce.com, test.salesforce.com, welcome.salesforce.com/discovery).
/// NO for my-domain servers. Exact string match; no normalization.
+ (BOOL)isPoolLoginHost:(nonnull NSString *)host;

@end
