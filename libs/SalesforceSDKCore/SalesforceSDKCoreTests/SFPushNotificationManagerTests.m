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

#import <XCTest/XCTest.h>
#import "SFPushNotificationManager.h"
#import "SFUserAccount.h"
#import "SFOAuthCoordinator.h"
#import "SFAuthenticationManager.h"
#import "SFIdentityCoordinator.h"
#import "SFUserAccountManager.h"
#import "SFIdentityData.h"
#import "SFPreferences.h"

// needs to match what is defined in SFPushNotificationManager
static NSString* const kSFDeviceSalesforceId = @"deviceSalesforceId";

@interface SFPushNotificationManager(Testing)
@property (nonatomic, assign) BOOL isSimulator;
@end

@interface SFPushNotificationManagerTests : XCTestCase
@property (nonatomic, strong) SFPushNotificationManager *manager;
@property (nonatomic, strong) SFUserAccount *user;
@end

@implementation SFPushNotificationManagerTests

- (void)setUp {
    [super setUp];
    self.manager = [[SFPushNotificationManager alloc] init];
    self.manager.isSimulator = NO;

    SFUserAccount *user = [[SFUserAccount alloc] initWithIdentifier:@"happy-user"];
    user.credentials.identityUrl = [NSURL URLWithString:@"https://login.salesforce.com/id/00D000000000062EA0/005R0000000Dsl0"];
    [SFUserAccountManager sharedInstance].currentUser = user;

    self.user = user;

}

- (void)tearDown {
    [super tearDown];
}

- (void)testUnregisterSalesforceNotifications_NoUserCredentials {
    self.user.credentials = (SFOAuthCredentials* _Nonnull)nil;
    BOOL result = [self.manager unregisterSalesforceNotifications:self.user];
    XCTAssertFalse(result);
}

- (void)testUnregisterSalesforceNotifications_NoDeviceIdPref {
    SFPreferences *pref = [SFPreferences sharedPreferencesForScope:SFUserAccountScopeUser user:self.user];
    [pref removeObjectForKey:kSFDeviceSalesforceId];

    BOOL result = [self.manager unregisterSalesforceNotifications:self.user];
    XCTAssertFalse(result);
}



@end
