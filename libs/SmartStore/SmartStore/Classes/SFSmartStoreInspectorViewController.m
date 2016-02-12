/*
 Copyright (c) 2014, salesforce.com, inc. All rights reserved.
 
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
#import <SalesforceSDKCore/SFSDKResourceUtils.h>
#import <SalesforceSDKCore/SFRootViewManager.h>
#import "SFQuerySpec.h"
#import <SalesforceSDKCore/SFJsonUtils.h>

// Nav bar
static CGFloat      const kNavBarHeight          = 44.0;
// Text fields
static NSString *   const kTextFieldFontName     = @"Courier";
static CGFloat      const kTextFieldFontSize     = 12.0;
static CGFloat      const kTextFieldBorderWidth  = 3.0;
static CGFloat      const kQueryFieldHeight      = 96.0;
static CGFloat      const kPageFieldHeight       = 24.0;
// Buttons
static NSString *   const kButtonFontName        = @"HelveticaNeue-Bold";
static CGFloat      const kButtonFontSize        = 16.0;
static CGFloat      const kButtonHeight          = 48.0;
static CGFloat      const kButtonBorderWidth     = 3.0;
// Results
static CGFloat      const kResultGridBorderWidth = 3.0;
static NSString *   const kResultTextFontName    = @"Courier";
static CGFloat      const kResultTextFontSize    = 12.0;
static CGFloat      const kResultCellHeight      = 24.0;
static CGFloat      const kResultCellBorderWidth = 1.0;
static NSString *   const kCellIndentifier       = @"cellIdentifier";
static NSUInteger   const kLabelTag              = 99;
// Resource keys
static NSString * const kInspectorNoRowsReturnedKey = @"inspectorNoRowsReturned";
static NSString * const kInspectorQueryFailedKey = @"inspectorQueryFailed";
static NSString * const kInspectorOKKey = @"inspectorOK";
static NSString * const kInspectorPageSizeHintKey = @"inspectorPageSizeHint";
static NSString * const kInspectorPageIndexHintKey = @"inspectorPageIndexHint";
static NSString * const kInspectorClearButtonTitleKey = @"inspectorClearButtonTitle";
static NSString * const kInspectorSoupsButtonTitleKey = @"inspectorSoupsButtonTitle";
static NSString * const kInspectorIndicesButtonTitleKey = @"inspectorIndicesButtonTitle";
static NSString * const kInspectorTitleKey = @"inspectorTitle";
static NSString * const kInspectorBackButtonTitleKey = @"inspectorBackButtonTitle";
static NSString * const kInspectorRunButtonTitleKey = @"inspectorRunButtonTitle";


@interface SFSmartStoreInspectorViewController () <UINavigationBarDelegate>

@property (nonatomic, strong) SFSmartStore *store;
@property (nonatomic, strong) UINavigationBar *navBar;
@property (nonatomic, strong) UITextView *queryField;
@property (nonatomic, strong) UITextField *pageSizeField;
@property (nonatomic, strong) UITextField *pageIndexField;
@property (nonatomic, strong) UIButton *clearButton;
@property (nonatomic, strong) UIButton *soupsButton;
@property (nonatomic, strong) UIButton *indicesButton;
@property (nonatomic, strong) UICollectionView *resultGrid;
@property (nonatomic, strong) NSArray *results;
@property (readonly, atomic, assign) NSUInteger countColumns;
@property (readonly, atomic, assign) NSUInteger countRows;

@end

@implementation SFSmartStoreInspectorViewController

#pragma mark - Constructor

- (instancetype) initWithStore:(SFSmartStore*)store
{
    self = [super init];
    if (self) {
        self.store = store;
    }
    return self;
}

#pragma mark - Present / dimiss

- (void) present:(UIViewController*)currentViewController
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self present:currentViewController];
        });
        return;
    }

    [currentViewController presentViewController:self animated:NO completion:nil];
}

- (void) dismiss
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self dismiss];
        });
        return;
    }

    [self.presentingViewController dismissViewControllerAnimated:NO completion:nil];
}

#pragma mark - Results setter

-(void) setResults:(NSArray *)results
{
    if (_results != results) {
        _results = results;
        _countRows = _results ? [_results count] : 0;
        _countColumns = _countRows > 0 ? [_results[0] count] : 0;
        dispatch_async(dispatch_get_main_queue(), ^
                       {
                           [self.resultGrid reloadData];
                       });
    }
}

#pragma mark - Actions handlers

- (void) backButtonClicked
{
    [self dismiss];
}


- (void) runQuery
{
    [self stopEditing];
    NSString* smartSql = self.queryField.text;
    NSInteger pageSize = [self.pageSizeField.text integerValue];
    pageSize = (pageSize <= 0 && ![self.pageSizeField.text isEqualToString:@"0"] ? 10 : pageSize);
    NSInteger pageIndex = [self.pageIndexField.text integerValue];
    NSError* error = nil;
    NSArray* results = [self.store queryWithQuerySpec:[SFQuerySpec newSmartQuerySpec:smartSql withPageSize:pageSize] pageIndex:pageIndex error:&error];
    NSString* errorAlertTitle = [SFSDKResourceUtils localizedString:kInspectorQueryFailedKey];
    if (error) {
        [self showAlert:[error localizedDescription] title:errorAlertTitle];
    }
    else if ([results count] == 0) {
        [self showAlert:[SFSDKResourceUtils localizedString:kInspectorNoRowsReturnedKey] title:errorAlertTitle];
    }
    self.results = results;
}

- (void) showAlert:(NSString*)message title:(NSString*)title
{
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    
    UIAlertAction *okAction = [UIAlertAction
                               actionWithTitle:[SFSDKResourceUtils localizedString:kInspectorOKKey]
                               style:UIAlertActionStyleDefault
                               handler:nil];
    
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void) soupsButtonClicked
{
    NSArray* names = [self.store allSoupNames];
    if ([names count] > 10) {
        self.queryField.text = @"SELECT soupName from soup_nameSFs";
    } else {
        NSMutableString* q = [NSMutableString string];
        BOOL first = YES;
        for (NSString* name in names) {
            if (!first)
                [q appendString:@" union "];
            [q appendFormat:@"SELECT '%@', count(*) FROM {%@}", name, name];
            first = false;
        }
        self.queryField.text = q;
    }
    [self runQuery];
}

- (void) indicesButtonClicked
{
    self.queryField.text = @"select soupName, path, columnType from soup_index_map";
    [self runQuery];
}

- (void) clearButtonClicked
{
    [self stopEditing];
    self.queryField.text = @"";
    self.pageSizeField.text = @"";
    self.pageIndexField.text = @"";
    self.results = nil;
}

- (void) stopEditing
{
    [self.queryField endEditing:YES];
    [self.pageSizeField endEditing:YES];
    [self.pageIndexField endEditing:YES];
}


#pragma mark - View layout

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (void)loadView
{
    [super loadView];
    
    // Nav bar
    self.navBar = [self createNavBar];
    
    // Query field
    self.queryField = [self createTextView];
    
    // Page size field
    self.pageSizeField = [self createTextField];
    self.pageSizeField.placeholder = [SFSDKResourceUtils localizedString:kInspectorPageSizeHintKey];
    self.pageSizeField.keyboardType = UIKeyboardTypeNumberPad;
    
    // Page index field
    self.pageIndexField = [self createTextField];
    self.pageIndexField.placeholder = [SFSDKResourceUtils localizedString:kInspectorPageIndexHintKey];
    self.pageIndexField.keyboardType = UIKeyboardTypeNumberPad;
    
    // Buttons
    self.clearButton = [self createButtonWithLabel:[SFSDKResourceUtils localizedString:kInspectorClearButtonTitleKey] action:@selector(clearButtonClicked)];
    self.soupsButton = [self createButtonWithLabel:[SFSDKResourceUtils localizedString:kInspectorSoupsButtonTitleKey] action:@selector(soupsButtonClicked)];
    self.indicesButton = [self createButtonWithLabel:[SFSDKResourceUtils localizedString:kInspectorIndicesButtonTitleKey] action:@selector(indicesButtonClicked)];
    
    // Results grid
    self.resultGrid = [self createGridView];
}

- (UINavigationBar*) createNavBar
{
    UINavigationBar* navBar = [[UINavigationBar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, kNavBarHeight)];
    navBar.delegate = self;
    UINavigationItem *navItem = [[UINavigationItem alloc] initWithTitle:[SFSDKResourceUtils localizedString:kInspectorTitleKey]];
    UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithTitle:[SFSDKResourceUtils localizedString:kInspectorBackButtonTitleKey] style:UIBarButtonItemStylePlain target:self action:@selector(backButtonClicked)];
    UIBarButtonItem *runItem = [[UIBarButtonItem alloc] initWithTitle:[SFSDKResourceUtils localizedString:kInspectorRunButtonTitleKey] style:UIBarButtonItemStylePlain target:self action:@selector(runQuery)];
    [navItem setLeftBarButtonItem:backItem];
    [navItem setRightBarButtonItem:runItem];
    [navBar setItems:@[navItem] animated:YES];
    [self.view addSubview:navBar];
    return navBar;
}

- (UITextView *) createTextView
{
    UITextView* textView = [[UITextView alloc] initWithFrame:CGRectZero];
    textView.delegate = self;
    textView.textColor = [UIColor blackColor];
    textView.backgroundColor = [UIColor whiteColor];
    textView.font = [UIFont fontWithName:kTextFieldFontName size:kTextFieldFontSize];
    textView.text = @"";
    textView.layer.borderColor = [UIColor lightGrayColor].CGColor;
    textView.layer.borderWidth = kTextFieldBorderWidth;
    [self.view addSubview:textView];
    return textView;
}

- (UITextField *) createTextField
{
    UITextField* textField = [[UITextField alloc] initWithFrame:CGRectZero];
    textField.textColor = [UIColor blackColor];
    textField.backgroundColor = [UIColor whiteColor];
    textField.font = [UIFont fontWithName:kTextFieldFontName size:kTextFieldFontSize];
    textField.text = @"";
    textField.textAlignment = NSTextAlignmentCenter;
    textField.layer.borderColor = [UIColor lightGrayColor].CGColor;
    textField.layer.borderWidth = kTextFieldBorderWidth;
    [self.view addSubview:textField];
    return textField;
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
    button.layer.borderColor = [UIColor lightGrayColor].CGColor;
    button.layer.borderWidth = kButtonBorderWidth;
    [self.view addSubview:button];
    return button;
}

- (UICollectionView*) createGridView
{
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    UICollectionView* gridView= [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    layout.minimumInteritemSpacing = 0;
    layout.minimumLineSpacing = 0;
    layout.scrollDirection = UICollectionViewScrollDirectionVertical;
    gridView.layer.borderColor = [UIColor lightGrayColor].CGColor;
    gridView.layer.borderWidth = kResultGridBorderWidth;
    [gridView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:kCellIndentifier];
    [gridView setBackgroundColor:[UIColor whiteColor]];
    [gridView setDataSource:self];
    [gridView setDelegate:self];
    [self.view addSubview:gridView];
    return gridView;
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
    [self layoutNavBar];
    [self layoutQueryField];
    [self layoutPageFields];
    [self layoutButtons];
    [self layoutResultGrid];
    [self.resultGrid reloadData];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

- (CGFloat) belowFrame:(CGRect) frame {
    return frame.origin.y + frame.size.height;
}

- (void) layoutNavBar
{
    CGFloat x = 0;
    CGFloat y = 0;
    CGFloat w = self.view.bounds.size.width;
    CGFloat h = kNavBarHeight;
    self.navBar.frame = CGRectMake(x, y, w, h);
}

- (void)layoutQueryField
{
    CGFloat x = 0;
    CGFloat y = [self belowFrame:self.navBar.frame];
    CGFloat w = self.view.bounds.size.width;
    CGFloat h = kQueryFieldHeight;
    self.queryField.frame = CGRectMake(x, y, w, h);
}

- (void)layoutPageFields
{
    CGFloat w = self.view.bounds.size.width / 2.0;
    CGFloat y = [self belowFrame:self.queryField.frame];
    CGFloat h = kPageFieldHeight;
    self.pageSizeField.frame = CGRectMake(0, y, w, h);
    self.pageIndexField.frame = CGRectMake(w, y, w, h);
}

- (void)layoutButtons
{
    CGFloat w = self.view.bounds.size.width / 3.0;
    CGFloat y = [self belowFrame:self.pageSizeField.frame];
    CGFloat h = kButtonHeight;
    self.clearButton.frame = CGRectMake(0, y, w, h);
    self.soupsButton.frame = CGRectMake(w, y, w, h);
    self.indicesButton.frame = CGRectMake(w * 2.0, y, w, h);
}

- (void) layoutResultGrid
{
    CGFloat x = 0;
    CGFloat y = [self belowFrame:self.clearButton.frame];
    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height - y;
    self.resultGrid.frame = CGRectMake(x, y, w, h);
}

#pragma mark - Text view delegate

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    if ( [text isEqualToString:@"\n"] ) {
        [self runQuery];
    }
    
    return YES;
}

#pragma mark - Collection view delegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSString* label = [[self cellDatawithIndexPath:indexPath] description];
    [self showAlert:label title:nil];
}


- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewCell *cell=[collectionView dequeueReusableCellWithReuseIdentifier:kCellIndentifier forIndexPath:indexPath];
    UILabel* labelView = [self cellViewWithIndexPath:indexPath];
    labelView.tag = kLabelTag;
    [[cell.contentView viewWithTag:kLabelTag] removeFromSuperview];
    [cell.contentView addSubview:labelView];
    return cell;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat w = [self cellWidthWithIndexPath:indexPath];
    CGFloat h = [self cellHeightWithIndexPath:indexPath];
    return CGSizeMake(w, h);
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return self.countRows;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return self.countColumns; // * self.countRows;
}

- (NSString*) compactDescription:(id)obj
{
    NSString* str = [obj description];
    return [str stringByReplacingOccurrencesOfString:@"\\s+" withString:@" " options:NSRegularExpressionSearch range:NSMakeRange(0, [str length])];
}

-(UILabel *)cellViewWithIndexPath:(NSIndexPath*) indexPath
{
    CGFloat w = [self cellWidthWithIndexPath:indexPath];
    CGFloat h = [self cellHeightWithIndexPath:indexPath];
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(0,0,w,h)];
    title.textColor = [UIColor blackColor];
    title.layer.borderColor = [UIColor lightGrayColor].CGColor;
    title.layer.borderWidth = kResultCellBorderWidth;
    title.font = [UIFont fontWithName:kResultTextFontName size:kResultTextFontSize];
    title.textAlignment = NSTextAlignmentCenter;
    title.text = [self compactDescription:[self cellDatawithIndexPath:indexPath]];
    return title;
}

- (CGFloat) cellWidthWithIndexPath:(NSIndexPath*) indexPath
{
    return self.countColumns > 0 ? self.resultGrid.frame.size.width / self.countColumns : 0;
}

- (CGFloat) cellHeightWithIndexPath:(NSIndexPath*) indexPath
{
    return kResultCellHeight;
}

- (id) cellDatawithIndexPath:(NSIndexPath*) indexPath
{
    return ((NSArray*) self.results[indexPath.section])[indexPath.row];
}

@end

