/*
 Copyright (c) 2011, salesforce.com, inc. All rights reserved.
 
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
#import "RestAPIExplorerAppDelegate.h"
#import "RestAPIExplorerViewController.h"

NSString *const kActionExportCredentialsForTesting = @"Export credentials to pasteboard";


@implementation QueryListViewController

@synthesize actions=_actions;
@synthesize appViewController=_appViewController;

- (id)initWithAppViewController:(RestAPIExplorerViewController *)appViewController {
    self = [super init];
    if (self) {
        self.appViewController = appViewController;
        self.actions = [NSArray arrayWithObjects:
                        @"versions", @"no params",
                        @"resources", @"no params",
                        @"describeGlobal", @"no params",
                        @"metadataWithObjectType:", @"params: objectType",
                        @"describeWithObjectType:", @"params: objectType",
                        @"retrieveWithObjectType:objectId:fieldList:", @"params: objectType, objectId, fieldList",
                        @"createWithObjectType:fields:", @"params: objectType, fields",
                        @"upsertWithObjectType:externalField:externalId:fields:", @"params: objectType, externalField, externalId, fields",
                        @"updateWithObjectType:objectId:fields:", @"params: objectType, objectId, fields",
                        @"requestForDeleteWithObjectType:objectId:", @"params: objectType, objectId",
                        @"query:", @"params: query",
                        @"search:", @"params: search",
                        @"logout", @"no params",
                        kActionExportCredentialsForTesting, @"no params",
                        nil];
    }
    return self;
}

- (void)dealloc
{
    self.appViewController = nil;
    self.actions = nil;
    [super dealloc];
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
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier] autorelease];
    }
    
    cell.textLabel.text = [_actions objectAtIndex:indexPath.row * 2];
    cell.detailTextLabel.text = [_actions objectAtIndex:indexPath.row * 2+1];
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *text = [_actions objectAtIndex:indexPath.row * 2];
    [self.appViewController popoverOptionSelected:text];
}

@end
