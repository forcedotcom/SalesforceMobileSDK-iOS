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

#import "SFOAuthCoordinator.h"
#import "SFOAuthCredentials.h"
#import "SalesforceOAuthTestAppDelegate.h"
#import "SalesforceOAuthTestViewController.h"

@interface SalesforceOAuthTestViewController ()
- (void)enableButtons:(BOOL)enable;
- (void)updateLabels;
- (void)authCompleted;
@end

@implementation SalesforceOAuthTestViewController

@synthesize oauthCoordinator   = _oauthCoordinator;
@synthesize fieldDomain        = _fieldDomain;
@synthesize buttonAuthenticate = _buttonAuthenticate;
@synthesize buttonClear        = _buttonClear;
@synthesize labelAccessToken   = _labelAccessToken;
@synthesize labelRefreshToken  = _labelRefreshToken;
@synthesize labelInstanceUrl   = _labelInstanceUrl;
@synthesize labelIssued        = _labelIssued;
@synthesize labelUserId        = _labelUserId;
@synthesize labelOrgId         = _labelOrgId;
@synthesize activityIndicator  = _activityIndicator;


- (id)initWithNibName:(NSString *)nibName bundle:(NSBundle *)nibBundle {
    if ((self = [super initWithNibName:nibName bundle:nibBundle])) {
        SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] initWithIdentifier:kIdentifier clientId:kOAuthClientId];
        _oauthCoordinator = [[SFOAuthCoordinator alloc] initWithCredentials:creds];
        _oauthCoordinator.delegate = self;
        [creds release];
    }
    return self;
}

- (void)dealloc {
    [_oauthCoordinator release];
    [_fieldDomain release];
    [_buttonAuthenticate release];
    [_buttonClear release];
    [_labelAccessToken release];
    [_labelRefreshToken release];
    [_labelInstanceUrl release];
    [_labelIssued release];
    [_labelUserId release];
    [_labelOrgId release];
    [_activityIndicator release];
    
    [super dealloc];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.fieldDomain.delegate = self;
    [self updateLabels];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
    } else {
        return YES;
    }
}

#pragma mark - UI

- (void)enableButtons:(BOOL)enable {
    self.buttonAuthenticate.enabled = enable;
    self.buttonClear.enabled = enable;
}

- (void)updateLabels {
    if (self.oauthCoordinator) {
        self.labelAccessToken.text = self.oauthCoordinator.credentials.accessToken;
        self.labelRefreshToken.text = self.oauthCoordinator.credentials.refreshToken;
        self.labelInstanceUrl.text = [self.oauthCoordinator.credentials.instanceUrl description];
        self.labelIssued.text = [self.oauthCoordinator.credentials.issuedAt descriptionWithLocale:[NSLocale currentLocale]];
        self.labelUserId.text = self.oauthCoordinator.credentials.userId;
        self.labelOrgId.text = self.oauthCoordinator.credentials.organizationId;
    }
}

- (IBAction)authClicked:(id)sender {
    SFOAuthCredentials *creds = self.oauthCoordinator.credentials;
    creds.domain = self.fieldDomain.text;
    
    [self enableButtons:NO];
    self.activityIndicator.hidden = NO;
    [self.activityIndicator startAnimating];
    
    [_oauthCoordinator authenticate];
}

- (void)authCompleted {
    [self.activityIndicator stopAnimating];
    [self updateLabels];
    [self.oauthCoordinator.view removeFromSuperview];
    [self enableButtons:YES];
}

- (IBAction)resetClicked:(id)sender {
    
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:nil
                                                       delegate:self
                                              cancelButtonTitle:@"Clear Access Token"
                                         destructiveButtonTitle:@"Clear All Tokens"
                                              otherButtonTitles:nil];
    
    [sheet showInView:self.view];
    [sheet release];
}

#pragma mark - SFOAuthCoordinatorDelegate

- (void)oauthCoordinator:(SFOAuthCoordinator *)manager willBeginAuthenticationWithView:(UIWebView *)webView {
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)manager didBeginAuthenticationWithView:(UIWebView *)webView {
    [self.activityIndicator stopAnimating];
    [self.view addSubview:webView];
}

- (void)oauthCoordinatorDidAuthenticate:(SFOAuthCoordinator *)coordinator {
    NSLog(@"SalesforceOAuthTestViewController:oauthCoordinatorDidAuthenticate: %@", coordinator.credentials);
    
    [self authCompleted];
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didFailWithError:(NSError *)error {
    NSLog(@"SalesforceOAuthTestViewController:oauthCoordinator:didFailWithError: %@", error);
    
    [self authCompleted];
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:[NSString stringWithFormat:@"Error %d", error.code]
                                                      message:error.localizedDescription
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
    
    [alert show];
    [alert release];
}

#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (0 == buttonIndex) {
        // reset access and refresh tokens
        [self.oauthCoordinator.credentials revoke];
    } else if (1 == buttonIndex) {
        // reset access token only
        [self.oauthCoordinator.credentials revokeAccessToken];
    } else {
        // invalid index
        NSLog(@"SalesforceOAuthTestViewController:actionSheet:clickedButtonAtIndex: invalid button index: %d", buttonIndex);
    }
    [self updateLabels];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

@end
