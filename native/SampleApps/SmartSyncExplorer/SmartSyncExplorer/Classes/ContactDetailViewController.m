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

#import "ContactDetailViewController.h"
#import "ContactSObjectDataSpec.h"

@interface ContactDetailViewController ()

@property (nonatomic, strong) ContactSFObject *contact;
@property (nonatomic, strong) SObjectDataManager *dataMgr;
@property (nonatomic, copy) void (^saveBlock)(void);
@property (nonatomic, strong) NSArray *dataRows;
@property (nonatomic, assign) BOOL isEditing;
@property (nonatomic, assign) BOOL contactUpdated;

@end

@implementation ContactDetailViewController

- (id)initWithContact:(ContactSFObject *)contact dataManager:(SObjectDataManager *)dataMgr saveBlock:(void (^)(void))saveBlock {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.contact = contact;
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
    
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.dataRows[section][0];
}

#pragma mark - Private methods

- (void)configureInitialBarButtonItems {
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(editContact)];
    self.navigationItem.leftBarButtonItem = nil;
}

- (NSArray *)dataRowsFromContact {
    
    NSArray *dataRowsArray = @[ @[ @"First name",
                                   kContactFirstNameField,
                                   [[self class] emptyStringForNil:self.contact.firstName],
                                   [self contactTextField:self.contact.firstName] ],
                                @[ @"Last name",
                                   kContactLastNameField,
                                   [[self class] emptyStringForNil:self.contact.lastName],
                                   [self contactTextField:self.contact.lastName] ],
                                @[ @"Title",
                                   kContactTitleField,
                                   [[self class] emptyStringForNil:self.contact.title],
                                   [self contactTextField:self.contact.title] ],
                                @[ @"Mobile phone",
                                   kContactMobilePhoneField,
                                   [[self class] emptyStringForNil:self.contact.mobilePhone],
                                   [self contactTextField:self.contact.mobilePhone] ],
                                @[ @"Email address",
                                   kContactEmailField,
                                   [[self class] emptyStringForNil:self.contact.email],
                                   [self contactTextField:self.contact.email] ],
                                @[ @"Department",
                                   kContactDepartmentField,
                                   [[self class] emptyStringForNil:self.contact.department],
                                   [self contactTextField:self.contact.department] ],
                                @[ @"Home phone",
                                   kContactHomePhoneField,
                                   [[self class] emptyStringForNil:self.contact.homePhone],
                                   [self contactTextField:self.contact.homePhone] ]
                                ];
    return dataRowsArray;
}

- (void)editContact {
    self.isEditing = YES;
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelEditContact)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(saveContact)];
    [self.tableView reloadData];
    __weak ContactDetailViewController *weakSelf = self;
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
    for (NSArray *fieldArray in self.dataRows) {
        NSString *fieldName = fieldArray[1];
        NSString *origFieldData = fieldArray[2];
        NSString *newFieldData = ((UITextField *)fieldArray[3]).text;
        if (![newFieldData isEqualToString:origFieldData]) {
            [self.contact updateSoupForFieldName:fieldName fieldValue:newFieldData];
            self.contactUpdated = YES;
        }
    }
    
    if (self.contactUpdated) {
        [self.dataMgr updateLocalData:self.contact];
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        [self.tableView reloadData];
    }
    
}

- (UITextField *)contactTextField:(NSString *)propertyValue {
    UITextField *textField = [[UITextField alloc] initWithFrame:CGRectZero];
    textField.text = propertyValue;
    return textField;
}

- (void)contactTextFieldAddLeftMargin:(UITextField *)textField {
    UIView *leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, textField.frame.size.height)];
    leftView.backgroundColor = textField.backgroundColor;
    textField.leftView = leftView;
    textField.leftViewMode = UITextFieldViewModeAlways;
}

+ (NSString *)emptyStringForNil:(NSString *)origValue {
    if (origValue == nil) {
        return @"";
    } else {
        return origValue;
    }
}

@end
