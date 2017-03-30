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

#import "ContactDetailViewController.h"
#import <SmartSyncExplorerCommon/ContactSObjectDataSpec.h>

@interface ContactDetailViewController ()

@property (nonatomic, strong) ContactSObjectData *contact;
@property (nonatomic, strong) SObjectDataManager *dataMgr;
@property (nonatomic, copy) void (^saveBlock)(void);
@property (nonatomic, strong) NSArray *dataRows;
@property (nonatomic, strong) NSArray *contactDataRows;
@property (nonatomic, strong) NSArray *deleteButtonDataRow;
@property (nonatomic, assign) BOOL isEditing;
@property (nonatomic, assign) BOOL contactUpdated;
@property (nonatomic, assign) BOOL isNewContact;

@end

@implementation ContactDetailViewController

- (id)initForNewContactWithDataManager:(SObjectDataManager *)dataMgr saveBlock:(void (^)(void))saveBlock {
    return [self initWithContact:nil dataManager:dataMgr saveBlock:saveBlock];
}

- (id)initWithContact:(ContactSObjectData *)contact dataManager:(SObjectDataManager *)dataMgr saveBlock:(void (^)(void))saveBlock {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        if (contact == nil) {
            self.isNewContact = YES;
            self.contact = [[ContactSObjectData alloc] init];
        } else {
            self.isNewContact = NO;
            self.contact = contact;
        }
        self.dataMgr = dataMgr;
        self.saveBlock = saveBlock;
        self.isEditing = NO;
    }
    return self;
}

- (void)loadView {
    [super loadView];
    
    self.dataRows = [self dataRowsFromContact];
    self.navigationController.navigationBar.tintColor = [UIColor whiteColor];
    [self configureInitialBarButtonItems];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    if (self.isNewContact) {
        [self editContact];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    if (self.contactUpdated && self.saveBlock != NULL) {
        dispatch_async(dispatch_get_main_queue(), self.saveBlock);
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - UITableView delegate methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [self.dataRows count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView_ cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"ContactDetailCellIdentifier";
    
    UITableViewCell *cell = [tableView_ dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
    
    if (indexPath.section < [self.contactDataRows count]) {
        if (self.isEditing) {
            cell.textLabel.text = nil;
            UITextField *editField = self.dataRows[indexPath.section][3];
            editField.frame = cell.contentView.bounds;
            [self contactTextFieldAddLeftMargin:editField];
            [cell.contentView addSubview:editField];
        } else {
            UITextField *editField = self.dataRows[indexPath.section][3];
            [editField removeFromSuperview];
            NSString *rowValueData = self.dataRows[indexPath.section][2];
            cell.textLabel.text = rowValueData;
        }
    } else {
        UIButton *deleteButton = self.dataRows[indexPath.section][1];
        deleteButton.frame = cell.contentView.bounds;
        [cell.contentView addSubview:deleteButton];
    }
    
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.dataRows[section][0];
}

#pragma mark - Private methods
- (void)configureInitialBarButtonItems {
    if (self.isNewContact) {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(saveContact)];
    } else {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(editContact)];
    }
    self.navigationItem.leftBarButtonItem = nil;
}

- (NSArray *)dataRowsFromContact {
    
    self.contactDataRows = @[ @[ @"First name",
                                 kContactFirstNameField,
                                 [[self class] emptyStringForNullValue:self.contact.firstName],
                                 [self contactTextField:self.contact.firstName] ],
                              @[ @"Last name",
                                 kContactLastNameField,
                                 [[self class] emptyStringForNullValue:self.contact.lastName],
                                 [self contactTextField:self.contact.lastName] ],
                              @[ @"Title",
                                 kContactTitleField,
                                 [[self class] emptyStringForNullValue:self.contact.title],
                                 [self contactTextField:self.contact.title] ],
                              @[ @"Mobile phone",
                                 kContactMobilePhoneField,
                                 [[self class] emptyStringForNullValue:self.contact.mobilePhone],
                                 [self contactTextField:self.contact.mobilePhone] ],
                              @[ @"Email address",
                                 kContactEmailField,
                                 [[self class] emptyStringForNullValue:self.contact.email],
                                 [self contactTextField:self.contact.email] ],
                              @[ @"Department",
                                 kContactDepartmentField,
                                 [[self class] emptyStringForNullValue:self.contact.department],
                                 [self contactTextField:self.contact.department] ],
                              @[ @"Home phone",
                                 kContactHomePhoneField,
                                 [[self class] emptyStringForNullValue:self.contact.homePhone],
                                 [self contactTextField:self.contact.homePhone] ]
                              ];
    self.deleteButtonDataRow = @[ @"", [self deleteButtonView] ];
    
    NSMutableArray *workingDataRows = [NSMutableArray array];
    [workingDataRows addObjectsFromArray:self.contactDataRows];
    if (!self.isNewContact) {
        [workingDataRows addObject:self.deleteButtonDataRow];
    }
    return workingDataRows;
}

- (void)editContact {
    self.isEditing = YES;
    if (!self.isNewContact) {
        // Buttons will already be set for new contact case.
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelEditContact)];
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(saveContact)];
    }
    [self.tableView reloadData];
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [weakSelf.dataRows[0][3] becomeFirstResponder];
    });
}

