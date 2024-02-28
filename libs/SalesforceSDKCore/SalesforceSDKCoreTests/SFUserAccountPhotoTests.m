/*
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
#import <SalesforceSDKCore/SalesforceSDKCore.h>
#import <SalesforceSDKCommon/SalesforceSDKCommon.h>
#import "SFOAuthCredentials+Internal.h"
#import "SFUserAccount+Internal.h"
#import "SFDirectoryManager+Internal.h"

@interface SFUserAccount (Testing)

- (NSString *)photoPathInternal:(NSError**)error;
- (UIImage *)decryptPhoto:(NSString *)photoPath;

@end

@interface SFUserAccountPhotoTests : XCTestCase

@end

static NSString * const kUserId = @"005R0000000DslaIAC";
static NSString * const kOrgId = @"00D000000000062EAA";

@implementation SFUserAccountPhotoTests

- (void)testPhotoWithCompletionBlock {
    SFUserAccount *user = [self createNewUser];
    [self setPhoto:user photo:nil];
    XCTAssertNil(user.photo);
    
    UIImage *testPhoto = [SFSDKResourceUtils imageNamed:@"salesforce-logo"];
    [self setPhoto:user photo:testPhoto];
    XCTAssertEqualObjects(user.photo, testPhoto);
    
    [self setPhoto:user photo:nil];
    XCTAssertNil(user.photo);
}

- (void)testPhotoWithoutCompletionBlock {
    SFUserAccount *user = [self createNewUser];
    [user setPhoto:nil completion:nil];
    [self waitForBlockCondition:^BOOL{
        return user.photo == nil;
    } timeout:2.0];
    XCTAssertNil(user.photo);
    
    UIImage *testPhoto = [SFSDKResourceUtils imageNamed:@"salesforce-logo"];
    [user setPhoto:testPhoto completion:nil];
    [self waitForBlockCondition:^BOOL{
        return user.photo == testPhoto;
    } timeout:2.0];
    XCTAssertNotNil(user.photo);
}

- (void)setPhoto:(SFUserAccount*)user photo:(UIImage*)photo {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Photo set"];
    [user setPhoto:photo completion:^(NSError *error) {
        [expectation fulfill];
    }];
    [self waitForExpectations:@[expectation] timeout:2.0];
}

- (SFUserAccount*)createNewUser {
    NSString *userID = @"005R0000000DslaIAC";
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:[NSString stringWithFormat:@"identifier-%lu", (unsigned long)userID] clientId:[SFUserAccountManager sharedInstance].oauthClientId encrypted:YES];
    SFUserAccount *user = [[SFUserAccount alloc] initWithCredentials:credentials];
    user.credentials.identityUrl = [NSURL URLWithString:[NSString stringWithFormat:@"https://login.salesforce.com/id/%@/%@", @"00D000000000062EAA", userID]];
    return user;
}

@end
