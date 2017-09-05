/*
 SFSDKLoginHostTests.m
 SalesforceSDKCore
 
 Created by Kunal Chitalia on 3/28/16.
 Copyright (c) 2016-present, salesforce.com, inc. All rights reserved.
 
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
#import "SFLoginViewController.h"
#import "SFSDKLoginHostListViewController.h"
#import "SFSDKLoginHostStorage.h"
#import "SFSDKLoginHost.h"

@interface SFSDKLoginHostTests : XCTestCase

@property (nonatomic, strong) NSString *productionUrl;
@property (nonatomic, strong) NSString *sandboxUrl;
@property (nonatomic, strong) NSString *doesNotExistUrl;
@property (nonatomic, strong) NSString *customName;
@property (nonatomic, strong) NSString *customUrl;
@property (nonatomic, strong) NSString *customName2;
@property (nonatomic, strong) NSString *customUrl2;

@end

@implementation SFSDKLoginHostTests

- (void)setUp {
    [super setUp];
    self.productionUrl = @"login.salesforce.com";
    self.sandboxUrl = @"test.salesforce.com";
    self.doesNotExistUrl = @"doesnotexist.salesforce.com";
    self.customName = @"New";
    self.customUrl = @"https://new.com";
    self.customName2 = @"New2";
    self.customUrl2 = @"https://new2.com";
    
}

- (void)tearDown {
    SFSDKLoginHostStorage *loginHostStorage = [SFSDKLoginHostStorage sharedInstance];
    [loginHostStorage removeAllLoginHosts];
    [super tearDown];
}

- (void)testLoginHost{
    NSString *name = @"dummyname";
    NSString *host = @"dummyhost";
    BOOL deletable = YES;
    
    SFSDKLoginHost *loginHost = [SFSDKLoginHost hostWithName:name host:host deletable:deletable];
    
    XCTAssertEqualObjects(host, loginHost.host, @"%@ Should be equal to %@", host, loginHost.host);
    XCTAssertEqualObjects(name, loginHost.name, @"%@ Should be equal to %@", name, loginHost.name);
    XCTAssertEqual(deletable, loginHost.deletable, @"%d Should be equal to %d", deletable, loginHost.deletable);
    
    //Only testing name to be nil as host can never be nil and deletable will always have a YES or NO value
    loginHost = [SFSDKLoginHost hostWithName:nil host:host deletable:deletable];
    
    XCTAssertNotNil(loginHost.name, @"Name shoud not be nil");
    
}

- (void)testSetupNavigationBar {
    SFLoginViewController *loginViewController = [SFLoginViewController sharedInstance];
    //Test default values
    XCTAssertNotNil(loginViewController.navBarColor, "Nav bar color should not be nil");
    XCTAssertNotNil(loginViewController.navBarTextColor, "Nav bar text color should not be nil");
    XCTAssertNil(loginViewController.navBarFont, "Nav bar font should be nil");
    XCTAssertEqual(YES, loginViewController.showNavbar, "Show Nav bar should be set to yes by default");
    XCTAssertEqual(YES, loginViewController.showSettingsIcon, "Show Settings Icon should be set to yes by default");
    
}

- (void) testGetLoginHosts {
    SFSDKLoginHostStorage *loginHostStorage = [SFSDKLoginHostStorage sharedInstance];
    SFSDKLoginHost *loginHost = [loginHostStorage loginHostForHostAddress:self.productionUrl];
    
    XCTAssertEqualObjects(@"Production", loginHost.name, @"%@ Should be equal to %@", @"Production", loginHost.name);
    XCTAssertEqualObjects(self.productionUrl, loginHost.host, @"%@ Should be equal to %@", self.productionUrl, loginHost.host);
    
    loginHost = [loginHostStorage loginHostForHostAddress:self.sandboxUrl];
    
    XCTAssertEqualObjects(@"Sandbox", loginHost.name, @"%@ Should be equal to %@", @"Sandbox", loginHost.name);
    XCTAssertEqualObjects(self.sandboxUrl, loginHost.host, @"%@ Should be equal to %@", self.sandboxUrl, loginHost.host);
    
    loginHost = [loginHostStorage loginHostForHostAddress:self.doesNotExistUrl];
    XCTAssertNil(loginHost, "Login host should be nil");
}

- (void) testAddCustomServer {
    SFSDKLoginHostStorage *loginHostStorage = [SFSDKLoginHostStorage sharedInstance];
    SFSDKLoginHost *loginHost = [loginHostStorage loginHostForHostAddress:self.productionUrl];
    
    XCTAssertEqualObjects(@"Production", loginHost.name, @"%@ Should be equal to %@", @"Production", loginHost.name);
    XCTAssertEqualObjects(self.productionUrl, loginHost.host, @"%@ Should be equal to %@", self.productionUrl, loginHost.host);
    
    [loginHostStorage addLoginHost:[SFSDKLoginHost hostWithName:self.customName host:self.customUrl deletable:YES]];
    
    loginHost = [loginHostStorage loginHostForHostAddress:self.customUrl];
    
    XCTAssertEqualObjects(self.customName, loginHost.name, @"%@ Should be equal to %@", self.customName, loginHost.name);
    XCTAssertEqualObjects(self.customUrl, loginHost.host, @"%@ Should be equal to %@", self.customUrl, loginHost.host);
}

- (void) testAddMultipleCustomServers {
    SFSDKLoginHostStorage *loginHostStorage = [SFSDKLoginHostStorage sharedInstance];
    XCTAssertEqual(2, [loginHostStorage numberOfLoginHosts], "Number of login hosts should be equal to 2");
    
    [loginHostStorage addLoginHost:[SFSDKLoginHost hostWithName:self.customName host:self.customUrl deletable:YES]];
    SFSDKLoginHost *loginHost = [loginHostStorage loginHostForHostAddress:self.customUrl];
    XCTAssertEqual(3, [loginHostStorage numberOfLoginHosts], "Number of login hosts should be equal to 3");
    XCTAssertEqualObjects(self.customName, loginHost.name, @"%@ Should be equal to %@", self.customName, loginHost.name);
    XCTAssertEqualObjects(self.customUrl, loginHost.host, @"%@ Should be equal to %@", self.customUrl, loginHost.host);
    
    [loginHostStorage addLoginHost:[SFSDKLoginHost hostWithName:self.customName2 host:self.customUrl2 deletable:YES]];
    loginHost = [loginHostStorage loginHostForHostAddress:self.customUrl2];
    XCTAssertEqual(4, [loginHostStorage numberOfLoginHosts], "Number of login hosts should be equal to 4");
    XCTAssertEqualObjects(self.customName2, loginHost.name, @"%@ Should be equal to %@", self.customName2, loginHost.name);
    XCTAssertEqualObjects(self.customUrl2, loginHost.host, @"%@ Should be equal to %@", self.customUrl2, loginHost.host);
}

@end
