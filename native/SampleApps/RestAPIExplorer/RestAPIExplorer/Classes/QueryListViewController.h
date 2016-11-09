/*
 Copyright (c) 2011-present, salesforce.com, inc. All rights reserved.
 
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

#import <UIKit/UIKit.h>

@class RestAPIExplorerViewController;


//action constants
extern NSString *const kActionVersions;
extern NSString *const kActionResources;
extern NSString *const kActionDescribeGlobal;
extern NSString *const kActionObjectMetadata;
extern NSString *const kActionObjectDescribe;
extern NSString *const kActionRetrieveObject;
extern NSString *const kActionCreateObject;
extern NSString *const kActionUpsertObject;
extern NSString *const kActionUpdateObject;
extern NSString *const kActionDeleteObject;
extern NSString *const kActionQuery;
extern NSString *const kActionSearch;
extern NSString *const kActionSearchScopeAndOrder;
extern NSString *const kActionSearchResultLayout;
extern NSString *const kActionOwnedFilesList;
extern NSString *const kActionFilesInUsersGroups;
extern NSString *const kActionFilesSharedWithUser;
extern NSString *const kActionFileDetails;
extern NSString *const kActionBatchFileDetails;
extern NSString *const kActionFileShares;
extern NSString *const kActionAddFileShare;
extern NSString *const kActionDeleteFileShare;
extern NSString *const kActionLogout;
extern NSString *const kActionSwitchUser;
extern NSString *const kActionUserInfo;
extern NSString *const kActionExportCredentialsForTesting;

@interface QueryListViewController : UITableViewController {
    NSArray *_actions;
    RestAPIExplorerViewController *_appViewController;
}

@property (nonatomic, strong) NSArray *actions;
@property (nonatomic, strong) RestAPIExplorerViewController *appViewController;

- (id)initWithAppViewController:(RestAPIExplorerViewController *)appViewController;

@end
