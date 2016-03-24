//
//  SFPushNotificationManagerTests.m
//  SalesforceSDKCore
//
//  Created by Dustin Breese on 3/24/16.
//  Copyright © 2016 salesforce.com. All rights reserved.
//

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
    self.user.credentials = nil;
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
