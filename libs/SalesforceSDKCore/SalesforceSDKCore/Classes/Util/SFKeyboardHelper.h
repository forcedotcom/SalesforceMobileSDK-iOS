//
//  SFKeyboardHelper.h
//
//  Created by Qingqing Liu, 05/09/2014.
//  Copyright (c) 2013 Salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#if !TARGET_OS_TV
#import <SalesforceSDKCore/SalesforceSDKCore.h>
#endif

#pragma clang diagnostic ignored "-Wunused-function" // ignore unused function warning

static CGFloat SFPhoneKeyboardHeight(CGRect keyboardFrame) {
    

    CGFloat height = CGRectGetHeight(keyboardFrame);
    if (height == 0) {
#if TARGET_OS_TV
        height = 162.0; // Landscape keyboard size
#else
        if (UIInterfaceOrientationIsPortrait([SFApplicationHelper sharedApplication].statusBarOrientation)) {
            height = 216.0; // Portrait keyboard size
        } else {
            height = 162.0; // Landscape keyboard size
        }
#endif
    }
    return height;
}
#pragma clang diagnostic warning "-Wunused-function" // stop ignoring the unused function

/** The various type of changes this helper handles
 */
typedef enum {
    SFKeyboardHelperChangeWillShow,
    SFKeyboardHelperChangeDidShow,
    SFKeyboardHelperChangeWillHide,
    SFKeyboardHelperChangeDidHide,
    SFKeyboardHelperChangeFrameChanged
} SFKeyboardHelperChange;

@class SFKeyboardHelper;

/** The delegate of the helper
 */
@protocol SFKeyboardHelperDelegate <NSObject>

/** This method is invoked when the keyboard changes
 @param helper The helper
 @param change The type of change
 @param keyboardFrame The keyboard frame in window coordinate
 @param notif The keyboard notification that can be re-used in the helper methods below
 */
- (void)keyboardHelper:(SFKeyboardHelper*)helper keyboardChanged:(SFKeyboardHelperChange)change keyboardFrame:(CGRect)keyboardFrame keyboardNotification:(NSNotification*)notif;

@end

/** This class helps manage the keyboard changes
 */
@interface SFKeyboardHelper : NSObject

/** The delegate
 */
@property (nonatomic, weak) id<SFKeyboardHelperDelegate> delegate;

/** Returns YES if the keyboard is visible, NO otherwise.
 */
@property (nonatomic, readonly, getter = isKeyboardVisible) BOOL keyboardVisible;

/** Returns the animation duration for the specified keyboard notification
 */
- (NSTimeInterval)animationDurationFromNotif:(NSNotification*)notif;

/** Invoke this method to trigger a UIView animation related to the keyboard notification
 @param notif The keyboard notification (as provided in the delegate method)
 @param animations The animations block
 @param completion The completion block
 */
- (void)animateWithNotification:(NSNotification*)notif animations:(void (^)(void))animations completion:(void (^)(BOOL finished))completion;

@end
