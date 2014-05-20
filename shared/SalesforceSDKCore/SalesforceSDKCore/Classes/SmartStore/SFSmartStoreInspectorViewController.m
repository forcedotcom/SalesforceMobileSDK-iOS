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
static CGFloat      const kPaddingTop                    = 25.0f;
static CGFloat      const kPadding                       = 5.0f;


// Query field font
static NSString *   const kQueryFieldFontName            = @"Courier";
static CGFloat      const kQueryFieldFontSize            = 12.0f;
// Run button font
static NSString *   const kButtonFontName        = @"HelveticaNeue-Bold";
static CGFloat      const kButtonFontSize        = 16.0f;
// Result text font
static NSString *   const kResultTextFontName            = @"Courier";
static CGFloat      const kResultTextFontSize            = 12.0f;


@interface SFSmartStoreInspectorViewController ()

@property (nonatomic, strong) UITextView *queryField;
@property (nonatomic, strong) UIButton *cancelButton;
@property (nonatomic, strong) UIButton *runQueryButton;
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

#pragma mark - Run query

- (void) runQuery
{
    [self.queryField endEditing:YES];
    NSString* smartSql = self.queryField.text;
    SFSmartStore* store = [SFSmartStore sharedStoreWithName:kDefaultSmartStoreName];
    NSArray* results = [store queryWithQuerySpec:[SFQuerySpec newSmartQuerySpec:smartSql withPageSize:10] pageIndex:0];
    self.resultText.text = [SFJsonUtils JSONRepresentation:results];
}

- (void) cancelQuery
{
    [SFSmartStoreInspectorViewController dismiss];
}

#pragma mark - View lifecycle


- (void)loadView
{
    [super loadView];
    
    // Query field
    self.queryField = [[UITextView alloc] initWithFrame:CGRectZero];
    self.queryField.textColor = [UIColor blackColor];
    self.queryField.font = [UIFont fontWithName:kQueryFieldFontName size:kQueryFieldFontSize];
    self.queryField.text = @"";
    self.queryField.accessibilityLabel = @"Query";
    [self.view addSubview:self.queryField];

    // Cancel button
    self.cancelButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.cancelButton setTitle:@"Cancel" /*[SFSDKResourceUtils localizedString:@"runQueryTitle"]*/ forState:UIControlStateNormal];
    self.cancelButton.backgroundColor = [UIColor whiteColor];
    [self.cancelButton.titleLabel setTextAlignment:NSTextAlignmentCenter];
    [self.cancelButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [self.cancelButton addTarget:self action:@selector(cancelQuery) forControlEvents:UIControlEventTouchUpInside];
    self.cancelButton.accessibilityLabel = @"Cancel";
    self.cancelButton.titleLabel.font = [UIFont fontWithName:kButtonFontName size:kButtonFontSize];
    [self.view addSubview:self.cancelButton];
    
    // Run button
    self.runQueryButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.runQueryButton setTitle:@"Run Query" /*[SFSDKResourceUtils localizedString:@"runQueryTitle"]*/ forState:UIControlStateNormal];
    self.runQueryButton.backgroundColor = [UIColor whiteColor];
    [self.runQueryButton.titleLabel setTextAlignment:NSTextAlignmentCenter];
    [self.runQueryButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [self.runQueryButton addTarget:self action:@selector(runQuery) forControlEvents:UIControlEventTouchUpInside];
    self.runQueryButton.accessibilityLabel = @"Run query";
    self.runQueryButton.titleLabel.font = [UIFont fontWithName:kButtonFontName size:kButtonFontSize];
    [self.view addSubview:self.runQueryButton];

    // Query field
    self.resultText = [[UITextView alloc] initWithFrame:CGRectZero];
    self.resultText.editable = NO;
    self.resultText.textColor = [UIColor blackColor];
    self.resultText.font = [UIFont fontWithName:kResultTextFontName size:kResultTextFontSize];
    self.resultText.text = @"";
    [self.view addSubview:self.resultText];
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
    [self layoutCancelButton];
    [self layoutRunQueryButton];
    [self layoutResultText];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

- (void)layoutQueryField
{
    CGFloat w = self.view.bounds.size.width - (kPadding * 2.0);
    CGFloat h = self.view.bounds.size.height / 4 - kPadding - kPaddingTop;
    CGFloat x = kPadding;
    CGFloat y = kPaddingTop;
    self.queryField.frame = CGRectMake(x, y, w, h);
}

- (void)layoutCancelButton
{
    CGFloat w = self.view.bounds.size.width / 2 - (kPadding * 1.5);
    CGFloat h = self.view.bounds.size.height / 8 - (kPadding * 2.0);
    CGFloat x = kPadding;
    CGFloat y = self.queryField.frame.origin.y + self.queryField.frame.size.height + kPadding;
    self.cancelButton.frame = CGRectMake(x, y, w, h);

}

- (void)layoutRunQueryButton
{
    CGFloat w = self.view.bounds.size.width / 2 - (kPadding * 1.5);
    CGFloat h = self.view.bounds.size.height / 8 - (kPadding * 2.0);
    CGFloat x = self.view.bounds.size.width / 2 + kPadding / 2;
    CGFloat y = self.queryField.frame.origin.y + self.queryField.frame.size.height + kPadding;
    self.runQueryButton.frame = CGRectMake(x, y, w, h);
    
}


- (void) layoutResultText
{
    CGFloat w = self.view.bounds.size.width - (kPadding * 2.0);
    CGFloat h = self.view.bounds.size.height - (self.runQueryButton.frame.origin.y + self.runQueryButton.frame.size.height) - (kPadding * 2.0);
    CGFloat x = kPadding;
    CGFloat y = self.view.bounds.size.height - h -kPadding;
    self.resultText.frame = CGRectMake(x, y, w, h);
}

@end
