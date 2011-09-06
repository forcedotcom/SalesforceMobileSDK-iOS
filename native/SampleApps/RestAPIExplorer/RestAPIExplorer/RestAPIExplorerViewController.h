//
//  RestAPIExplorerViewController.h
//  RestAPIExplorer
//
//  Created by Didier Prophete on 7/14/11.
//  Copyright 2011 Salesforce.com. All rights reserved.
//

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
