/*
 Copyright (c) 2025-present, salesforce.com, inc. All rights reserved.
 
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

NS_ASSUME_NONNULL_BEGIN

@interface SFOAuthCoordinatorFrontdoorBridgeLoginOverride: NSObject

/// For Salesforce Identity UI Bridge API support, an overriding front door bridge URL to use in place of the default initial URL.
@property (nonatomic, strong, nullable) NSURL *frontdoorBridgeUrl;

/// For Salesforce Identity UI Bridge API support, the optional web server flow code verififer accompaning the front door bridge URL.  This can only be used with `overrideWithfrontDoorBridgeUrl`.
@property (nonatomic, strong, nullable) NSString *codeVerifier;

/// For Salesforce Identity UI Bridge API support, indicates if overriding front door bridge URL has a consumer key value that matches the app config, which is also known as the boot config.
@property (nonatomic, assign) BOOL matchesConsumerKey;

- (instancetype)initWithFrontdoorBridgeUrl:(NSURL *)frontdoorBridgeUrl codeVerifier:(NSString *)codeVerifier;

@end

NS_ASSUME_NONNULL_END
