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

#import "RestAPIExplorerViewController.h"
#import "QueryListViewController.h"
#import "AppDelegate.h"
#import <SalesforceSDKCore/SFJsonUtils.h>
#import <SalesforceSDKCore/SFRestAPI.h>
#import <SalesforceSDKCore/SFRestAPI+Files.h>
#import <SalesforceSDKCore/SFRestRequest.h>
#import <SalesforceSDKCore/SFSecurityLockout.h>
#import <SalesforceSDKCore/SFAuthenticationManager.h>
#import <SalesforceSDKCore/SFDefaultUserManagementViewController.h>
#import <SalesforceSDKCore/SFIdentityData.h>
#import <SalesforceSDKCore/SFApplicationHelper.h>

@interface RestAPIExplorerViewController()

@property (nonatomic, strong) UIAlertController *logoutActionSheet;
@property (nonatomic, assign) BOOL popOverDisplayed;
- (NSString *)formatRequest:(SFRestRequest *)request;
- (void)hideKeyboard;
- (void)clearPopovers:(NSNotification *)note;

@end

@implementation RestAPIExplorerViewController

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
    self.tfUserId.text = [SFUserAccountManager sharedInstance].currentUser.idData.userId;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(clearPopovers:)
                                                 name:kSFPasscodeFlowWillBegin
                                               object:nil];
}


- (void)viewDidUnload
{
    // action based query
    self.popOverController = nil;
    self.toolBar = nil;
    self.logoutActionSheet = nil;
    self.tfObjectType = nil;
    self.tfObjectId = nil;
    self.tfExternalId = nil;
    self.tfSearch = nil;
    self.tfQuery = nil;
    self.tfExternalFieldId = nil;
    self.tfFieldList = nil;
    self.tfObjectList = nil;
    self.tvFields = nil;
    self.tfUserId = nil;
    self.tfPage = nil;
    self.tfVersion = nil;
    self.tfObjectIdList = nil;
    self.tfEntityId = nil;
    self.tfShareType = nil;
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
    [self.tfPath resignFirstResponder];
    [self.tfResult resignFirstResponder];
    [self.tfResponseFor resignFirstResponder];
    [self.tvParams resignFirstResponder];
    [self.segmentMethod resignFirstResponder];
    [self.tfObjectType resignFirstResponder];
    [self.tfObjectId resignFirstResponder];
    [self.tfExternalId resignFirstResponder];
    [self.tfSearch resignFirstResponder];
    [self.tfQuery resignFirstResponder];
    [self.tfExternalFieldId resignFirstResponder];
    [self.tfFieldList resignFirstResponder];
    [self.tfObjectList resignFirstResponder];
    [self.tvFields resignFirstResponder];
    [self.tfUserId resignFirstResponder];
    [self.tfPage resignFirstResponder];
    [self.tfVersion resignFirstResponder];
    [self.tfObjectIdList resignFirstResponder];
    [self.tfEntityId resignFirstResponder];
    [self.tfShareType resignFirstResponder];
}

- (void)showMissingFieldError:(NSString *)missingFields {
    [self showAlert:@"Missing Field" withMessage:[NSString stringWithFormat:@"You need to fill out the following field(s): %@", missingFields]];
}

#pragma mark - actions

- (IBAction)btnGoPressed:(id)sender {
    [self hideKeyboard];
    NSString *params = self.tvParams.text;

    NSDictionary *queryParams = ([params length] == 0
                                 ? nil
                                 : (NSDictionary *)[SFJsonUtils objectFromJSONString:params]
                                 );
                                 
    SFRestMethod method = (SFRestMethod)self.segmentMethod.selectedSegmentIndex;
    NSString *path = self.tfPath.text;
    SFRestRequest *request = [SFRestRequest requestWithMethod:method path:path queryParams:queryParams];

    [[SFRestAPI sharedInstance] send:request delegate:self];
}

