//
//  SFLoadingView.h
//  SalesforceCommonUtils
//
//  Created by Amol Prabhu on 4/14/15.
//  Copyright (c) 2015 Salesforce.com. All rights reserved.
//

#import <UIKit/UIKit.h>

@class SFLoadingView;

@protocol SFLoadingViewDelegate <NSObject>

/** Implementing class will provide the view in which the loading view will be contained.
 @param loadingView the loadingView for which a containerview is required.
 @return container view.
 */
- (UIView *)containerViewForLoadingView:(SFLoadingView *)loadingView;

@optional

/** Implementing class will provide the center position at which the loading view will be positioned in the container view.
 If this method is not implemented, default center calculation logic will be applied based on the view returned by `containerViewForLoadingView`
 @param loadingView the loadingView for which the center point is required.
 @return CGPoint the center point.
 */
- (CGPoint)centerPointForLoadingView:(SFLoadingView *)loadingView;

@end

@interface SFLoadingView : UIView

@property (nonatomic, weak) id<SFLoadingViewDelegate> delegate;

/** shows/hides the view based on the param.
 @param show boolean value indicating whether to display the loading view or not.
 */
- (void)showLoadingView:(BOOL)show;

/** shows/hides the view based on the param.
 @param show boolean value indicating whether to display the loading view or not.
 @param shouldDelay boolean value indicating whether to delay the display of the loading indicator.
 */
- (void)showLoadingView:(BOOL)show withDelay:(BOOL)shouldDelay;


@end
