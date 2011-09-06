//
//  SalesforceOAuthTestViewController.h
//  SalesforceOAuthTest
//
//  Created by Steve Holly on 20/06/2011.
//  Copyright 2011 Salesforce.com. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SFOAuthCoordinator.h"

@interface SalesforceOAuthTestViewController : UIViewController <SFOAuthCoordinatorDelegate, UIActionSheetDelegate, UITextFieldDelegate> {
    SFOAuthCoordinator *_oauthCoordinator;
}

@property (nonatomic, retain) SFOAuthCoordinator *oauthCoordinator;
@property (nonatomic, retain) IBOutlet UITextField *fieldDomain;
@property (nonatomic, retain) IBOutlet UIButton *buttonAuthenticate;
@property (nonatomic, retain) IBOutlet UIButton *buttonClear;
@property (nonatomic, retain) IBOutlet UILabel *labelAccessToken;
@property (nonatomic, retain) IBOutlet UILabel *labelRefreshToken;
@property (nonatomic, retain) IBOutlet UILabel *labelInstanceUrl;
@property (nonatomic, retain) IBOutlet UILabel *labelIssued;
@property (nonatomic, retain) IBOutlet UILabel *labelUserId;
@property (nonatomic, retain) IBOutlet UIActivityIndicatorView *activityIndicator;

- (IBAction)authClicked:(id)sender;
- (IBAction)resetClicked:(id)sender;

@end
