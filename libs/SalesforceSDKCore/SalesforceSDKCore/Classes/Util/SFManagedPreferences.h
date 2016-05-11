/*
 Copyright (c) 2015-present, salesforce.com, inc. All rights reserved.
 
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

/**
 Class to handle preferences set by an MDM provider.
 */
@interface SFManagedPreferences : NSObject

/**
 @return The shared instance of this class.
 */
+ (instancetype)sharedPreferences;

/**
 Whether or not any managed preferences have been configured for this app.
 */
@property (nonatomic, readonly) BOOL hasManagedPreferences;

/**
 Whether the app is configured to require certificate-based authentication. (RequireCertAuth)
 */
@property (nonatomic, readonly) BOOL requireCertificateAuthentication;

/**
 An array of prescribed login hosts from the MDM provider. (AppServiceHosts)
 */
@property (nonatomic, readonly) NSArray *loginHosts;

/**
 The associated labels for the provided login hosts. (AppServiceHostLabels)
 */
@property (nonatomic, readonly) NSArray *loginHostLabels;

/**
 The managed Connected App ID. (ManagedAppOAuthID)
 */
@property (nonatomic, readonly) NSString *connectedAppId;

/**
 The managed Conneced App Callback URI. (ManagedAppCallbackURL)
 */
@property (nonatomic, readonly) NSString *connectedAppCallbackUri;

/**
 Whether or not to clear the clipboard when the app is backgrounded. (ClearClipboardOnBackground)
 */
@property (nonatomic, readonly) BOOL clearClipboardOnBackground;

/**
 Whether or not to display only the authorized hosts. (OnlyShowAuthorizedHosts)
 */
@property (nonatomic, readonly) BOOL onlyShowAuthorizedHosts;

/**
 The raw NSDictionary of managed preferences.
 */
@property (nonatomic, strong, readonly) NSDictionary *rawPreferences;

@end
