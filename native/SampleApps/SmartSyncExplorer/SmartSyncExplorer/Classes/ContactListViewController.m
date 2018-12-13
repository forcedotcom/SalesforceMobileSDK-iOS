/*
 Copyright (c) 2014-present, salesforce.com, inc. All rights reserved.

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

#import "ContactListViewController.h"
#import "ActionsPopupController.h"
#import "ContactDetailViewController.h"
#import "WYPopoverController.h"
#import <SalesforceSDKCore/SFDefaultUserManagementViewController.h>
#import <SalesforceSDKCore/SFUserAccountManager.h>
#import <SalesforceSDKCore/SFSecurityLockout.h>
#import <SalesforceSDKCore/SalesforceSDKManager.h>
#import <SmartStore/SFSmartStoreInspectorViewController.h>

static NSString * const kNavBarTitleText                = @"Contacts";
static NSUInteger const kNavBarTintColor                = 0xf10000;
static CGFloat    const kNavBarTitleFontSize            = 27.0;
static NSUInteger const kSearchHeaderBackgroundColor    = 0xafb6bb;
static NSUInteger const kContactTitleTextColor          = 0x696969;
static CGFloat    const kContactTitleFontSize           = 15.0;
static CGFloat    const kContactDetailFontSize          = 13.0;
static CGFloat    const kControlBuffer                  = 5.0;
static CGFloat    const kSearchHeaderHeight             = 50.0;
static CGFloat    const kTableViewRowHeight             = 60.0;
static CGFloat    const kInitialsCircleDiameter         = 50.0;
static CGFloat    const kInitialsFontSize               = 19.0;
static CGFloat    const kToastMessageFontSize           = 16.0;

static NSUInteger const kColorCodesList[] = { 0x1abc9c,  0x2ecc71,  0x3498db,  0x9b59b6,  0x34495e,  0x16a085,  0x27ae60,  0x2980b9,  0x8e44ad,  0x2c3e50,  0xf1c40f,  0xe67e22,  0xe74c3c,  0x95a5a6,  0xf39c12,  0xd35400,  0xc0392b,  0xbdc3c7,  0x7f8c8d };


@interface ContactListViewController () <UISearchBarDelegate>

@property (nonatomic, strong) WYPopoverController *popOverController;
@property (nonatomic, strong) UIAlertController *logoutActionSheet;


// View / UI properties
@property (nonatomic, strong) UILabel *navBarLabel;
@property (nonatomic, strong) UIView *searchHeader;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UIBarButtonItem *syncButton;
@property (nonatomic, strong) UIBarButtonItem *addButton;
@property (nonatomic, strong) UIBarButtonItem *moreButton;
@property (nonatomic, strong) UIView *toastView;
@property (nonatomic, strong) UILabel *toastViewMessageLabel;
@property (nonatomic, copy) NSString *toastMessage;

// Data properties
@property (nonatomic, strong) SObjectDataManager *dataMgr;
@property (nonatomic, assign) BOOL isSearching;
@property (nonatomic, strong) NSString* searchText;

@end

@implementation ContactListViewController

#pragma mark - init/setup

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.dataMgr = [[SObjectDataManager alloc] initWithDataSpec:[ContactSObjectData dataSpec]];
        self.isSearching = NO;
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    if (!self.dataMgr) {
        self.dataMgr = [[SObjectDataManager alloc] initWithDataSpec:[ContactSObjectData dataSpec]];
    }

    __weak typeof(self) weakSelf = self;
    void (^completionBlock)(void) = ^{
        [weakSelf refreshList];
    };

    [self.dataMgr refreshLocalData:completionBlock];
    if ([self.dataMgr.dataRows count] == 0) {
        [self.dataMgr refreshRemoteData:completionBlock];
    }

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(clearPopovers:)
                                                 name:kSFPasscodeFlowWillBegin
                                               object:nil];
}

- (void)loadView {
    [super loadView];

    self.navigationController.navigationBar.barTintColor = [[self class] colorFromRgbHexValue:kNavBarTintColor];

    [self addTapGestureRecognizers];

    // Nav bar label
    self.navBarLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.navBarLabel.text = kNavBarTitleText;
    self.navBarLabel.textAlignment = NSTextAlignmentLeft;
    self.navBarLabel.textColor = [UIColor whiteColor];
    self.navBarLabel.backgroundColor = [UIColor clearColor];
    self.navBarLabel.font = [UIFont systemFontOfSize:kNavBarTitleFontSize];
    self.navigationItem.titleView = self.navBarLabel;

    // Navigation bar buttons
    self.addButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"add"] style:UIBarButtonItemStylePlain target:self action:@selector(addContact)];
    self.syncButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"sync"] style:UIBarButtonItemStylePlain target:self action:@selector(syncUpDown)];
    self.moreButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(showOtherActions)];
    self.navigationItem.rightBarButtonItems = @[ self.moreButton, self.syncButton, self.addButton ];
    for (UIBarButtonItem *bbi in self.navigationItem.rightBarButtonItems) {
        bbi.tintColor = [UIColor whiteColor];
    }

    // Search header
    self.searchHeader = [[UIView alloc] initWithFrame:CGRectZero];
    self.searchHeader.backgroundColor = [[self class] colorFromRgbHexValue:kSearchHeaderBackgroundColor];

    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectZero];
    self.searchBar.barTintColor = [[self class] colorFromRgbHexValue:kSearchHeaderBackgroundColor];
    self.searchBar.placeholder = @"Search";
    self.searchBar.delegate = self;
    [self.searchHeader addSubview:self.searchBar];

    // Toast view
    self.toastView = [[UIView alloc] initWithFrame:CGRectZero];
    self.toastView.backgroundColor = [UIColor colorWithRed:(38.0 / 255.0) green:(38.0 / 255.0) blue:(38.0 / 255.0) alpha:0.7];
    self.toastView.layer.cornerRadius = 10.0;
    self.toastView.alpha = 0.0;

    self.toastViewMessageLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.toastViewMessageLabel.font = [UIFont systemFontOfSize:kToastMessageFontSize];
    self.toastViewMessageLabel.textColor = [UIColor whiteColor];
    [self.toastView addSubview:self.toastViewMessageLabel];
    [self.view addSubview:self.toastView];
}

- (void)viewWillLayoutSubviews {
    CGRect navBarFrame = self.navigationController.navigationBar.frame;
    UIImage *rightButtonImage = self.navigationItem.rightBarButtonItem.image;
    CGRect navBarLabelFrame = CGRectMake(0,
                                         0,
                                         navBarFrame.size.width - rightButtonImage.size.width,
                                         navBarFrame.size.height);
    self.navBarLabel.frame = navBarLabelFrame;
    [self layoutSearchHeader];

    [self layoutToastView];
}

- (void)viewWillAppear:(BOOL)animated {

    [super viewWillAppear:animated];

}

- (void)viewDidAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - UITableView delegate methods

- (UITableViewCell *)tableView:(UITableView *)tableView_ cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"ContactListCellIdentifier";

    UITableViewCell *cell = [tableView_ dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }

    ContactSObjectData *obj = [self.dataMgr.dataRows objectAtIndex:indexPath.row];
    cell.textLabel.text = [self formatNameFromContact:obj];
    cell.textLabel.font = [UIFont systemFontOfSize:kContactTitleFontSize];
    cell.detailTextLabel.text = [self formatTitle:obj.title];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:kContactDetailFontSize];
    cell.detailTextLabel.textColor = [[self class] colorFromRgbHexValue:kContactTitleTextColor];
    cell.imageView.image = [self initialsBackgroundImageWithColor:[self colorFromContact:obj] initials:[self formatInitialsFromContact:obj]];

    cell.accessoryView = [self accessoryViewForContact:obj];

    return cell;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.dataMgr.dataRows count];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (section != 0) return nil;

    [self layoutSearchHeader];

    return self.searchHeader;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (section == 0)
        return kSearchHeaderHeight;
    else
        return 0;
}

- (void)tableView:(UITableView *)theTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    ContactSObjectData *contact = [self.dataMgr.dataRows objectAtIndex:indexPath.row];
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:kNavBarTitleText style:UIBarButtonItemStylePlain target:nil action:nil];
    ContactDetailViewController *detailVc = [[ContactDetailViewController alloc] initWithContact:contact
                                                                                     dataManager:self.dataMgr
                                                                                       saveBlock:^{
                                                                                           [self.tableView beginUpdates];
                                                                                           [self.tableView reloadRowsAtIndexPaths:@[ indexPath ] withRowAnimation:UITableViewRowAnimationNone];
                                                                                           [self.tableView endUpdates];
                                                                                       }];
    [self.navigationController pushViewController:detailVc animated:YES];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return kTableViewRowHeight;
}

#pragma mark - UISearchBarDelegate methods

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    [SFSDKLogger log:[self class] level:DDLogLevelDebug format:@"searching with text: %@", searchText];
    self.searchText = searchText;
    [self refreshList];
}

- (void) refreshList {
    __weak typeof(self) weakSelf = self;
    [self.dataMgr filterOnSearchTerm:self.searchText completion:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf.tableView reloadData];
        if (strongSelf.isSearching && ![strongSelf.searchBar isFirstResponder]) {
            [strongSelf.searchBar becomeFirstResponder];
        }
    }];
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
    self.isSearching = YES;
}

#pragma mark - Private methods

- (UIView *)accessoryViewForContact:(ContactSObjectData *)contact {
    static UIImage *sLocalAddImage = nil;
    static UIImage *sLocalUpdateImage = nil;
    static UIImage *sLocalDeleteImage = nil;
    static UIImage *sChevronRightImage = nil;

    if (sLocalAddImage == nil) {
        sLocalAddImage = [UIImage imageNamed:@"local-add"];
    }
    if (sLocalUpdateImage == nil) {
        sLocalUpdateImage = [UIImage imageNamed:@"local-update"];
    }
    if (sLocalDeleteImage == nil) {
        sLocalDeleteImage = [UIImage imageNamed:@"local-delete"];
    }
    if (sChevronRightImage == nil) {
        sChevronRightImage = [UIImage imageNamed:@"chevron-right"];
    }

    if ([self.dataMgr dataHasLocalChanges:contact]) {
        UIImage *localImage;
        // If deleted and created or updated, we should show deleted
        if ([self.dataMgr dataLocallyDeleted:contact])
            localImage = sLocalDeleteImage;
        // If created and updated, we should show created
        else if ([self.dataMgr dataLocallyCreated:contact])
            localImage = sLocalAddImage;
        // If updated (but not deleted or created), we should show updated
        else
            localImage = sLocalUpdateImage;

        //
        // Uber view
        //
        CGFloat accessoryViewWidth = localImage.size.width + kControlBuffer + sChevronRightImage.size.width;
        CGRect accessoryViewRect = CGRectMake(0, 0, accessoryViewWidth, self.tableView.rowHeight);
        UIView *accessoryView = [[UIView alloc] initWithFrame:accessoryViewRect];
        //
        // "local" view
        //
        CGRect localImageViewRect = CGRectMake(0,
                                               CGRectGetMidY(accessoryView.bounds) - (localImage.size.height / 2.0),
                                               localImage.size.width,
                                               localImage.size.height);
        UIImageView *localImageView = [[UIImageView alloc] initWithFrame:localImageViewRect];
        localImageView.image = localImage;
        [accessoryView addSubview:localImageView];
        //
        // spacer view
        //
        UIView *spacerView = [[UIView alloc] initWithFrame:CGRectMake(localImageView.frame.size.width, 0, kControlBuffer, self.tableView.rowHeight)];
        [accessoryView addSubview:spacerView];
        //
        // chevron view
        //
        CGRect chevronViewRect = CGRectMake(localImageView.frame.size.width + spacerView.frame.size.width,
                                            CGRectGetMidY(accessoryView.bounds) - (sChevronRightImage.size.height / 2.0),
                                            sChevronRightImage.size.width,
                                            sChevronRightImage.size.height);
        UIImageView *chevronView = [[UIImageView alloc] initWithFrame:chevronViewRect];
        chevronView.image = sChevronRightImage;
        [accessoryView addSubview:chevronView];

        return accessoryView;
    } else {
        //
        // Uber view
        //
        CGRect accessoryViewRect = CGRectMake(0, 0, sChevronRightImage.size.width, self.tableView.rowHeight);
        UIView *accessoryView = [[UIView alloc] initWithFrame:accessoryViewRect];
        //
        // chevron view
        //
        CGRect chevronViewRect = CGRectMake(0,
                                            CGRectGetMidY(accessoryView.bounds) - (sChevronRightImage.size.height / 2.0),
                                            sChevronRightImage.size.width,
                                            sChevronRightImage.size.height);
        UIImageView *chevronView = [[UIImageView alloc] initWithFrame:chevronViewRect];
        chevronView.image = sChevronRightImage;
        [accessoryView addSubview:chevronView];

        return accessoryView;
    }
}

- (void)addTapGestureRecognizers {
    UITapGestureRecognizer* navBarTapGesture = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(searchResignFirstResponder)];
    navBarTapGesture.cancelsTouchesInView = NO;
    [self.navigationController.navigationBar addGestureRecognizer:navBarTapGesture];

    UITapGestureRecognizer* tableViewTapGesture = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(searchResignFirstResponder)];
    tableViewTapGesture.cancelsTouchesInView = NO;
    [self.tableView addGestureRecognizer:tableViewTapGesture];
}

- (void)syncUpDown {
    self.navigationItem.rightBarButtonItem.enabled = NO;
    [self showToast:@"Syncing with Salesforce"];
    __weak typeof(self) weakSelf = self;
    void(^completionBlock)(void) = ^{
        [weakSelf refreshList];
    };

    [self.dataMgr updateRemoteData:^(SFSyncState *syncProgressDetails) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            strongSelf.navigationItem.rightBarButtonItem.enabled = YES;
            // NB: when the sync failed it means not everything could be synched up
            //     it doesn't mean nothing could be synched up
            // Therefore we should be refreshing whether it was a complete success or not
            [strongSelf.dataMgr refreshLocalData:completionBlock];
            [strongSelf.dataMgr refreshRemoteData:completionBlock]; // NB will again call refreshLocalData when completing

            // Letting the user know whether it was a complete success or not
            if ([syncProgressDetails isDone]) {
                [strongSelf showToast:@"Sync complete!"];
            } else if ([syncProgressDetails hasFailed]) {
                [strongSelf showToast:@"Sync failed."];
            }
        });
    }];
}

- (void)addContact {
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:kNavBarTitleText style:UIBarButtonItemStylePlain target:nil action:nil];
    ContactDetailViewController *detailVc = [[ContactDetailViewController alloc] initForNewContactWithDataManager:self.dataMgr saveBlock:^{
        [self.dataMgr refreshLocalData:^{
            [self refreshList];
        }];
    }];
    [self.navigationController pushViewController:detailVc animated:YES];
}

- (void)showOtherActions {
    if([self.popOverController isPopoverVisible]){
        [self.popOverController dismissPopoverAnimated:YES];
        return;
    }

    ActionsPopupController *popoverContent = [[ActionsPopupController alloc] initWithAppViewController:self];
    popoverContent.preferredContentSize = CGSizeMake(260,180);
    self.popOverController = [[WYPopoverController alloc] initWithContentViewController:popoverContent];


    [self.popOverController presentPopoverFromBarButtonItem:self.moreButton
                                   permittedArrowDirections:WYPopoverArrowDirectionAny
                                                   animated:YES];
}

- (void)popoverOptionSelected:(NSString *)text {
    [self.popOverController dismissPopoverAnimated:YES];

    if ([text isEqualToString:kActionLogout]) {
        [self showLogoutActionSheet];
        return;
    } else if ([text isEqualToString:kActionSwitchUser]) {
        SFDefaultUserManagementViewController *umvc = [[SFDefaultUserManagementViewController alloc] initWithCompletionBlock:^(SFUserManagementAction action) {
            [self dismissViewControllerAnimated:YES completion:NULL];
        }];
        [self presentViewController:umvc animated:YES completion:NULL];
    } else if ([text isEqualToString:kActionDbInspector]) {
        SFSmartStoreInspectorViewController *inspector = [[SFSmartStoreInspectorViewController alloc] initWithStore:self.dataMgr.store];
        [self presentViewController:inspector animated:NO completion:nil];
    }
}

- (void)showLogoutActionSheet
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:Nil
                                                                   message:@"Are you sure you want to log out?"
                                                          preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *logoutAction = [UIAlertAction actionWithTitle:@"Logout"
                                                           style:UIAlertActionStyleDestructive
                                                         handler:^(UIAlertAction * action) {
                                                            self.logoutActionSheet = nil;
                                                            [[SFUserAccountManager sharedInstance] logout];
                                                        }];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction * action) {
                                                         }];
    [alert addAction:logoutAction];
    [alert addAction:cancelAction];
    self.logoutActionSheet = alert;
    [self presentViewController:alert animated:YES completion:nil];
}


- (void)layoutToastView {
    CGFloat toastWidth = 250.0;
    CGFloat toastHeight = 50.0;
    CGFloat bottomScreenPadding = 40.0;

    self.toastView.frame = CGRectMake(CGRectGetMidX([self.toastView superview].bounds) - (toastWidth / 2.0),
                                      CGRectGetMaxY([self.toastView superview].bounds) - bottomScreenPadding - toastHeight,
                                      toastWidth,
                                      toastHeight);

    //
    // messageLabel
    //
    NSDictionary *messageAttrs = @{ NSForegroundColorAttributeName: self.toastViewMessageLabel.textColor, NSFontAttributeName: self.toastViewMessageLabel.font };
    if (self.toastMessage == nil) {
        self.toastMessage = @" ";
    }
    CGSize messageTextSize = [self.toastMessage sizeWithAttributes:messageAttrs];
    CGRect messageRect = CGRectMake(CGRectGetMidX(self.toastView.bounds) - (messageTextSize.width / 2.0),
                                    CGRectGetMidY(self.toastView.bounds) - (messageTextSize.height / 2.0),
                                    messageTextSize.width, messageTextSize.height);
    self.toastViewMessageLabel.frame = messageRect;
    self.toastViewMessageLabel.text = self.toastMessage;
}

- (void)showToast:(NSString *)message {
    NSTimeInterval const toastDisplayTimeSecs = 2.0;

    self.toastMessage = message;
    [self layoutToastView];
    self.toastView.alpha = 0.0;
    [UIView beginAnimations:@"toastFadeIn" context:NULL];
    [UIView setAnimationDuration:0.3];
    self.toastView.alpha = 1.0;
    [UIView commitAnimations];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, toastDisplayTimeSecs * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [UIView beginAnimations:@"toastFadeOut" context:NULL];
        [UIView setAnimationDuration:0.3];
        self.toastView.alpha = 0.0;
        [UIView commitAnimations];
    });
}

- (void)searchResignFirstResponder {
    if ([self.searchBar isFirstResponder]) {
        [self.searchBar resignFirstResponder];
        self.isSearching = NO;
    }
}

- (void)layoutSearchHeader {

    //
    // searchHeader
    //
    CGRect searchHeaderFrame = CGRectMake(0, 0, self.navigationController.navigationBar.frame.size.width, kSearchHeaderHeight);
    self.searchHeader.frame = searchHeaderFrame;

    //
    // searchBar
    //
    CGRect searchBarFrame = CGRectMake(0,
                                       0,
                                       self.searchHeader.frame.size.width,
                                       self.searchHeader.frame.size.height);
    self.searchBar.frame = searchBarFrame;
}

- (NSString *)formatNameFromContact:(ContactSObjectData *)contact {
    NSString *firstName = [contact.firstName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *lastName = [contact.lastName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (firstName == nil && lastName == nil) {
        return @"";
    } else if (firstName == nil && lastName != nil) {
        return lastName;
    } else if (firstName != nil && lastName == nil) {
        return firstName;
    } else {
        return [NSString stringWithFormat:@"%@ %@", firstName, lastName];
    }
}

- (NSString *)formatInitialsFromContact:(ContactSObjectData *)contact {
    NSString *firstName = [contact.firstName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *lastName = [contact.lastName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    NSMutableString *initialsString = [NSMutableString stringWithString:@""];
    if ([firstName length] > 0) {
        unichar firstChar = [firstName characterAtIndex:0];
        NSString *firstCharString = [NSString stringWithCharacters:&firstChar length:1];
        [initialsString appendFormat:@"%@", firstCharString];
    }
    if ([lastName length] > 0) {
        unichar firstChar = [lastName characterAtIndex:0];
        NSString *firstCharString = [NSString stringWithCharacters:&firstChar length:1];
        [initialsString appendFormat:@"%@", firstCharString];
    }

    return initialsString;
}

- (NSString *)formatTitle:(NSString *)title {
    title = [title stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return (title != nil ? title : @"");
}

- (UIColor *)colorFromContact:(ContactSObjectData *)contact {

    NSString *lastName = [contact.lastName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSUInteger codeSeedFromName = 0;
    for (NSUInteger i = 0; i < [lastName length]; i++) {
        codeSeedFromName += [lastName characterAtIndex:i];
    }

    static NSUInteger colorCodesListCount = sizeof(kColorCodesList) / sizeof(NSUInteger);
    NSUInteger colorCodesListIndex = codeSeedFromName % colorCodesListCount;
    NSUInteger colorCodeHexValue = kColorCodesList[colorCodesListIndex];
    return [[self class] colorFromRgbHexValue:colorCodeHexValue];
}

+ (UIColor *)colorFromRgbHexValue:(NSUInteger)rgbHexColorValue {
    return [UIColor colorWithRed:((CGFloat)((rgbHexColorValue & 0xFF0000) >> 16)) / 255.0
                           green:((CGFloat)((rgbHexColorValue & 0xFF00) >> 8)) / 255.0
                            blue:((CGFloat)(rgbHexColorValue & 0xFF)) / 255.0
                           alpha:1.0];
}

- (UIImage *)initialsBackgroundImageWithColor:(UIColor *)circleColor initials:(NSString *)initials {

    UIGraphicsBeginImageContextWithOptions(CGSizeMake(kInitialsCircleDiameter, kInitialsCircleDiameter), NO, [UIScreen mainScreen].scale);

    // Draw the circle.
    CGContextRef context = UIGraphicsGetCurrentContext();
    UIGraphicsPushContext(context);
    CGPoint circleCenter = CGPointMake(kInitialsCircleDiameter / 2.0, kInitialsCircleDiameter / 2.0);
    CGContextSetFillColorWithColor(context, [circleColor CGColor]);
    CGContextBeginPath(context);
    CGContextAddArc(context, circleCenter.x, circleCenter.y, kInitialsCircleDiameter / 2.0, 0, 2*M_PI, 0);
    CGContextFillPath(context);

    // Draw the initials.
    NSDictionary *initialsAttrs = @{ NSForegroundColorAttributeName: [UIColor whiteColor], NSFontAttributeName: [UIFont systemFontOfSize:kInitialsFontSize] };
    CGSize initialsTextSize = [initials sizeWithAttributes:initialsAttrs];
    CGRect initialsRect = CGRectMake(circleCenter.x - (initialsTextSize.width / 2.0), circleCenter.y - (initialsTextSize.height / 2.0), initialsTextSize.width, initialsTextSize.height);
    [initials drawInRect:initialsRect withAttributes:initialsAttrs];

    UIGraphicsPopContext();

    UIImage *imageFromGraphicsContext = UIGraphicsGetImageFromCurrentImageContext();

    UIGraphicsEndImageContext();

    return imageFromGraphicsContext;
}

#pragma mark - Passcode handling

- (void)clearPopovers:(NSNotification *)note
{
    [SFSDKLogger log:[self class] level:DDLogLevelDebug format:@"Passcode screen loading. Clearing popovers."];
    if (self.popOverController) {
        [self.popOverController dismissPopoverAnimated:NO];
    }
    if (self.logoutActionSheet) {
        [self.logoutActionSheet dismissViewControllerAnimated:YES completion:nil];
    }
}

@end
