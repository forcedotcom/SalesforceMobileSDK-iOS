/*
 SFUserAccountManager+URLHandlers.h
 SalesforceSDKCore
 
 Created by Raj Rao on 9/25/17.
 
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
#import <SalesforceSDKCore/SalesforceSDKCore.h>

@class SFSDKAuthRequestCommand;
@class SFSDKAuthResponseCommand;
@class SFSDKAuthErrorCommand;
@class SFSDKIDPInitCommand;

@interface SFUserAccountManager (URLHandlers)
/**
 Handle an advanced authentication response from the external browser, continuing any
 in-progress adavanced authentication flow.
 @param  url The URL response returned to the app from the external browser.
 @param  options Dictionary of name-value pairs received from open URL
 @return YES if this is request is handled, NO otherwise.
 */
- (BOOL)handleNativeAuthResponse:(NSURL *_Nonnull)url options:(NSDictionary *_Nullable)options;

/**
 Handle an error situation that occured in the IDP flow.
 @param command The Error URL request from the idp or SP App.
 @return YES if this is request is handled, NO otherwise.
 */
- (BOOL)handleIdpAuthError:(SFSDKAuthErrorCommand *_Nonnull)command;

/**
 Handle an IDP initiated auth flow.
 @param command The URL request from the IDP APP.
 @return YES if this is request is handled, NO otherwise.
 */
- (BOOL)handleIdpInitiatedAuth:(SFSDKIDPInitCommand *_Nonnull)command;

/**
 Handle an IDP request initiated from an SP APP.
 @param request The  request from the SP APP.
 @return YES if this request is handled, NO otherwise.
 */
- (BOOL)handleIdpRequest:(SFSDKAuthRequestCommand *_Nonnull)request;

/**
 Handle an IDP response received from an IDP APP.
 @param  response The URL response from the IDP APP.
 @return YES if this is request is handled, NO otherwise.
 */
- (BOOL)handleIdpResponse:(SFSDKAuthResponseCommand *_Nonnull)response;
@end
