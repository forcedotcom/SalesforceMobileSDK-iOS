/*
 Copyright (c) 2012, salesforce.com, inc. All rights reserved.
 
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

#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <UIKit/UITextInputTraits.h>

#import "SFSmartStoreInspectorViewController.h"
#import "SFSDKResourceUtils.h"
#import "SFRootViewManager.h"
#import "SFSmartStore.h"
#import "SFQuerySpec.h"
#import "SFJsonUtils.h"

// Padding
static CGFloat      const kNavBarHeight          = 44.0f;
static CGFloat      const kPadding               = 5.0f;


// Query field font
static NSString *   const kQueryFieldFontName    = @"Courier";
static CGFloat      const kQueryFieldFontSize    = 12.0f;
// Run button font
static NSString *   const kButtonFontName        = @"HelveticaNeue-Bold";
static CGFloat      const kButtonFontSize        = 16.0f;
// Result text font
static NSString *   const kResultTextFontName    = @"Courier";
static CGFloat      const kResultTextFontSize    = 12.0f;


@interface SFSmartStoreInspectorViewController ()

@property (nonatomic, strong) UINavigationBar *navBar;
@property (nonatomic, strong) UITextView *queryField;
@property (nonatomic, strong) UIButton *clearButton;
@property (nonatomic, strong) UIButton *soupsButton;
@property (nonatomic, strong) UIButton *indicesButton;
@property (nonatomic, strong) UITextView *resultText;

@end

@implementation SFSmartStoreInspectorViewController

#pragma mark - Singleton

+ (SFSmartStoreInspectorViewController *) sharedInstance
{
    static SFSmartStoreInspectorViewController *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken,
                  ^{
                      sharedInstance = [[SFSmartStoreInspectorViewController alloc] init];
                  });
    return sharedInstance;
}

#pragma mark - Present / 

+ (void) present
{
    [[SFRootViewManager sharedManager] pushViewController:[SFSmartStoreInspectorViewController sharedInstance]];
}

+ (void) dismiss
{
    [[SFRootViewManager sharedManager] popViewController:[SFSmartStoreInspectorViewController sharedInstance]];
}


- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - Actions handlers

- (void) onBack
{
    [SFSmartStoreInspectorViewController dismiss];
}


- (void) onQuery
{
    [self.queryField endEditing:YES];
    NSString* smartSql = self.queryField.text;
    SFSmartStore* store = [SFSmartStore sharedStoreWithName:kDefaultSmartStoreName];
    NSArray* results = [store queryWithQuerySpec:[SFQuerySpec newSmartQuerySpec:smartSql withPageSize:10] pageIndex:0];
    self.resultText.text = [SFJsonUtils JSONRepresentation:results];
}

- (void) onSoups
{
    self.queryField.text = @"SELECT soupName from soup_names";
    [self onQuery];
}

- (void) onIndices
{
    self.queryField.text = @"select soupName, path, columnType from soup_index_map";
    [self onQuery];
}

- (void) onClear
{
    self.queryField.text = @"";
    self.resultText.text = @"";
}


#pragma mark - View lifecycle

// TODO get strings from [SFSDKResourceUtils localizedString:@"..."]
- (void)loadView
{
    [super loadView];
    
    // Nav bar
    self.navBar = [[UINavigationBar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, kNavBarHeight)];
    self.navBar.delegate = self;
    UINavigationItem *navItem = [[UINavigationItem alloc] initWithTitle:@"Inspector"];
    UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithTitle:@"Back" style:UIBarButtonItemStylePlain target:self action:@selector(onBack)];
    UIBarButtonItem *runItem = [[UIBarButtonItem alloc] initWithTitle:@"Run" style:UIBarButtonItemStylePlain target:self action:@selector(onQuery)];
    [navItem setLeftBarButtonItem:backItem];
    [navItem setRightBarButtonItem:runItem];
    [self.navBar setItems:@[navItem] animated:YES];
    [self.view addSubview:self.navBar];
    
    // Query field
    self.queryField = [[UITextView alloc] initWithFrame:CGRectZero];
    self.queryField.textColor = [UIColor blackColor];
    self.queryField.font = [UIFont fontWithName:kQueryFieldFontName size:kQueryFieldFontSize];
    self.queryField.text = @"";
    self.queryField.accessibilityLabel = @"Query";
    [self.view addSubview:self.queryField];

    // Buttons
    self.clearButton = [self createButtonWithLabel:@"Clear" action:@selector(onClear)];
    self.soupsButton = [self createButtonWithLabel:@"Soups" action:@selector(onSoups)];
    self.indicesButton = [self createButtonWithLabel:@"Indices" action:@selector(onIndices)];

    // Results field
    self.resultText = [[UITextView alloc] initWithFrame:CGRectZero];
    self.resultText.editable = NO;
    self.resultText.textColor = [UIColor blackColor];
    self.resultText.font = [UIFont fontWithName:kResultTextFontName size:kResultTextFontSize];
    self.resultText.text = @"";
    [self.view addSubview:self.resultText];
}

- (UIButton*) createButtonWithLabel:(NSString*) label action:(SEL)action
{
    UIButton* button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setTitle:label forState:UIControlStateNormal];
    button.backgroundColor = [UIColor whiteColor];
    [button.titleLabel setTextAlignment:NSTextAlignmentCenter];
    [button setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    button.titleLabel.font = [UIFont fontWithName:kButtonFontName size:kButtonFontSize];
    [self.view addSubview:button];
    return button;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self layoutSubviews];
}

- (void)viewWillLayoutSubviews
{
    [self layoutSubviews];
    [super viewWillLayoutSubviews];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
}

- (void)layoutSubviews
{
    [self layoutQueryField];
    [self layoutButtons];
    [self layoutResultText];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

- (void)layoutQueryField
{
    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height / 4.0 - kNavBarHeight;
    CGFloat x = 0;
    CGFloat y = self.navBar.frame.size.height;
    self.queryField.frame = CGRectMake(x, y, w, h);
}

- (void)layoutButtons
{
    CGFloat w = self.view.bounds.size.width / 3.0;
    CGFloat h = self.view.bounds.size.height / 8.0 - (kPadding * 2.0);
    CGFloat y = self.queryField.frame.origin.y + self.queryField.frame.size.height + kPadding;
    self.clearButton.frame = CGRectMake(kPadding / 2.0, y, w - kPadding, h);
    self.soupsButton.frame = CGRectMake(w + kPadding / 2.0, y, w - kPadding, h);
    self.indicesButton.frame = CGRectMake(w * 2.0 + kPadding / 2.0, y, w - kPadding, h);
}

- (void) layoutResultText
{
    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height * 5.0 / 8.0;
    CGFloat x = 0;
    CGFloat y = self.view.bounds.size.height - h;
    self.resultText.frame = CGRectMake(x, y, w, h);
}


@end
