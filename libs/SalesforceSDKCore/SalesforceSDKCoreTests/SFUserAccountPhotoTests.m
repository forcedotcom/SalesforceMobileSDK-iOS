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
#import "SFOAuthCredentials+Internal.h"

@interface SFUserAccount (Testing)

- (NSString *)photoPathInternal:(NSError**)error;
- (UIImage *)decryptPhoto:(NSString *)photoPath;

@end

static NSString * const kUserIdFormatString = @"005R0000000Dsl%lu";
static NSString * const kOrgIdFormatString = @"00D000000000062EA%lu";

@interface SFUserAccountPhotoTests : XCTestCase

@end

@implementation SFUserAccountPhotoTests

- (void)testPhotoEncryption {
    SFUserAccount *user = [self createNewUserWithIndex:0];
    NSError *error = nil;
    NSString *userPhotoPath = [user photoPathInternal:&error];
    
    // Write unencrypted file to disk for upgrade scenario
    // Recreating UIImage from named resource because otherwise resource includes additional metadata that breaks comparison of
    // images as NSData
    UIImage *originalPhoto = [[UIImage alloc] initWithCGImage:[SFSDKResourceUtils imageNamed:@"salesforce-logo"].CGImage];
    NSData *originalPhotoData = UIImagePNGRepresentation(originalPhoto);
    [originalPhotoData writeToFile:userPhotoPath options:NSDataWritingAtomic error:&error];
    XCTAssertNil(error);
    
    // Access photo which should pick up from disk and encrypt it
    UIImage *userPhoto = user.photo;
    XCTAssertNotNil(userPhoto);
    NSData *userPhotoData = UIImagePNGRepresentation(userPhoto);
    XCTAssertNotNil(userPhotoData);
    XCTAssertTrue([userPhotoData isEqualToData:originalPhotoData]);
    
    // Check that data on disk is different since it should be encrypted now
    NSData *encryptedPhotoData = [[NSData alloc] initWithContentsOfFile:userPhotoPath];
    XCTAssertNotNil(encryptedPhotoData);
    XCTAssertFalse([encryptedPhotoData isEqualToData:originalPhotoData]);
    
    // Check decrypted disk data
    UIImage *decryptedPhoto = [user decryptPhoto:userPhotoPath];
    NSData *decryptedPhotoData = UIImagePNGRepresentation(decryptedPhoto);
    XCTAssertTrue([decryptedPhotoData isEqualToData:originalPhotoData]);
}

- (void)testPhotoWithCompletionBlock {
    SFUserAccount *user = [self createNewUserWithIndex:0];
    [self setPhoto:user photo:nil];
    XCTAssertNil(user.photo);
    
    UIImage *testPhoto = [SFSDKResourceUtils imageNamed:@"salesforce-logo"];
    [self setPhoto:user photo:testPhoto];
    XCTAssertEqualObjects(user.photo, testPhoto);
    
    [self setPhoto:user photo:nil];
    XCTAssertNil(user.photo);
}

- (void)testPhotoWithoutCompletionBlock {
    SFUserAccount *user = [self createNewUserWithIndex:0];
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

- (SFUserAccount*)createNewUserWithIndex:(NSUInteger)index {
    XCTAssertTrue(index < 10, @"Supports only index up to 9");
    SFOAuthCredentials *credentials = [[SFOAuthCredentials alloc] initWithIdentifier:[NSString stringWithFormat:@"identifier-%lu", (unsigned long)index] clientId:[SFUserAccountManager  sharedInstance].oauthClientId encrypted:YES];
    SFUserAccount *user =[[SFUserAccount alloc] initWithCredentials:credentials];
    NSString *userId = [NSString stringWithFormat:kUserIdFormatString, (unsigned long)index];
    NSString *orgId = [NSString stringWithFormat:kOrgIdFormatString, (unsigned long)index];
    user.credentials.identityUrl = [NSURL URLWithString:[NSString stringWithFormat:@"https://login.salesforce.com/id/%@/%@", orgId, userId]];
    return user;
}

@end