- (IBAction)btnActionPressed:(id)sender {
    [self hideKeyboard];

    if(self.popOverDisplayed){
        self.popOverDisplayed = NO;
        [self dismissViewControllerAnimated:YES completion:nil];
        return;
    }

    QueryListViewController *popoverContent = [[QueryListViewController alloc] initWithAppViewController:self];
    popoverContent.preferredContentSize = CGSizeMake(500,700);
    popoverContent.modalPresentationStyle = UIModalPresentationPopover;
    [self presentViewController:popoverContent animated:YES completion:nil];
    UIPopoverPresentationController  *myPopover = [popoverContent popoverPresentationController];
    myPopover.permittedArrowDirections = UIPopoverArrowDirectionUp;
    myPopover.barButtonItem = (UIBarButtonItem *) sender;
    self.popOverDisplayed = YES;
}


- (void)popoverOptionSelected:(NSString *)text {
    [self dismissPopoverController];

    SFRestRequest *request = nil;

    // collect all the textfield values
    NSString *objectType = self.tfObjectType.text;
    NSString *objectId = self.tfObjectId.text;
    NSString *fieldList = self.tfFieldList.text;
    NSString *objectList = self.tfObjectList.text;
    NSDictionary *fields = [SFJsonUtils objectFromJSONString:self.tvFields.text];
    NSString *search = self.tfSearch.text;
    NSString *query = self.tfQuery.text;
    NSString *externalId = self.tfExternalId.text;
    NSString *externalFieldId = self.tfExternalFieldId.text;
    NSString *userId = self.tfUserId.text;
    NSUInteger page = [self.tfPage.text integerValue];
    NSString *version = self.tfVersion.text;
    NSArray *objectIdList = [self.tfObjectIdList.text componentsSeparatedByString:@","];
    NSString *entityId = self.tfEntityId.text;
    NSString *shareType = self.tfShareType.text;
    
    // make sure we set the value to nil if the field is empty
    if (!objectType.length)
        objectType = nil;
    if (!objectId.length)
        objectId = nil;
    if (!fieldList.length)
        fieldList = nil;
    if (!objectList.length)
        objectList = nil;
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
    if (!userId.length)
        userId = nil;
    if (!version.length)
        version = nil;
    if (objectIdList.count == 0)
        objectIdList = nil;
    if (!entityId.length)
        entityId = nil;
    if (!shareType.length)
        shareType = nil;
    
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
    else if ([text isEqualToString:kActionSearchScopeAndOrder]) {
        request = [[SFRestAPI sharedInstance] requestForSearchScopeAndOrder];
    }
    else if ([text isEqualToString:kActionSearchResultLayout]) {
        if (!objectList) {
            [self showMissingFieldError:@"objectList"];
            return;
        }
        request = [[SFRestAPI sharedInstance] requestForSearchResultLayout:objectList];
    }
    else if ([text isEqualToString:kActionOwnedFilesList]) {
        if (!userId) {
            [self showMissingFieldError:@"userId"];
            return;
        }
        request = [[SFRestAPI sharedInstance] requestForOwnedFilesList:userId page:page];
    }
    else if ([text isEqualToString:kActionFilesInUsersGroups]) {
        if (!userId) {
            [self showMissingFieldError:@"userId"];
            return;
        }
        request = [[SFRestAPI sharedInstance] requestForFilesInUsersGroups:userId page:page];
    }
    else if ([text isEqualToString:kActionFilesSharedWithUser]) {
        if (!userId) {
            [self showMissingFieldError:@"userId"];
            return;
        }
        request = [[SFRestAPI sharedInstance] requestForFilesSharedWithUser:userId page:page];
    }
    else if ([text isEqualToString:kActionFileDetails]) {
        if (!objectId || !version) {
            [self showMissingFieldError:@"objectId, version"];
            return;
        }
        request = [[SFRestAPI sharedInstance] requestForFileDetails:objectId forVersion:version];
    }
    else if ([text isEqualToString:kActionBatchFileDetails]) {
        if (!objectIdList) {
            [self showMissingFieldError:@"objectIdList"];
            return;
        }
        request = [[SFRestAPI sharedInstance] requestForBatchFileDetails:objectIdList];
    }
    else if ([text isEqualToString:kActionFileShares]) {
        if (!objectId) {
            [self showMissingFieldError:@"objectId"];
            return;
        }
        request = [[SFRestAPI sharedInstance] requestForFileShares:objectId page:page];
    }
    else if ([text isEqualToString:kActionAddFileShare]) {
        if (!objectId || !entityId || !shareType) {
            [self showMissingFieldError:@"objectId, entityId, shareType"];
            return;
        }
        request = [[SFRestAPI sharedInstance] requestForAddFileShare:objectId entityId:entityId shareType:shareType];
    }
    else if ([text isEqualToString:kActionDeleteFileShare]) {
        if (!objectId) {
            [self showMissingFieldError:@"objectId"];
            return;
        }
        request = [[SFRestAPI sharedInstance] requestForDeleteFileShare:objectId];
    }
    else if ([text isEqualToString:kActionUserInfo]) {
        SFUserAccount *currentAccount = [SFUserAccountManager sharedInstance].currentUser;
        NSString *userInfoString = [NSString stringWithFormat:@"Name: %@\nID: %@\nEmail: %@",
                                    currentAccount.fullName,
                                    currentAccount.userName,
                                    currentAccount.email];

        [self showAlert:@"User Info" withMessage:userInfoString];
        
    }
    else if ([text isEqualToString:kActionLogout]) {
        [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
        [self createLogoutActionSheet];
        return;
    } else if ([text isEqualToString:kActionSwitchUser]) {
        SFDefaultUserManagementViewController *umvc = [[SFDefaultUserManagementViewController alloc] initWithCompletionBlock:^(SFUserManagementAction action) {
            [self dismissViewControllerAnimated:YES completion:NULL];
        }];
        [self presentViewController:umvc animated:YES completion:NULL];
    }
    else if ([text isEqualToString:kActionExportCredentialsForTesting]) {
        AppDelegate *appDelegate = (AppDelegate *)[[SFApplicationHelper sharedApplication] delegate];
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

#pragma mark - private methods

-(void) dismissPopoverController {
    if(self.popOverDisplayed){
        self.popOverDisplayed = NO;
        [self dismissViewControllerAnimated:YES completion:nil];
        return;
    }
}

- (void)createLogoutActionSheet
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:Nil
                                                                   message:@"Are you sure you want to log out?"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *logoutAction = [UIAlertAction actionWithTitle:@"Confirm Logout"
                                                          style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                              self.logoutActionSheet = nil;
                                                              [[SFAuthenticationManager sharedManager] logout];
                                                          }];
    [alert addAction:logoutAction];
    self.logoutActionSheet = alert;
    [self presentViewController:alert animated:YES completion:nil];
}

- (void) showAlert:(NSString *)title withMessage:(NSString *) message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Ok"
                                                           style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
            }];
    [alert addAction:cancelAction];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Passcode handling

