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

@interface ContactDetailViewController ()

@property (nonatomic, strong) ContactSObjectData *contact;
@property (nonatomic, strong) NSArray *dataRows;

@end

@implementation ContactDetailViewController

- (id)initWithContact:(ContactSObjectData *)contact {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.contact = contact;
        self.dataRows = [self dataRowsFromContact];
    }
    return self;
}

- (void)loadView {
    [super loadView];
    
    self.navigationController.navigationBar.tintColor = [UIColor whiteColor];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
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
    
    NSString *rowValueData = self.dataRows[indexPath.section][1];
    cell.textLabel.text = rowValueData;
    
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.dataRows[section][0];
}

#pragma mark - Private methods

- (NSArray *)dataRowsFromContact {

    NSArray *dataRowsArray = @[ @[ @"First name", [[self class] emptyStringForNil:self.contact.firstName] ],
                                @[ @"Last name", [[self class] emptyStringForNil:self.contact.lastName] ],
                                @[ @"Title", [[self class] emptyStringForNil:self.contact.title] ],
                                @[ @"Mobile phone", [[self class] emptyStringForNil:self.contact.mobilePhone] ],
                                @[ @"Email address", [[self class] emptyStringForNil:self.contact.email] ],
                                @[ @"Department", [[self class] emptyStringForNil:self.contact.department] ],
                                @[ @"Home phone", [[self class] emptyStringForNil:self.contact.homePhone] ]
                                ];
    return dataRowsArray;
}

+ (NSString *)emptyStringForNil:(NSString *)origValue {
    if (origValue == nil) {
        return @"";
    } else {
        return origValue;
    }
}

@end
