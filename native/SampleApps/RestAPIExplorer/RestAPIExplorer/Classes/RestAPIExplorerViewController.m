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


#import "RestAPIExplorerViewController.h"

#import "QueryListViewController.h"
#import "AppDelegate.h"
#import <SalesforceSDKCore/SFJsonUtils.h>
#import <SalesforceRestAPI/SFRestAPI.h>
#import <SalesforceRestAPI/SFRestRequest.h>
#import <SalesforceSDKCore/SFSecurityLockout.h>
#import <SalesforceSDKCore/SFAuthenticationManager.h>
#import <SalesforceSDKCore/SFDefaultUserManagementViewController.h>

@interface RestAPIExplorerViewController ()

@property (nonatomic, strong) UIActionSheet *logoutActionSheet;

- (NSString *)formatRequest:(SFRestRequest *)request;
- (void)hideKeyboard;
- (void)clearPopovers:(NSNotification *)note;

@end

@implementation RestAPIExplorerViewController

// action based query
@synthesize popoverController=__popoverController;
@synthesize toolBar = _toolBar;
@synthesize tfObjectType = _tfObjectType;
@synthesize tfObjectId = _tfObjectId;
@synthesize tfExternalId = _tfExternalId;
@synthesize tfSearch = _tfSearch;
@synthesize tfQuery = _tfQuery;
@synthesize tfExternalFieldId = _tfExternalFieldId;
@synthesize tfFieldList = _tfFieldList;
@synthesize tvFields = _tvFields;
@synthesize logoutActionSheet = _logoutActionSheet;
// manual query
@synthesize tfPath=_tfPath;
@synthesize tvParams=_tvParams;
@synthesize segmentMethod=_segmentMethod;
// response
@synthesize tfResponseFor=_tfResponseFor;
@synthesize tfResult=_tfResult;

#pragma mark - init/setup

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"Salesforce API Explorer";
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(clearPopovers:)
                                                 name:kSFPasscodeFlowWillBegin
                                               object:nil];
}


- (void)viewDidUnload
{
    // action based query
    self.popoverController = nil;
    self.toolBar = nil;
    self.logoutActionSheet = nil;
    self.tfObjectType = nil;
    self.tfObjectId = nil;
    self.tfExternalId = nil;
    self.tfSearch = nil;
    self.tfQuery = nil;
    self.tfExternalFieldId = nil;
    self.tfFieldList = nil;
    self.tvFields = nil;
    // manual query
    self.tfPath = nil;
    self.tvParams = nil;
    self.segmentMethod = nil;
    // response
    self.tfResponseFor = nil;
    self.tfResult = nil;

    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return YES;
}


#pragma mark - helper

- (NSString *)formatRequest:(SFRestRequest *)request {
    return [NSString stringWithFormat:@"%@\n\n\n", [[request description] stringByReplacingOccurrencesOfString:@"\n" withString:@"\n"]];
}

- (void)hideKeyboard {
    [_tfPath resignFirstResponder];
    [_tfResult resignFirstResponder];
    [_tfResponseFor resignFirstResponder];
    [_tvParams resignFirstResponder];
    [_segmentMethod resignFirstResponder];
    [_tfObjectType resignFirstResponder];
    [_tfObjectId resignFirstResponder];
    [_tfExternalId resignFirstResponder];
    [_tfSearch resignFirstResponder];
    [_tfQuery resignFirstResponder];
    [_tfExternalFieldId resignFirstResponder];
    [_tfFieldList resignFirstResponder];
    [_tvFields resignFirstResponder];
}

- (void)showMissingFieldError:(NSString *)missingFields {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Missing Field" 
                                                    message:[NSString stringWithFormat:@"You need to fill out the following field(s): %@", missingFields]
                                                   delegate:nil
                                          cancelButtonTitle:@"Ok"
                                          otherButtonTitles: nil];
    [alert show];	
}

#pragma mark - actions

- (IBAction)btnGoPressed:(id)sender {
    [self hideKeyboard];
    NSString *params = _tvParams.text;

    NSDictionary *queryParams = ([params length] == 0
                                 ? nil
                                 : (NSDictionary *)[SFJsonUtils objectFromJSONString:params]
                                 );
                                 
    SFRestMethod method = (SFRestMethod)_segmentMethod.selectedSegmentIndex;
    NSString *path = self.tfPath.text;
    SFRestRequest *request = [SFRestRequest requestWithMethod:method path:path queryParams:queryParams];

    [[SFRestAPI sharedInstance] send:request delegate:self];
}

