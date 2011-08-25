//
//  QueryListViewController.m
//  RestAPIExplorer
//
//  Created by Didier Prophete on 7/22/11.
//  Copyright 2011 Salesforce.com. All rights reserved.
//

#import "QueryListViewController.h"
#import "RestAPIExplorerAppDelegate.h"
#import "RestAPIExplorerViewController.h"
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
