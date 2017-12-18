/*
 SFSDKIDPConstants.h
 SalesforceSDKCore
 
 Created by Raj Rao on 9/28/17.
 
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

#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSString *const kSFErrorCodeParam;

FOUNDATION_EXPORT NSString *const kSFErrorReasonParam;

FOUNDATION_EXPORT NSString *const kSFErrorDescParam;

FOUNDATION_EXPORT NSUInteger const kSFVerifierByteLength;

FOUNDATION_EXPORT NSString *const kSFVerifierParamName;

FOUNDATION_EXPORT NSString *const kSFChallengeParamName;

FOUNDATION_EXPORT NSString *const kSFCodeParam;

FOUNDATION_EXPORT NSString *const kSFStateParam;

FOUNDATION_EXPORT NSString *const kSFAppNameParam;

FOUNDATION_EXPORT NSString *const kSFAppNameDefault;

FOUNDATION_EXPORT NSString *const kSFUserHintParam;

FOUNDATION_EXPORT NSString *const kSFLoginHostParam;

FOUNDATION_EXPORT NSString *const kSFCallingAppUrlParam;

FOUNDATION_EXPORT NSString *const kSFErrorReasonParam;

FOUNDATION_EXPORT NSString *const kSFErrorCodeParam;

FOUNDATION_EXPORT NSString *const kSFErrorDescriptionParam;

FOUNDATION_EXPORT NSString *const kSFRefreshTokenParam;

FOUNDATION_EXPORT NSString *const kSFOAuthClientIdParam;

FOUNDATION_EXPORT NSString *const kSFOAuthRedirectUrlParam;

FOUNDATION_EXPORT NSString *const kSFSpecVersion;

FOUNDATION_EXPORT NSString *const kSFSpecHost;

FOUNDATION_EXPORT NSString *const kSFAppDescParam;

FOUNDATION_EXPORT NSString *const kSFScopesParam;

FOUNDATION_EXPORT NSString *const kSFStartURLParam;

@interface SFSDKIDPConstants : NSObject

@end