- (IBAction)btnActionPressed:(id)sender {
    [self hideKeyboard];

    if([self.popoverController isPopoverVisible]){
        [self.popoverController dismissPopoverAnimated:YES];
        return;
    }

    QueryListViewController *popoverContent = [[QueryListViewController alloc] initWithAppViewController:self];
    popoverContent.preferredContentSize = CGSizeMake(500,700);
    UIPopoverController *myPopover = [[UIPopoverController alloc] initWithContentViewController:popoverContent];
    self.popoverController = myPopover;
    
    [self.popoverController presentPopoverFromBarButtonItem:sender
                                   permittedArrowDirections:UIPopoverArrowDirectionAny 
                                                   animated:YES];
}

- (void)popoverOptionSelected:(NSString *)text {
    [self.popoverController dismissPopoverAnimated:YES];

    SFRestRequest *request = nil;

    // collect all the textfield values
    NSString *objectType = self.tfObjectType.text;
    NSString *objectId = self.tfObjectId.text;
    NSString *fieldList = self.tfFieldList.text;
    NSDictionary *fields = [SFJsonUtils objectFromJSONString:self.tvFields.text]; 
    NSString *search = self.tfSearch.text;
    NSString *query = self.tfQuery.text;
    NSString *externalId = self.tfExternalId.text;
    NSString *externalFieldId = self.tfExternalFieldId.text;
    
    // make sure we set the value to nil if the field is empty
    if (!objectType.length)
        objectType = nil;
    if (!objectId.length)
        objectId = nil;
    if (!fieldList.length)
        fieldList = nil;
    if (!fields.count)
        fields = nil;
    if (!search.length)
        search = nil;
    if (!query.length)
        query = nil;
    if (!externalId.length)
        externalId = nil;
    if (!externalFieldId.length)
        externalFieldId = nil;
    
    
    if ([text isEqualToString:kActionVersions]) {
        request = [[SFRestAPI sharedInstance] requestForVersions];
    }
    else if ([text isEqualToString:kActionResources]) {
        request = [[SFRestAPI sharedInstance] requestForResources];
    }
    else if ([text isEqualToString:kActionDescribeGlobal]) {
        request = [[SFRestAPI sharedInstance] requestForDescribeGlobal];
    }
    else if ([text isEqualToString:kActionObjectMetadata]) {
        if (!objectType) {
            [self showMissingFieldError:@"objectType"];
             return;
        }
        request = [[SFRestAPI sharedInstance] requestForMetadataWithObjectType:objectType];
    }
    else if ([text isEqualToString:kActionObjectDescribe]) {
        if (!objectType) {
            [self showMissingFieldError:@"objectType"];
            return;
        }
        request = [[SFRestAPI sharedInstance] requestForDescribeWithObjectType:objectType];
    }
    else if ([text isEqualToString:kActionRetrieveObject]) {
        if (!objectType || !objectId) { // fieldList is optional
            [self showMissingFieldError:@"objectType, objectId"];
            return;
        }
        request = [[SFRestAPI sharedInstance] requestForRetrieveWithObjectType:objectType objectId:objectId fieldList:fieldList];
    }
    else if ([text isEqualToString:kActionCreateObject]) {
        if (!fields) {
            [self showMissingFieldError:@"fields"];
            return;
        }
        request = [[SFRestAPI sharedInstance] requestForCreateWithObjectType:objectType fields:fields];
    }
    else if ([text isEqualToString:kActionUpsertObject]) {
        if (!objectType || !externalFieldId || !externalId || !fields) {
            [self showMissingFieldError:@"objectType, objectId, fields"];
            return;
        }
        request = [[SFRestAPI sharedInstance] requestForUpsertWithObjectType:objectType externalIdField:externalFieldId externalId:externalId fields:fields];
    }
    else if ([text isEqualToString:kActionUpdateObject]) {
        if (!objectType || !objectId || !fields) {
            [self showMissingFieldError:@"objectType, objectId, fields"];
            return;
        }
        request = [[SFRestAPI sharedInstance] requestForUpdateWithObjectType:objectType objectId:objectId fields:fields];
    }
    else if ([text isEqualToString:kActionDeleteObject]) {
        if (!objectType || !objectId) {
            [self showMissingFieldError:@"objectType, objectId"];
            return;
        }
        request = [[SFRestAPI sharedInstance] requestForDeleteWithObjectType:objectType objectId:objectId];
    }
    else if ([text isEqualToString:kActionQuery]) {
        if (!query) {
            [self showMissingFieldError:@"query"];
            return;
        }
        request = [[SFRestAPI sharedInstance] requestForQuery:query];
    }
    else if ([text isEqualToString:kActionSearch]) {
        if (!search) {
            [self showMissingFieldError:@"search"];
            return;
        }
        request = [[SFRestAPI sharedInstance] requestForSearch:search];
    }
    else if ([text isEqualToString:kActionUserInfo]) {
        SFUserAccount *currentAccount = [SFUserAccountManager sharedInstance].currentUser;
        NSString *userInfoString = [NSString stringWithFormat:@"Name: %@\nID: %@\nEmail: %@",
                                    currentAccount.fullName,
                                    currentAccount.userName,
                                    currentAccount.email];
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"User Info"
                                                            message:userInfoString
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles: nil];
        [alertView show];
    }
    else if ([text isEqualToString:kActionLogout]) {
        self.logoutActionSheet = [[UIActionSheet alloc] initWithTitle:@"Are you sure you want to log out?"
                                                              delegate:self
                                                     cancelButtonTitle:nil
                                                destructiveButtonTitle:@"Confirm Logout"
                                                     otherButtonTitles:nil];
        [self.logoutActionSheet showFromToolbar:self.toolBar];
        return;
    } else if ([text isEqualToString:kActionSwitchUser]) {
        SFDefaultUserManagementViewController *umvc = [[SFDefaultUserManagementViewController alloc] initWithCompletionBlock:^(SFUserManagementAction action) {
            [self dismissViewControllerAnimated:YES completion:NULL];
        }];
        [self presentViewController:umvc animated:YES completion:NULL];
    }
    else if ([text isEqualToString:kActionExportCredentialsForTesting]) {
        AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        [appDelegate exportTestingCredentials];        
    }
    
    //don't attempt to send a nil request
    if (nil != request) {
        self.tfPath.text = request.path;
        self.tvParams.text = [SFJsonUtils JSONRepresentation:request.queryParams];
        self.segmentMethod.selectedSegmentIndex = request.method;

        [[SFRestAPI sharedInstance] send:request delegate:self];    
    }
}

