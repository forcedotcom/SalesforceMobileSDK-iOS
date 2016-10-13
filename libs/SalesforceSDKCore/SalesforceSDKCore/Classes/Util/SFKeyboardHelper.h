/*
 Copyright (c) 2015, salesforce.com, inc. All rights reserved.
 
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
