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



static NSString * const RemoteAccessConsumerKey = @"3MVG9Iu66FKeHhINkB1l7xt7kR8czFcCTUhgoA8Ol2Ltf1eYHOU4SqQRSEitYFDUpqRWcoQ2.dBv_a1Dyu5xa";
static NSString * const OAuthRedirectURI        = @"testsfdc:///mobilesdk/detect/oauth/done";

@interface TodayViewController () <NCWidgetProviding,SFRestDelegate,UITableViewDelegate,UITableViewDataSource>{
      NSMutableArray *_contacts;
}
@property (weak, nonatomic) IBOutlet UITableView *todayTableView;
@property (nonatomic, strong) SObjectDataManager *dataMgr;

@end

@implementation TodayViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    #if defined(DEBUG)
        [SFLogger sharedLogger].logLevel = SFLogLevelDebug;
    #else
        [SFLogger sharedLogger].logLevel = SFLogLevelInfo;
    #endif

    _contacts = [NSMutableArray new];
    [self.todayTableView setDataSource:self];
    [self.todayTableView setDelegate:self];

   

    
    // Do any additional setup after loading the view from its nib.
}

- (void) refreshList {
//    __weak TodayViewController *weakSelf = self;
//
//    [self.dataMgr filterOnSearchTerm:@"" completion:^{
//        [weakSelf.todayTableView reloadData];
//    }];
    [self.todayTableView reloadData];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)widgetPerformUpdateWithCompletionHandler:(void (^)(NCUpdateResult))completionHandler {
    // Perform any setup necessary in order to update the view.
    
    // If an error is encountered, use NCUpdateResultFailed
    // If there's no update required, use NCUpdateResultNoData
    // If there's an update, use NCUpdateResultNewData
    [SFSDKDatasharingHelper sharedInstance].appGroupName = @"group.com.salesforce.mobilesdk.internal.SmartSyncExplorer";
    [SFSDKDatasharingHelper sharedInstance].appGroupEnabled = YES;
    if( [self userLoginStatus] ) {
       
        [SalesforceSDKManager setInstanceClass:[SalesforceSDKManagerWithSmartStore class]];
        [SalesforceSDKManager sharedManager].connectedAppId = RemoteAccessConsumerKey;
        [SalesforceSDKManager sharedManager].connectedAppCallbackUri = OAuthRedirectURI;
        [SalesforceSDKManager sharedManager].authScopes = @[@"web", @"api"];
        [SalesforceSDKManager sharedManager].authenticateAtLaunch = FALSE;
        
        NSArray *accounts = [[SFUserAccountManager sharedInstance] allUserAccounts];
        if(accounts && accounts.count>0) {
            // check for actual Account or id of account or pick the first one?
            [[SFUserAccountManager sharedInstance] setCurrentUser:accounts[0]];
            
            __weak typeof(self) weakSelf = self;
            void (^completionBlock)(void) = ^{
                [weakSelf refreshList];
            };
          
            if (!self.dataMgr) {
                self.dataMgr = [[SObjectDataManager alloc] initWithDataSpec:[ContactSObjectData dataSpec]];
            }
            [self.dataMgr lastModifiedRecords:3 completion:completionBlock];
            
        }
    }
    completionHandler(NCUpdateResultNewData);
}

- (BOOL)userLoginStatus {
    return [[NSUserDefaults msdkUserDefaults] boolForKey:@"userLoggedIn"];
}

- (void)request:(SFRestRequest *)request didLoadResponse:(id)dataResponse {
    NSLog(@"Request Success");
    dispatch_async(dispatch_get_main_queue(), ^{
        NSArray *records = ((NSDictionary *)dataResponse)[@"records"];
        [_contacts removeAllObjects];
        [_contacts addObjectsFromArray:records];
        [_todayTableView reloadData];
        NSLog(@"didLoadResponse %@",records);
    });

}

- (void)request:(SFRestRequest *)request didFailLoadWithError:(NSError *)error {
    NSLog(@"Request Error");
}

- (void)requestDidCancelLoad:(SFRestRequest *)request {
    NSLog(@"Request requestDidCancelLoad");
}

- (void)requestDidTimeout:(SFRestRequest *)request {
    NSLog(@"Request requestDidTimeout");
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return  self.dataMgr==nil?0:[self.dataMgr.dataRows count];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *simpleTableIdentifier = @"SimpleTableItem";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:simpleTableIdentifier];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:simpleTableIdentifier];
    }
    ContactSObjectData *contact = [self.dataMgr.dataRows objectAtIndex:indexPath.row] ;
    cell.textLabel.text = [NSString stringWithFormat:@"%@ %@", contact.firstName,contact.lastName];
    return cell;

}
@end