#pragma mark - Passcode handling

- (void)clearPopovers:(NSNotification *)note
{
    [self log:SFLogLevelDebug msg:@"Passcode screen loading.  Clearing popovers."];
    if (self.popoverController) {
        [self.popoverController dismissPopoverAnimated:NO];
    }
    if (self.logoutActionSheet) {
        [self.logoutActionSheet dismissWithClickedButtonIndex:-100 animated:NO];
    }
}

#pragma mark - UITextFieldDelegate

-(BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self btnGoPressed:nil];
    return NO;
}

#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if ([actionSheet isEqual:self.logoutActionSheet]) {
        self.logoutActionSheet = nil;
        if (buttonIndex == actionSheet.destructiveButtonIndex) {
            [[SFAuthenticationManager sharedManager] logout];
        }
    }
}

#pragma mark - SFRestDelegate

- (void)request:(SFRestRequest *)request didLoadResponse:(id)dataResponse {
    dispatch_async(dispatch_get_main_queue(), ^{
        _tfResult.backgroundColor = [UIColor colorWithRed:1.0 green:204/255.0 blue:102/255.0 alpha:1.0];
        _tfResponseFor.text = [self formatRequest:request];
        _tfResult.text = [dataResponse description];
    });
}

- (void)request:(SFRestRequest*)request didFailLoadWithError:(NSError*)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        _tfResult.backgroundColor = [UIColor redColor];
        _tfResponseFor.text = [self formatRequest:request];
        _tfResult.text = [error description];

    });
}

- (void)requestDidCancelLoad:(SFRestRequest *)request {
    dispatch_async(dispatch_get_main_queue(), ^{
        _tfResult.backgroundColor = [UIColor redColor];
        _tfResponseFor.text = [self formatRequest:request];
        _tfResult.text =  @"Request was cancelled";
    });
}

- (void)requestDidTimeout:(SFRestRequest *)request {
    dispatch_async(dispatch_get_main_queue(), ^{
        _tfResult.backgroundColor = [UIColor redColor];
        _tfResponseFor.text = [self formatRequest:request];
        _tfResult.text =  @"Request timedout";
    });
}

@end
