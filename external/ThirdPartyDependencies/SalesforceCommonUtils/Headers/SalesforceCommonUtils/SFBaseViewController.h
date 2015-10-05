//
//  SFBaseViewController.h
//  SalesforceCommonUtils
//
//  Created by João Neves on 4/24/15.
//  Copyright (c) 2015 Salesforce.com. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef struct {
    BOOL loading; //is in loading state
    BOOL empty; //is in empty state
} SFViewState;

@interface SFBaseViewController : UIViewController

@property (nonatomic, assign, readonly) SFViewState viewState;


#pragma mark - ViewState methods

- (void)updateViewState;
- (BOOL)isInLoadingState; //no need to call super
- (BOOL)isInEmptyState; //no need to call super
- (void)updateViewStateLoading:(BOOL)showLoading;
- (void)updateViewStateEmpty:(BOOL)showEmpty;
- (void)viewStateUpdated;

@end
