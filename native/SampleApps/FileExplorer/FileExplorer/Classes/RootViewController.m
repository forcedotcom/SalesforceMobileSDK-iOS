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


#import "RootViewController.h"

#import <SalesforceSDKCore/SFAuthenticationManager.h>
#import <SalesforceNativeSDK/SFRestAPI+Blocks.h>
#import <SalesforceNativeSDK/SFRestAPI+Files.h>
#import <SalesforceNativeSDK/SFRestRequest.h>

typedef void (^ThumbnailLoadedBlock) (UIImage *thumbnailImage);

@interface RootViewController () {
}
@property (nonatomic, strong) UIBarButtonItem* logoutButton;
@property (nonatomic, strong) UIBarButtonItem* cancelRequestsButton;
@property (nonatomic, strong) UIBarButtonItem* ownedFilesButton;
@property (nonatomic, strong) UIBarButtonItem* sharedFilesButton;
@property (nonatomic, strong) UIBarButtonItem* groupsFilesButton;
// very basic in-memory cache
@property (nonatomic, strong) NSMutableDictionary* thumbnailCache;

- (void) downloadThumbnail:(NSString*)fileId completeBlock:(ThumbnailLoadedBlock)completeBlock;
- (void) logout;
- (void) cancelRequests;
- (void) showOwnedFiles;
- (void) showGroupsFiles;
- (void) showSharedFiles;

@end

@implementation RootViewController

@synthesize dataRows;
@synthesize logoutButton;
@synthesize cancelRequestsButton;
@synthesize ownedFilesButton;
@synthesize sharedFilesButton;
@synthesize groupsFilesButton;

#pragma mark Misc

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Relinquish ownership any cached data, images, etc that aren't in use.
}

- (void)dealloc
{
    self.dataRows = nil;
    self.logoutButton = nil;
    self.cancelRequestsButton = nil;
    self.ownedFilesButton = nil;
    self.sharedFilesButton = nil;
    self.groupsFilesButton = nil;
    self.thumbnailCache = nil;
}


#pragma mark - View lifecycle
- (void)loadView {
    [super loadView];
    self.thumbnailCache = [NSMutableDictionary dictionary];
    self.title = @"FileExplorer";
    logoutButton = [[UIBarButtonItem alloc] initWithTitle:@"Logout" style:UIBarButtonItemStylePlain target:self action:@selector(logout)];
    cancelRequestsButton = [[UIBarButtonItem alloc] initWithTitle:@"Cancel" style:UIBarButtonItemStylePlain target:self action:@selector(cancelRequests)];
    self.navigationItem.leftBarButtonItems = @[logoutButton, cancelRequestsButton];
    
    ownedFilesButton = [[UIBarButtonItem alloc] initWithTitle:@"Owned" style:UIBarButtonItemStylePlain target:self action:@selector(showOwnedFiles)];
    groupsFilesButton = [[UIBarButtonItem alloc] initWithTitle:@"Groups" style:UIBarButtonItemStylePlain target:self action:@selector(showGroupsFiles)];
    sharedFilesButton = [[UIBarButtonItem alloc] initWithTitle:@"Shared" style:UIBarButtonItemStylePlain target:self action:@selector(showSharedFiles)];
    self.navigationItem.rightBarButtonItems = @[ownedFilesButton, groupsFilesButton, sharedFilesButton];
}

#pragma mark - Button handlers

- (void) logout
{
    [[SFAuthenticationManager sharedManager] logout];
}

-(void) cancelRequests
{
    [[SFRestAPI sharedInstance] cancelAllRequests];
}

- (void) showOwnedFiles
{
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForOwnedFilesList:nil page:0];
    [[SFRestAPI sharedInstance] send:request delegate:self];
}

- (void) showGroupsFiles
{
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForFilesInUsersGroups:nil page:0];
    [[SFRestAPI sharedInstance] send:request delegate:self];
}

- (void) showSharedFiles
{
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForFilesSharedWithUser:nil page:0];
    [[SFRestAPI sharedInstance] send:request delegate:self];
}


#pragma mark - SFRestAPIDelegate

- (void)request:(SFRestRequest *)request didLoadResponse:(id)jsonResponse {
    NSArray *files = jsonResponse[@"files"];
    NSLog(@"request:didLoadResponse: #files: %d", files.count);
    self.dataRows = files;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });
}


- (void)request:(SFRestRequest*)request didFailLoadWithError:(NSError*)error {
    NSLog(@"request:didFailLoadWithError: %@", error);
    //add your failed error handling here
}

- (void)requestDidCancelLoad:(SFRestRequest *)request {
    NSLog(@"requestDidCancelLoad: %@", request);
    //add your failed error handling here
}

- (void)requestDidTimeout:(SFRestRequest *)request {
    NSLog(@"requestDidTimeout: %@", request);
    //add your failed error handling here
}

#pragma mark - thumbnail handling

/**
 * Return image from cache if available, otherwise download image from server, and then size it and cache it
 */
- (void) getThumbnail:(NSString*) fileId completeBlock:(ThumbnailLoadedBlock)completeBlock {
    // cache hit
    if (self.thumbnailCache[fileId]) {
        completeBlock(self.thumbnailCache[fileId]);
    }
    // cache miss
    else {
        [self downloadThumbnail:fileId completeBlock:^(UIImage *image) {
            // size it
            UIGraphicsBeginImageContext(CGSizeMake(120,90));
            [image drawInRect:CGRectMake(0, 0, image.size.width, 90)];
            UIImage *thumbnailImage = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            // cache it
            self.thumbnailCache[fileId] = thumbnailImage;
            // done
            completeBlock(thumbnailImage);
        }];
    }
}

- (void) downloadThumbnail:(NSString*)fileId completeBlock:(ThumbnailLoadedBlock)completeBlock {
    SFRestRequest *imageRequest = [[SFRestAPI sharedInstance] requestForFileRendition:fileId version:nil renditionType:@"THUMB120BY90" page:0];
    [[SFRestAPI sharedInstance] sendRESTRequest:imageRequest failBlock:nil completeBlock:^(NSData *responseData) {
        NSLog(@"downloadThumbnail:%@ completed", fileId);
        UIImage *image = [UIImage imageWithData:responseData];
        dispatch_async(dispatch_get_main_queue(), ^{
            completeBlock(image);
        });
    }];
}


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.dataRows count];
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView_ cellForRowAtIndexPath:(NSIndexPath *)indexPath {
   static NSString *CellIdentifier = @"CellIdentifier";

   // Dequeue or create a cell of the appropriate type.
    UITableViewCell *cell = [tableView_ dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }

	// Configure the cell to show the data.
    NSDictionary *obj = [dataRows objectAtIndex:indexPath.row];
    NSString *fileId = obj[@"id"];
    NSInteger tag = [fileId hash];

	cell.textLabel.text =  obj[@"title"];
    cell.detailTextLabel.text = obj[@"owner"][@"name"];
    cell.tag = tag;
    [self getThumbnail:fileId completeBlock:^(UIImage* thumbnailImage) {
        // Cell are recycled - we don't want to set the image if the cell is showing a different file
        if (cell.tag == tag) {
            cell.imageView.image = thumbnailImage;
            [cell setNeedsLayout];
        }
    }];

	return cell;

}


- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 90;
}

@end
