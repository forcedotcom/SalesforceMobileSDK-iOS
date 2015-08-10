//
//  SFCoverView.h
//  SalesforceCommonUtils
//
//  Created by Qingqing Liu on 5/8/12.
//  Copyright (c) 2012 salesforce.com. All rights reserved.
//

#import <UIKit/UIKit.h>

@class SFCoverView;

/**SFCoverViewDelegate defines delegate which will be called back when coverview is touched by user */
@protocol SFCoverViewDelegate <NSObject>

@required
- (void)coverViewClicked:(SFCoverView *)coverView;
@end

/**  A helper view designed to be used to cover existing UI with this cover view which will prevent user interactction. When user touches any ara on the cover view, `  coverViewClicked` will be invoked on delegate
 */
@interface SFCoverView : UIView 

/**Create a new cover view with specified frame, background and alpha

 If calling `initFrame` directly without passing background and alpha, default background will be set to dark gray and alpha will be set to 0.9
 
 @param frame Frame of the view
 @param backgroundColor Background color for the cover view. 
 @param alpha Alpha for the cover view.  */
- (id)initWithFrame:(CGRect)frame backgroundColor:(UIColor *)backgroundColor alpha:(CGFloat)alpha;

/**Assign delegate to this cover view. 
 
 When user touches any place on the cover view, `coverViewClicked` will be invoked on delegate
 
@param delegate Delegate for this cover view. 
 */
@property (nonatomic, weak) id <SFCoverViewDelegate> delegate;
@end