- (void)clearPopovers:(NSNotification *)note
{
    [SFSDKLogger log:[self class] level:DDLogLevelDebug format:@"Passcode screen loading. Clearing popovers."];
    if (self.popOverController) {
        [self dismissPopoverController];
    }
    if (self.logoutActionSheet) {
        [self.logoutActionSheet dismissViewControllerAnimated:YES completion:Nil];
    }
}

#pragma mark - UITextFieldDelegate

-(BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self btnGoPressed:nil];
    return NO;
}

#pragma mark - SFRestDelegate

- (void)request:(SFRestRequest *)request didLoadResponse:(id)dataResponse {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.tfResult.backgroundColor = [UIColor colorWithRed:1.0 green:204/255.0 blue:102/255.0 alpha:1.0];
        self.tfResponseFor.text = [self formatRequest:request];
        self.tfResult.text = [dataResponse description];
    });
}

- (void)request:(SFRestRequest*)request didFailLoadWithError:(NSError*)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.tfResult.backgroundColor = [UIColor redColor];
        self.tfResponseFor.text = [self formatRequest:request];
        self.tfResult.text = [error description];

    });
}

- (void)requestDidCancelLoad:(SFRestRequest *)request {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.tfResult.backgroundColor = [UIColor redColor];
        self.tfResponseFor.text = [self formatRequest:request];
        self.tfResult.text =  @"Request was cancelled";
    });
}

- (void)requestDidTimeout:(SFRestRequest *)request {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.tfResult.backgroundColor = [UIColor redColor];
        self.tfResponseFor.text = [self formatRequest:request];
        self.tfResult.text =  @"Request timedout";
    });
}

@end
