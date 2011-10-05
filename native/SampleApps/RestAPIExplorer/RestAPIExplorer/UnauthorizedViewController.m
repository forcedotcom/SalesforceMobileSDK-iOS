//
//  UnauthorizedViewController.m
//  RestAPIExplorer
//
//  Created by Todd Stellanova on 10/5/11.
//  Copyright 2011 Salesforce.com. All rights reserved.
//

#import "UnauthorizedViewController.h"

@implementation UnauthorizedViewController

@synthesize oauthView = _oauthView;


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}


- (void)dealloc {
    self.oauthView = nil;
    [super dealloc];
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
	return YES;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation 
{
    
}

#pragma mark - Properties

- (void)setOauthView:(UIView *)oauthView {
    if (![oauthView isEqual:_oauthView]) {
        [_oauthView removeFromSuperview];
        [_oauthView release];
        _oauthView = [oauthView retain];
        
        if (nil != _oauthView) {
            [_oauthView setAutoresizingMask:UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth];
            [_oauthView setFrame:self.view.bounds];
            [self.view addSubview:_oauthView];
        }
    }
}
@end
