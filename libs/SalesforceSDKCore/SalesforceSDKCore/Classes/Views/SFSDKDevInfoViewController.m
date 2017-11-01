/*
 Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.

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


#import "SFSDKDevInfoViewController.h"
#import "SalesforceSDKManager.h"
#import "SFSDKResourceUtils.h"

// Nav bar
static CGFloat      const kNavBarHeight          = 44.0;
// Results
static CGFloat      const kResultGridBorderWidth = 1.0;
static NSString *   const kResultTextFontName    = @"Courier";
static CGFloat      const kResultTextFontSize    = 18.0;
static CGFloat      const kResultCellHeight      = 44.0;
static CGFloat      const kResultCellBorderWidth = 1.0;
static NSString *   const kCellIndentifier       = @"cellIdentifier";
static NSUInteger   const kLabelTag              = 99;
// Resource keys
static NSString * const kDevInfoTitleKey = @"devInfoTitle";
static NSString * const kDevInfoBackButtonTitleKey = @"devInfoBackButtonTitle";
static NSString * const kDevInfoOKKey = @"devInfoOKKey";

@interface SFSDKDevInfoViewController () <UINavigationBarDelegate>

@property (nonatomic, strong) UINavigationBar *navBar;
@property (nonatomic, strong) UICollectionView *resultGrid;

@end

@implementation SFSDKDevInfoViewController

#pragma mark - Constructor

- (instancetype) init
{
    self = [super init];
    if (self) {
        self.infoRows = [self prepareListData:[[SalesforceSDKManager sharedManager] getDevSupportInfos]];
    }
    return self;
}

#pragma mark - View lifecycle

- (NSArray *)prepareListData:(NSArray *)rawData {
    NSMutableArray* listData = [NSMutableArray new];
    for (int i=0; i<rawData.count; i+=2) {
        [listData addObject:@[rawData[i],rawData[i+1]]];
    }
    return listData;
}

#pragma mark - Actions handlers

- (void) backButtonClicked
{
    [self.presentingViewController dismissViewControllerAnimated:NO completion:NULL];
}

- (void) showAlert:(NSString*)message title:(NSString*)title
{
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];


    UIAlertAction *okAction = [UIAlertAction
            actionWithTitle:[SFSDKResourceUtils localizedString:kDevInfoOKKey]
                      style:UIAlertActionStyleDefault
                    handler:nil];

    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
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

    // Table view
    self.resultGrid = [self createGridView];

}

- (UINavigationBar*) createNavBar
{
    UINavigationBar* navBar = [[UINavigationBar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, kNavBarHeight)];
    navBar.delegate = self;
    UINavigationItem *navItem = [[UINavigationItem alloc] initWithTitle:[SFSDKResourceUtils localizedString:kDevInfoTitleKey]];
    UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithTitle:[SFSDKResourceUtils localizedString:kDevInfoBackButtonTitleKey] style:UIBarButtonItemStylePlain target:self action:@selector(backButtonClicked)];
    [navItem setLeftBarButtonItem:backItem];
    [navBar setItems:@[navItem] animated:YES];
    [self.view addSubview:navBar];
    return navBar;
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

- (void)layoutSubviews
{
    [self layoutNavBar];
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

- (void) layoutResultGrid
{
    CGFloat x = 0;
    CGFloat y = [self belowFrame:self.navBar.frame];
    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height - y;
    self.resultGrid.frame = CGRectMake(x, y, w, h);
}

#pragma mark - Collection view delegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    [self showAlert:self.infoRows[indexPath.section][indexPath.item] title:nil];
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
    return self.infoRows.count;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return 2;
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
    title.textAlignment = NSTextAlignmentLeft;
    title.numberOfLines = 0;
    title.text = self.infoRows[indexPath.section][indexPath.item];
    return title;
}

- (CGFloat) cellWidthWithIndexPath:(NSIndexPath*) indexPath
{
    return self.resultGrid.frame.size.width * (indexPath.item == 0 ? 1 : 3) / 4;
}

- (CGFloat) cellHeightWithIndexPath:(NSIndexPath*) indexPath
{
    return kResultCellHeight;
}

@end
