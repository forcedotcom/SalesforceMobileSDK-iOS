/*
 Copyright (c) 2016, salesforce.com, inc. All rights reserved.

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
#import "TodayViewController.h"
#import <SmartSyncExplorerCommon/SmartSyncExplorerCommon.h>
#import <NotificationCenter/NotificationCenter.h>
#import <SmartStore/SalesforceSDKManagerWithSmartStore.h>
#import <SalesforceSDKCore/SFSDKDatasharingHelper.h>
#import <SalesforceSDKCore/NSUserDefaults+SFAdditions.h>
#import <SalesforceSDKCore/SFRestRequest.h>
#import <SalesforceSDKCore/SFRestAPI.h>
#import <SalesforceSDKCore/SFLoggerMacros.h>
#import <SalesforceSDKCore/SFLogger.h>
#import <SmartStore/SFQuerySpec.h>

@interface TodayViewController () <NCWidgetProviding,UITableViewDelegate,UITableViewDataSource>

@property (weak, nonatomic) IBOutlet UITableView *todayTableView;
@property (nonatomic, strong) SObjectDataManager *dataMgr;
- (BOOL)userIsLoggedIn;

@end

static const NSUInteger kNumberOfRecords = 3;
static NSString *simpleTableIdentifier = @"SimpleTableItem";

@implementation TodayViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    #if defined(DEBUG)
        [SFLogger sharedLogger].logLevel = SFLogLevelDebug;
    #else
        [SFLogger sharedLogger].logLevel = SFLogLevelInfo;
    #endif
    self.todayTableView.dataSource = self;
    self.todayTableView.delegate = self;
}

- (void) refreshList {
    [self.todayTableView reloadData];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)widgetPerformUpdateWithCompletionHandler:(void (^)(NCUpdateResult))completionHandler {

    SmartSyncExplorerConfig *config = [SmartSyncExplorerConfig sharedInstance];

    [SFSDKDatasharingHelper sharedInstance].appGroupName = config.appGroupName;
    [SFSDKDatasharingHelper sharedInstance].appGroupEnabled = YES;
    if([self userIsLoggedIn] ) {
        [self log:SFLogLevelError format:@"User has logged in"];
        [SalesforceSDKManager setInstanceClass:[SalesforceSDKManagerWithSmartStore class]];
        [SalesforceSDKManager sharedManager].connectedAppId = config.remoteAccessConsumerKey;
        [SalesforceSDKManager sharedManager].connectedAppCallbackUri = config.oauthRedirectURI;
        [SalesforceSDKManager sharedManager].authScopes = config.oauthScopes;
        [SalesforceSDKManager sharedManager].authenticateAtLaunch = config.appGroupsEnabled;

        SFUserAccountIdentity *activeUserIdentity = [SFUserAccountManager sharedInstance].activeUserIdentity;
        SFUserAccount *currentUser = [[SFUserAccountManager sharedInstance] userAccountForUserIdentity:activeUserIdentity];
        [SFUserAccountManager sharedInstance].currentUser = currentUser;

        __weak typeof(self) weakSelf = self;
        void (^completionBlock)(void) = ^{
            [weakSelf refreshList];
        };

        if(currentUser) {
            if (!self.dataMgr) {
                self.dataMgr = [[SObjectDataManager alloc] initWithDataSpec:[ContactSObjectData dataSpec]];
            }
            [self.dataMgr lastModifiedRecords:kNumberOfRecords completion:completionBlock];
        }
    }
    completionHandler(NCUpdateResultNewData);
}

- (BOOL)userIsLoggedIn {
    SmartSyncExplorerConfig *config = [SmartSyncExplorerConfig sharedInstance];
    return [[NSUserDefaults msdkUserDefaults] boolForKey:config.userLogInStatusKey];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return  self.dataMgr==nil?0:[self.dataMgr.dataRows count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
   UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:simpleTableIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:simpleTableIdentifier];
    }
    ContactSObjectData *contact = [self.dataMgr.dataRows objectAtIndex:indexPath.row] ;
    cell.textLabel.text = [NSString stringWithFormat:@"%@ %@", contact.firstName,contact.lastName];
    return cell;

}
@end
