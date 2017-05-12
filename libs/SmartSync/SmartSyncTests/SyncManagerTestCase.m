/*
 Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.
 
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

#import <SmartStore/SFSoupIndex.h>
#import <SmartStore/SFSmartStore.h>
#import <SalesforceSDKCore/SFAuthenticationManager.h>
#import <SalesforceSDKCore/TestSetupUtils.h>
#import "TestSyncUpTarget.h"
#import "SyncManagerTestCase.h"

static NSException *authException = nil;

@implementation SyncManagerTestCase

+ (void)setUp
{
    @try {
        [SFLogger sharedLogger].logLevel = SFLogLevelDebug;
        [SFSyncManagerLogger setLevel:SFLogLevelDebug];
        [TestSetupUtils populateAuthCredentialsFromConfigFileForClass:[self class]];
        [TestSetupUtils synchronousAuthRefresh];
        [SFSmartStore removeAllStores];

    } @catch (NSException *exception) {
        [self log:SFLogLevelDebug format:@"Populating auth from config failed: %@", exception];
        authException = exception;
    }
    [super setUp];
}

- (void)setUp
{
    if (authException) {
        XCTFail(@"Setting up authentication failed: %@", authException);
    }
    [SFRestAPI setIsTestRun:YES];
    [[SFRestAPI sharedInstance] setCoordinator:[SFAuthenticationManager sharedManager].coordinator];

    // User and managers setup
    self.currentUser = [SFUserAccountManager sharedInstance].currentUser;
    self.syncManager = [SFSmartSyncSyncManager sharedInstance:self.currentUser];
    self.store = [SFSmartStore sharedStoreWithName:kDefaultSmartStoreName user:self.currentUser];
    [super setUp];
}

- (void)tearDown
{
    // User and managers tear down
    [SFSmartSyncSyncManager removeSharedInstance:self.currentUser];
    [[SFRestAPI sharedInstance] cleanup];
    [SFRestAPI setIsTestRun:NO];

    self.currentUser = nil;
    self.syncManager = nil;
    self.store = nil;

    // Some test runs were failing, saying the run didn't complete. This seems to fix that.
    [NSThread sleepForTimeInterval:0.1];
    [super tearDown];
}

- (NSString*)createRecordName:(NSString*)objectType {
    return [NSString stringWithFormat:@"SyncManagerTestCase_%@_%08d", objectType, arc4random_uniform(100000000)];
}

- (NSString*) createAccountName {
    return [self createRecordName:ACCOUNT_TYPE];
}

- (NSArray<NSDictionary*>*) createAccountsLocally:(NSArray<NSString*>*)names {
    NSMutableArray<NSDictionary *> *accounts = [NSMutableArray new];
    NSDictionary *attributes = @{TYPE: ACCOUNT_TYPE};
    for (NSString *name in names) {
        NSDictionary *account = @{
                ID: [self createLocalId],
                NAME: name,
                DESCRIPTION: [@[DESCRIPTION, name] componentsJoinedByString:@"_"],
                ATTRIBUTES: attributes,
                kSyncTargetLocal: @YES,
                kSyncTargetLocallyCreated: @YES,
                kSyncTargetLocallyUpdated: @NO,
                kSyncTargetLocallyDeleted: @NO,
        };
        [accounts addObject:account];
    }
    return [self.store upsertEntries:accounts toSoup:ACCOUNTS_SOUP];
}

- (NSString*) createLocalId {
    return [NSString stringWithFormat:@"local_%08d", arc4random_uniform(100000000)];
}

- (void)createAccountsSoup {
    NSArray* indexSpecs = @[
                            [[SFSoupIndex alloc] initWithPath:ID indexType:kSoupIndexTypeString columnName:nil],
                            [[SFSoupIndex alloc] initWithPath:NAME indexType:kSoupIndexTypeString columnName:nil],
                            [[SFSoupIndex alloc] initWithPath:DESCRIPTION indexType:kSoupIndexTypeFullText columnName:nil],
                            [[SFSoupIndex alloc] initWithPath:kSyncTargetLocal indexType:kSoupIndexTypeString columnName:nil]
                            ];
    [self.store registerSoup:ACCOUNTS_SOUP withIndexSpecs:indexSpecs error:nil];
}

- (void)dropAccountsSoup{
    [self.store removeSoup:ACCOUNTS_SOUP];
}

- (void)createContactsSoup {
    NSArray* indexSpecs = @[
            [[SFSoupIndex alloc] initWithPath:ID indexType:kSoupIndexTypeString columnName:nil],
            [[SFSoupIndex alloc] initWithPath:LAST_NAME indexType:kSoupIndexTypeString columnName:nil],
            [[SFSoupIndex alloc] initWithPath:ACCOUNT_ID indexType:kSoupIndexTypeString columnName:nil],
            [[SFSoupIndex alloc] initWithPath:kSyncTargetLocal indexType:kSoupIndexTypeString columnName:nil]
    ];
    [self.store registerSoup:CONTACTS_SOUP withIndexSpecs:indexSpecs error:nil];
}

- (void)dropContactsSoup{
    [self.store removeSoup:CONTACTS_SOUP];
}

- (NSString*) buildInClause:(NSArray*)values {
    return [NSString stringWithFormat:@"('%@')", [values componentsJoinedByString:@"', '"]];
}
@end
