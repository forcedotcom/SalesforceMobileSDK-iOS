/*
 SFSDKAuthConfigUtilTests.m
 SalesforceSDKCoreTests
 
 Created by Raj Rao on 2/28/19.
 Copyright (c) 2019-present, salesforce.com, inc. All rights reserved.
 
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
#import <XCTest/XCTest.h>
#import <SalesforceSDKCommon/NSUserDefaults+SFAdditions.h>
#import <SalesforceSDKCore/SalesforceSDKCore.h>
#import "SFUserAccountManager+Internal.h"
@interface SFManagedPreferencesTest : XCTestCase
@property (nonatomic,strong) NSDictionary *managedProps;
@property (nonatomic,strong) SFUserAccount *prevCurrentUser;
@end
static NSException *authException = nil;

@implementation SFManagedPreferencesTest

- (void)setUp {
    //add  Managed Properties
    self.prevCurrentUser = [SFUserAccountManager sharedInstance].currentUser;
    [[SFUserAccountManager sharedInstance] setCurrentUserInternal:[[SFUserAccount alloc] init]];
    self.managedProps = @{@"RequireCertAuth":@YES,@"OnlyShowAuthorizedHosts":@YES,
                          @"ClearClipboardOnBackground":@YES,
                          @"ManagedAppCallbackURL": @"managed:url",
                          @"ManagedAppOAuthID" : @"managedappid",
                          @"IDPAppURLScheme" : @"idp:app:url"};
    [[NSUserDefaults msdkUserDefaults] setObject:self.managedProps forKey:@"com.apple.configuration.managed"];
}

- (void)tearDown {
    //Remove the Managed Properties
    self.managedProps = nil;
    [[SFUserAccountManager sharedInstance] setCurrentUserInternal:self.prevCurrentUser];
    [[NSUserDefaults msdkUserDefaults] removeObjectForKey:@"com.apple.configuration.managed"];
}

- (void)testManagedPreference {
    
    XCTAssertNotNil(self.managedProps, @"Dictionary for managed properties should not be nil");
   
    XCTAssertTrue([SFManagedPreferences sharedPreferences].requireCertificateAuthentication, @"SFManagedPreferences should have been set");
    XCTAssertTrue([SFUserAccountManager sharedInstance].useBrowserAuth, @"SFUserAccountManager should have been setup to use SFManagedPreferences settings for Browser");
    
    XCTAssertTrue([SFManagedPreferences sharedPreferences].connectedAppCallbackUri, @"SFManagedPreferences connectedAppCallbackUri should have been set");
   
    XCTAssertEqualObjects([SFManagedPreferences sharedPreferences].connectedAppCallbackUri,[SFUserAccountManager sharedInstance].oauthCompletionUrl, @"SFUserAccountManager should have been setup to use SFManagedPreferences connectedAppCallbackUri");
    
    XCTAssertTrue([SFManagedPreferences sharedPreferences].connectedAppId, @"SFManagedPreferences connectedAppId should have been set");
    
    XCTAssertEqualObjects([SFManagedPreferences sharedPreferences].connectedAppId,[SFUserAccountManager sharedInstance].oauthClientId, @"SFUserAccountManager should have been setup to use SFManagedPreferences connectedAppId");
    
    XCTAssertTrue([SFManagedPreferences sharedPreferences].idpAppURLScheme, @"SFManagedPreferences idpAppURLScheme should have been set");
    
    XCTAssertEqualObjects([SFManagedPreferences sharedPreferences].idpAppURLScheme,[SFUserAccountManager sharedInstance].idpAppURIScheme, @"SFUserAccountManager should have been setup to use SFManagedPreferences connectedAppId");
    
}
@end