- (void)cancelEditContact {
    self.isEditing = NO;
    [self configureInitialBarButtonItems];
    [self.tableView reloadData];
}

- (void)saveContact {
    [self configureInitialBarButtonItems];
    
    self.contactUpdated = NO;
    for (NSArray *fieldArray in self.contactDataRows) {
        NSString *fieldName = fieldArray[1];
        NSString *origFieldData = fieldArray[2];
        NSString *newFieldData = ((UITextField *)fieldArray[3]).text;
        if (![newFieldData isEqualToString:origFieldData]) {
            [self.contact updateSoupForFieldName:fieldName fieldValue:newFieldData];
            self.contactUpdated = YES;
        }
    }
    
    if (self.contactUpdated) {
        if (self.isNewContact) {
            [self.dataMgr createLocalData:self.contact];
        } else {
            [self.dataMgr updateLocalData:self.contact];
        }
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        [self.tableView reloadData];
    }
    
}

- (void)deleteContactConfirm {
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Confirm Delete"
                                                                   message:@"Are you sure you want to delete this contact?"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                           style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                               [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
                                                           }];
    
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK"
                                                           style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                               [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
                                                                [self deleteContact];
                                                           }];
    [alert addAction:cancelAction];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];

    
}

- (void)deleteContact {
    [self.dataMgr deleteLocalData:self.contact];
    self.contactUpdated = YES;
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)undeleteContact {
    [self.dataMgr undeleteLocalData:self.contact];
    self.contactUpdated = YES;
    [self.navigationController popViewControllerAnimated:YES];
}

- (UITextField *)contactTextField:(NSString *)propertyValue {
    UITextField *textField = [[UITextField alloc] initWithFrame:CGRectZero];
    textField.text = propertyValue;
    return textField;
}

- (UIButton *)deleteButtonView {
    BOOL deleted = ([[self.contact fieldValueForFieldName:kSyncTargetLocallyDeleted] boolValue]);
    UIButton *deleteButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [deleteButton setTitle:(deleted ? @"Undelete Contact" : @"Delete Contact") forState:UIControlStateNormal];
    [deleteButton setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    deleteButton.titleLabel.font = [UIFont systemFontOfSize:18.0];
    deleteButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    deleteButton.contentEdgeInsets = UIEdgeInsetsMake(0, 15, 0, 0);
    [deleteButton addTarget:self action:(deleted ? @selector(undeleteContact) : @selector(deleteContactConfirm)) forControlEvents:UIControlEventTouchUpInside];
    return deleteButton;
}

- (void)contactTextFieldAddLeftMargin:(UITextField *)textField {
    UIView *leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, textField.frame.size.height)];
    leftView.backgroundColor = textField.backgroundColor;
    textField.leftView = leftView;
    textField.leftViewMode = UITextFieldViewModeAlways;
}

+ (NSString *)emptyStringForNullValue:(id)origValue {
    if (origValue == nil || origValue == [NSNull null]) {
        return @"";
    } else {
        return origValue;
    }
}

@end
