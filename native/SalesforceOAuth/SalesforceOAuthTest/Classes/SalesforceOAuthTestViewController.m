//
//  SalesforceOAuthTestViewController.h
//  SalesforceOAuthTest
//
//  Created by Steve Holly on 20/06/2011.
//  Copyright 2011 Salesforce.com. All rights reserved.
//

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
@synthesize activityIndicator  = _activityIndicator;


- (id)initWithNibName:(NSString *)nibName bundle:(NSBundle *)nibBundle {
    if ((self = [super initWithNibName:nibName bundle:nibBundle])) {
        SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] initWithIdentifier:kOAuthClientId];
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
