//
//  UserIdUpgradeTests.m
//  SalesforceSDKCore
//
//  Created by Brianna Birman on 6/8/20.
//  Copyright (c) 2020-present, salesforce.com, inc. All rights reserved.
// 
//  Redistribution and use of this software in source and binary forms, with or without modification,
//  are permitted provided that the following conditions are met:
//  * Redistributions of source code must retain the above copyright notice, this list of conditions
//  and the following disclaimer.
//  * Redistributions in binary form must reproduce the above copyright notice, this list of
//  conditions and the following disclaimer in the documentation and/or other materials provided
//  with the distribution.
//  * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
//  endorse or promote products derived from this software without specific prior written
//  permission of salesforce.com, inc.
// 
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
//  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
//  FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
//  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
//  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
//  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
//  WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import <XCTest/XCTest.h>
#import "SFUserAccount.h"
#import "SFDirectoryManager.h"
#import "SFDirectoryManager+Internal.h"
#import "SFSDKResourceUtils.h"
#import "SFOAuthCredentials.h"
#import "SFOAuthCredentials+Internal.h"

static NSString *userId15 = @"005B0000005WYRK";
static NSString *userId18 = @"005B0000005WYRKIA4";
static NSString *orgId = @"00DB0000000ToZ3MAK";
static NSString *communityId = @"COMMUNITYID";

@interface SFUserAccount (Testing)

- (NSString *)userPhotoDirectory;
@end

// TODO: Remove in Mobile SDK 10.0
@interface SFUserIdUpgradeTests : XCTestCase

@end

@implementation SFUserIdUpgradeTests

- (void)setUp {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *libraryDirectoryOrg = [[SFDirectoryManager sharedManager] directoryForOrg:orgId user:nil community:nil type:NSLibraryDirectory components:nil];
    [fm removeItemAtPath:libraryDirectoryOrg error:nil];
    NSString *documentDirectoryOrg = [[SFDirectoryManager sharedManager] directoryForOrg:orgId user:nil community:nil type:NSDocumentDirectory components:nil];
    [fm removeItemAtPath:documentDirectoryOrg error:nil];
}

- (void)testProfilePhoto {
    SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] initWithIdentifier:@"CLIENT ID"  clientId:@"CLIENT ID" encrypted:NO];
    creds.userId = userId18;
    creds.organizationId = orgId;
    creds.communityId = communityId;
    SFUserAccount *account = [[SFUserAccount alloc] initWithCredentials:creds];
    NSString *photoDirectoryPath = [account userPhotoDirectory];
    [SFDirectoryManager ensureDirectoryExists:photoDirectoryPath error:nil];
    
    // Create photo with 15 character name
    NSString *photoPath15 = [photoDirectoryPath stringByAppendingPathComponent:userId15];
    UIImage *photo = [[UIImage alloc] initWithCGImage:[SFSDKResourceUtils imageNamed:@"salesforce-logo"].CGImage];
    NSData *originalPhotoData = UIImagePNGRepresentation(photo);
    [originalPhotoData writeToFile:photoPath15 options:NSDataWritingAtomic error:nil];
    
    // Accessing photo should rename from 15 to 18 character path if needed and return photo
    XCTAssertNotNil(account.photo, "Account photo not found");
    NSString *photoPath18 = [photoDirectoryPath stringByAppendingPathComponent:userId18];
    NSFileManager *fm = [[NSFileManager alloc] init];
    XCTAssertFalse([fm fileExistsAtPath:photoPath15]);
    XCTAssertTrue([fm fileExistsAtPath:photoPath18]);
}

- (void)testDirectories {
    // Create directories based on 15 character user ID
    NSError *error = nil;
    NSString *libraryDirectory15 = [[SFDirectoryManager sharedManager] directoryForOrg:orgId user:userId15 community:communityId type:NSLibraryDirectory components:nil];
    [SFDirectoryManager ensureDirectoryExists:libraryDirectory15 error:&error];
    XCTAssertNil(error, @"Error creating directory: %@", error);
    
    NSString *documentDirectory15 = [[SFDirectoryManager sharedManager] directoryForOrg:orgId user:userId15 community:communityId type:NSDocumentDirectory components:nil];
    [SFDirectoryManager ensureDirectoryExists:documentDirectory15 error:&error];
    XCTAssertNil(error, @"Error creating directory: %@", error);
    
    // Upgrade everything to 18 characters
    [SFDirectoryManager upgradeUserDirectories];
    
    NSFileManager *fm = [[NSFileManager alloc] init];
    NSString *libraryDirectory18 = [libraryDirectory15 stringByReplacingOccurrencesOfString:userId15 withString:userId18];
    XCTAssertFalse([fm fileExistsAtPath:libraryDirectory15]);
    XCTAssertTrue([fm fileExistsAtPath:libraryDirectory18]);
    
    NSString *documentDirectory18 = [documentDirectory15 stringByReplacingOccurrencesOfString:userId15 withString:userId18];
    XCTAssertFalse([fm fileExistsAtPath:documentDirectory15]);
    XCTAssertTrue([fm fileExistsAtPath:documentDirectory18]);
}

@end
