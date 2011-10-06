/*
 Copyright (c) 2011, salesforce.com, inc. All rights reserved.
 
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


#import <UIKit/UIKit.h>
#import "SFRestAPI.h"
#import "RestAPIExplorerAppDelegate.h"

@interface RestAPIExplorerViewController : UIViewController <SFRestDelegate, UITextFieldDelegate> {
    // action based query
    UIPopoverController *__popoverController;
    UITextField *_tfObjectType;
    UITextField *_tfObjectId;
    UITextField *_tfExternalId;
    UITextField *_tfSearch;
    UITextField *_tfQuery;
    UITextField *_tfExternalFieldId;
    UITextField *_tfFieldList;
    UITextView *_tvFields;
    
    // manual query
    UITextField *_tfPath;
    UITextView *_tvParams;
    UISegmentedControl *_segmentMethod;

    // response
    UILabel *_tfResponseFor;
    UITextView *_tfResult;
}

- (void)popoverOptionSelected:(NSString *)text;

- (IBAction)btnGoPressed:(id)sender;
- (IBAction)btnActionPressed:(id)sender;

// action based query
@property (nonatomic, retain) UIPopoverController *popoverController;
@property (nonatomic, retain) IBOutlet UITextField *tfObjectType;
@property (nonatomic, retain) IBOutlet UITextField *tfObjectId;
@property (nonatomic, retain) IBOutlet UITextField *tfExternalId;
@property (nonatomic, retain) IBOutlet UITextField *tfSearch;
@property (nonatomic, retain) IBOutlet UITextField *tfQuery;
@property (nonatomic, retain) IBOutlet UITextField *tfExternalFieldId;
@property (nonatomic, retain) IBOutlet UITextField *tfFieldList;
@property (nonatomic, retain) IBOutlet UITextView *tvFields;

// manual query
@property (nonatomic, retain) IBOutlet UITextField *tfPath;
@property (nonatomic, retain) IBOutlet UITextView *tvParams;
@property (nonatomic, retain) IBOutlet UISegmentedControl *segmentMethod;

// response
@property (nonatomic, retain) IBOutlet UILabel *tfResponseFor;
@property (nonatomic, retain) IBOutlet UITextView *tfResult;

@end
