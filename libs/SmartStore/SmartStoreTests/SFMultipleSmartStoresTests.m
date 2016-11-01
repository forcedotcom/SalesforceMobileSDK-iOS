/*
 SFMultipleSmartStoresTests.m
 
 Created by Raj Rao on Wed Oct 24 17:47:00 PDT 2016.
 
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

#import "SFMultipleSmartStoresTest.h"

@interface SFMultipleSmartStoresTests()

@property (nonatomic, strong) SFUserAccount *smartStoreUser;

@end

@implementation SFMultipleSmartStoresTests

#pragma mark - setup and teardown

- (void) setUp
{
    [super setUp];
    [SFLogger sharedLogger].logLevel = SFLogLevelDebug;
    _smartStoreUser = [super setUpSmartStoreUser];
    [self setupGlobalStores];
    [self setupUserStores];

}

- (void) tearDown
{
    [self tearDownSmartStoreUser:self.smartStoreUser];
    [super tearDown];
}

- (void) setupGlobalStores {
    [SFSmartStore sharedGlobalStoreWithName:@"GLBLDB1"];
    [SFSmartStore sharedGlobalStoreWithName:@"GLBLDB2"];
    [SFSmartStore sharedGlobalStoreWithName:@"GLBLDB3"];
}

- (void) setupUserStores {
    [SFSmartStore sharedStoreWithName:@"USRDB1"];
    [SFSmartStore sharedStoreWithName:@"USRDB2"];
    [SFSmartStore sharedStoreWithName:@"USRDB3"];
}

- (void) testGetGlobalStoreNames {
    NSArray *array = [SFSmartStore allGlobalStoreNames];
    XCTAssertTrue(array.count == 3, "GetAllGlobalStoreNames call failed");
}

- (void) testGetUserStoreNames {
    NSArray *array = [SFSmartStore allStoreNames];
    XCTAssertTrue(array.count == 3, "testGetUserStoreNames call failed");
}

- (void) testRemoveAllStores {
    [SFSmartStore removeAllStores];
    NSArray *array = [SFSmartStore allStoreNames];
    XCTAssertTrue(array==nil || array.count==0, "testRemoveAllStores call failed");
}

- (void) testRemoveAllGlobalStores {
    [SFSmartStore removeAllGlobalStores];
    NSArray *array = [SFSmartStore allGlobalStoreNames];
    XCTAssertTrue(array==nil || array.count == 0, "testRemoveAllGlobalStores call failed");
}

- (void) testGetStoreWithStoreName {
    SFSmartStore *smartStore = [SFSmartStore sharedStoreWithName:@"USRDB1"];
    XCTAssertTrue(smartStore!=nil, "testGetStoreWithStoreName call failed");
}

- (SFUserAccount*)setUpSmartStoreUser
{
    u_int32_t userIdentifier = arc4random();
    SFUserAccount *user = [[SFUserAccount alloc] initWithIdentifier:[NSString stringWithFormat:@"identifier-%u", userIdentifier]];
    NSString *userId = [NSString stringWithFormat:@"user_%u", userIdentifier];
    NSString *orgId = [NSString stringWithFormat:@"org_%u", userIdentifier];
    user.credentials.identityUrl = [NSURL URLWithString:[NSString stringWithFormat:@"https://login.salesforce.com/id/%@/%@", orgId, userId]];
    
    [[SFUserAccountManager sharedInstance] addAccount:user];
    [SFUserAccountManager sharedInstance].currentUser = user;
    
    return user;
}

- (void)tearDownSmartStoreUser:(SFUserAccount*)user
{
    [SFSmartStore removeAllGlobalStores];
    [SFSmartStore removeAllStores];
    [[SFUserAccountManager sharedInstance] deleteAccountForUser:user error:nil];
    [SFUserAccountManager sharedInstance].currentUser = nil;
}

@end
