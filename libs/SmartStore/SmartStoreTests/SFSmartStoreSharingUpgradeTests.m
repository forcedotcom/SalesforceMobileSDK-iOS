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
#import <SalesforceSDKCommon/NSUserDefaults+SFAdditions.h>
#import <SalesforceSDKCore/SFKeyStoreManager.h>
#import "NSData+SFAdditions.h"
#import "SFSmartStoreTestCase.h"
#import "SFSmartStoreUpgrade.h"
#import "SFSmartStoreDatabaseManager.h"

#import "sqlite3.h"

#define kTestUpgradeSmartStoreName  @"testSmartStoreUpgrade"
#define kTestSoupName        @"testSoup"

@interface SFSmartStoreDatabaseManager (Private)
- (NSString*)fullDbFilePathForStoreName:(NSString*)storeName;
@end

@interface SFSmartStore (Private)
@property (nonatomic, class,readwrite) SFSmartStoreEncryptionSaltBlock encryptionSaltBlock;
+ (BOOL)hasPlainTextHeader:(NSString *)storeName user:(SFUserAccount *) user;
@end

@interface SFSmartStoreUpgrade (Private)
+ (BOOL)updateSaltForStore:(NSString *)storeName user:(SFUserAccount *)user;
@end

@interface SFSmartStoreSharingUpgradeTests : SFSmartStoreTestCase
@property (nonatomic, strong) SFUserAccount *smartStoreUser;
@property (nonatomic, strong) SFSmartStore *store;
@property (nonatomic, strong) SFSmartStore *globalStore;
@end

@implementation SFSmartStore (Private)
@dynamic encryptionSaltBlock;

+ (BOOL)hasPlainTextHeader:(NSString *)storeName user:(SFUserAccount *) user {
    //53 51 4c 69 74 65 SQLite marker
    uint8_t sqlLiteBytes[]  =  {0x53,0x51,0x4c,0x69,0x74,0x65};
    NSData *sqlLiteHeader = [NSData dataWithBytes:sqlLiteBytes length:6];
    SFSmartStoreDatabaseManager *databaseManager = [SFSmartStoreDatabaseManager sharedManagerForUser:user];

    if (![databaseManager persistentStoreExists:storeName]) {
        return NO;
    }
    NSString *fullDbFilePath = [databaseManager fullDbFilePathForStoreName:storeName];
    NSFileHandle *file = [NSFileHandle fileHandleForUpdatingAtPath:fullDbFilePath];
    [file seekToFileOffset:0];
    NSData *databuffer = [file readDataOfLength:sqlLiteHeader.length];
    [file closeFile];
    return [sqlLiteHeader isEqualToData:databuffer];
}
@end

@implementation SFSmartStoreSharingUpgradeTests

- (void) setUp {
    [super setUp];
    if ([[SFKeyStoreManager sharedInstance] keyWithLabelExists:kSFSmartStoreEncryptionSaltLabel]) {
        [[SFKeyStoreManager sharedInstance] removeKeyWithLabel:kSFSmartStoreEncryptionSaltLabel];
    }
    [[NSUserDefaults msdkUserDefaults] setBool:NO forKey:@"com.salesforce.smartstore.external.hasExternalSalt"];
    
    [SFSDKSmartStoreLogger setLogLevel:SFLogLevelDebug];
    self.smartStoreUser = [self setUpSmartStoreUser];
    [SFSmartStore removeSharedStoreWithName:kTestUpgradeSmartStoreName];
    self.store = [SFSmartStore sharedStoreWithName:kTestUpgradeSmartStoreName];
    self.store.captureExplainQueryPlan = YES;
}

- (void) tearDown
{
    [SFSmartStore removeSharedStoreWithName:kTestUpgradeSmartStoreName];
    [self tearDownSmartStoreUser:self.smartStoreUser];
    self.smartStoreUser = nil;
    self.store = nil;
    
    if ([[SFKeyStoreManager sharedInstance] keyWithLabelExists:kSFSmartStoreEncryptionSaltLabel]) {
        [[SFKeyStoreManager sharedInstance] removeKeyWithLabel:kSFSmartStoreEncryptionSaltLabel];
    }
    [[NSUserDefaults msdkUserDefaults] setBool:NO forKey:@"com.salesforce.smartstore.external.hasExternalSalt"];
    [super tearDown];
}

- (void)testUpgrade {
    //test existence of a datastore with inlined salt
    SFEncryptionKey *origKey = [SFSmartStore encryptionKeyBlock]();
    SFSmartStore *store = [SFSmartStore sharedStoreWithName:kTestUpgradeSmartStoreName];
    XCTAssertNotNil(origKey,@"Database must be setup to have an encKey");
    XCTAssertNotNil(store,@"Store should not be nil");
    XCTAssertFalse([SFSmartStore hasPlainTextHeader:store.storeName user:store.user],@"Database must not have plain text header");
    [self setupSaltBlock];
    NSString *salt = [SFSmartStore encryptionSaltBlock]();
    SFEncryptionKey *key = [SFSmartStore encryptionKeyBlock]();
    XCTAssertNotNil(salt,@"Database must be setup to have a salt");
    XCTAssertEqualObjects(origKey,key,@"Database must  be setup to have the same encKey");
    BOOL result = [SFSmartStoreUpgrade updateSaltForStore:store.storeName user:store.user];
    XCTAssertTrue(result,"Upgrade to using external salt should have worked");
    XCTAssertTrue([SFSmartStore hasPlainTextHeader:store.storeName user:store.user],@"Database now must  have plain text header");
    store = [SFSmartStore sharedStoreWithName:kTestUpgradeSmartStoreName];
    XCTAssertNotNil(store,@"Store should not be nil after upgrade");
    [self clearSaltBlock];
}

- (void)setupSaltBlock {
    [SFSmartStore setEncryptionSaltBlock:^NSString * _Nullable{
            SFEncryptionKey *saltKey = [[SFKeyStoreManager sharedInstance]   retrieveKeyWithLabel:kSFSmartStoreEncryptionSaltLabel autoCreate:YES];
            NSString *salt = [[saltKey key] digest];
            return salt;
    }];
}

- (void)clearSaltBlock {
    [SFSmartStore setEncryptionSaltBlock:nil];
    if ([[SFKeyStoreManager sharedInstance] keyWithLabelExists:kSFSmartStoreEncryptionSaltLabel]) {
        [[SFKeyStoreManager sharedInstance] removeKeyWithLabel:kSFSmartStoreEncryptionSaltLabel];
    }
}


@end
