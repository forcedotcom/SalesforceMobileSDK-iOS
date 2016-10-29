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

#import "QueryListViewController.h"
#import "RestAPIExplorerViewController.h"

//action constants
NSString *const kActionVersions = @"versions";
NSString *const kActionResources = @"resources";
NSString *const kActionDescribeGlobal = @"describeGlobal";
NSString *const kActionObjectMetadata = @"metadataWithObjectType:";
NSString *const kActionObjectDescribe = @"describeWithObjectType:";
NSString *const kActionRetrieveObject = @"retrieveWithObjectType:objectId:fieldList:";
NSString *const kActionCreateObject = @"createWithObjectType:fields:";
NSString *const kActionUpsertObject = @"upsertWithObjectType:externalField:externalId:fields:";
NSString *const kActionUpdateObject = @"updateWithObjectType:objectId:fields:";
NSString *const kActionDeleteObject = @"deleteWithObjectType:objectId:";
NSString *const kActionQuery = @"query:";
NSString *const kActionSearch = @"search:";
NSString *const kActionSearchScopeAndOrder = @"searchScopeAndOrder:";
NSString *const kActionSearchResultLayout = @"searchResultLayout:";
NSString *const kActionOwnedFilesList = @"ownedFilesList:page";
NSString *const kActionFilesInUsersGroups = @"filesInUsersGroups:page";
NSString *const kActionFilesSharedWithUser = @"filesSharedWithUser:page";
NSString *const kActionFileDetails = @"fileDetails:forVersion";
NSString *const kActionBatchFileDetails = @"batchFileDetails:";
NSString *const kActionFileShares = @"fileShares:page";
NSString *const kActionAddFileShare = @"addFileShare:entityId:shareType";
NSString *const kActionDeleteFileShare = @"deleteFileShares:";
NSString *const kActionLogout = @"logout";
NSString *const kActionSwitchUser = @"switch user";
NSString *const kActionUserInfo = @"current user info";
NSString *const kActionExportCredentialsForTesting = @"Export credentials to pasteboard";


@implementation QueryListViewController

@synthesize actions=_actions;
@synthesize appViewController=_appViewController;

- (id)initWithAppViewController:(RestAPIExplorerViewController *)appViewController {
    self = [super init];
    if (self) {
        self.appViewController = appViewController;
        self.actions = @[kActionVersions, @"no params",
                        kActionResources, @"no params",
                        kActionDescribeGlobal, @"no params",
                        kActionObjectMetadata, @"params: objectType",
                        kActionObjectDescribe, @"params: objectType",
                        kActionRetrieveObject, @"params: objectType, objectId, fieldList",
                        kActionCreateObject, @"params: objectType, fields",
                        kActionUpsertObject, @"params: objectType, externalField, externalId, fields",
                        kActionUpdateObject, @"params: objectType, objectId, fields",
                        kActionDeleteObject, @"params: objectType, objectId",
                        kActionQuery, @"params: query",
                        kActionSearch, @"params: search",
                        kActionSearchScopeAndOrder, @"no params",
                        kActionSearchResultLayout, @"params: objectList",
                        kActionOwnedFilesList, @"params: userId, page",
                        kActionFilesInUsersGroups, @"params: userId, page",
                        kActionFilesSharedWithUser, @"params: userId, page",
                        kActionFileDetails, @"params: objectId, version",
                        kActionBatchFileDetails, @"params: objectIdList",
                        kActionFileShares, @"params: objectId, page",
                        kActionAddFileShare, @"params: objectId, entityId, sharedType",
                        kActionDeleteFileShare, @"params: objectId",
                        kActionUserInfo, @"no params",
                        kActionLogout, @"no params",
                        kActionSwitchUser, @"no params",
                        kActionExportCredentialsForTesting, @"no params"];
    }
    return self;
}

- (void) dealloc
{
    SFRelease(_actions);
    SFRelease(_appViewController);
}

#pragma mark - View lifecycle

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
	return YES;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _actions.count / 2;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
    
    cell.textLabel.text = _actions[indexPath.row * 2];
    cell.detailTextLabel.text = _actions[indexPath.row * 2+1];
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *text = _actions[indexPath.row * 2];
    [self.appViewController popoverOptionSelected:text];
}

@end
