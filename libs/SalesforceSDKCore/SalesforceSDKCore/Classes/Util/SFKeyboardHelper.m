//
//  SFKeyboardHelper.m
//  SalesforceSDKCore
//
//  Created by Qingqing Liu 05/09/2014
//  Copyright (c) 2013 Salesforce.com. All rights reserved.
//

#import "SFKeyboardHelper.h"
#import <SalesforceSDKCore/SalesforceSDKCore.h>

static inline UIViewAnimationOptions animationOptionsWithCurve(UIViewAnimationCurve curve) {
    switch (curve) {
        case UIViewAnimationCurveEaseInOut:
            return UIViewAnimationOptionCurveEaseInOut;
            
        case UIViewAnimationCurveEaseIn:
            return UIViewAnimationOptionCurveEaseIn;
            
        case UIViewAnimationCurveEaseOut:
            return UIViewAnimationOptionCurveEaseOut;
            
        case UIViewAnimationCurveLinear:
        default:
            return UIViewAnimationOptionCurveLinear;
    }
}

@interface SFKeyboardHelper ()

@property (nonatomic, readwrite) BOOL keyboardVisible;
@property (nonatomic, strong) id keyboardWillShowObserver;
@property (nonatomic, strong) id keyboardDidShowObserver;
@property (nonatomic, strong) id keyboardWillHideObserver;
@property (nonatomic, strong) id keyboardDidHideObserver;
@property (nonatomic, strong) id keyboardDidChangeFrameObserver;

@end

@implementation SFKeyboardHelper

- (id)init {
    self = [super init];
    if (self) {
        if ([UIDevice currentDevice].systemVersionNumber >= 9) {
            // for iOS 9 and above, stop keyboard monitoring when app become inactive (needed for split screen)
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillBecomeInactive:) name:UIApplicationWillResignActiveNotification object:nil];
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appBecameActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
        }
        [self subscribeForKeyboardNotifications];
    }
    return self;
}

- (void)subscribeForKeyboardNotifications {
#if !TARGET_OS_TV

    __weak __typeof(self) weakSelf = self;
    
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    self.keyboardWillShowObserver = [notificationCenter addObserverForName:UIKeyboardWillShowNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        [weakSelf keyboardWillShowNotification:note];
    }];
    self.keyboardDidShowObserver = [notificationCenter addObserverForName:UIKeyboardDidShowNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        [weakSelf keyboardDidShowNotification:note];
    }];
    self.keyboardWillHideObserver = [notificationCenter addObserverForName:UIKeyboardWillHideNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        [weakSelf keyboardWillHideNotification:note];
    }];
    self.keyboardDidHideObserver = [notificationCenter addObserverForName:UIKeyboardDidHideNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        [weakSelf keyboardDidHideNotification:note];
    }];
    self.keyboardDidChangeFrameObserver = [notificationCenter addObserverForName:UIKeyboardDidChangeFrameNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        [weakSelf keyboardDidChangeFrameNotification:note];
    }];
#endif
}

- (void)unscribeForKeyboardNotifications {
    [[NSNotificationCenter defaultCenter] removeObserver:self.keyboardWillShowObserver];
    [[NSNotificationCenter defaultCenter] removeObserver:self.keyboardDidShowObserver];
    [[NSNotificationCenter defaultCenter] removeObserver:self.keyboardWillHideObserver];
    [[NSNotificationCenter defaultCenter] removeObserver:self.keyboardDidHideObserver];
    [[NSNotificationCenter defaultCenter] removeObserver:self.keyboardDidChangeFrameObserver];
}

- (void)dealloc {
   [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (CGRect)keyboardFrameFromNotif:(NSNotification*)notif {
#if TARGET_OS_TV
    return CGRectZero;
#else
    NSValue *value = [[notif userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey];
    if (value) {
        CGRect keyboardFrame = [value CGRectValue];
        return keyboardFrame;
    } else {
        return CGRectZero;
    }
#endif
}

- (void)appWillBecomeInactive:(NSNotification*)notif {
    [self unscribeForKeyboardNotifications];
    if (self.isKeyboardVisible && [UIDevice currentDeviceIsIPad]) {
        self.keyboardVisible = NO;
        
        // iOS 9 hides keyboard automatically when app become inactive, so let delegate know that keyboard will hide
        // UIApplicationWillResignActiveNotification comes before UIKeyboardWillHideNotification notification, so we cannot rely on UIKeyboardWillHideNotification to inform delegate
        // as when we've already unsubscribed to the keyboard notifications after UIApplicationWillResignActiveNotification
        [self.delegate keyboardHelper:self
                      keyboardChanged:SFKeyboardHelperChangeWillHide
                        keyboardFrame:CGRectZero
                 keyboardNotification:notif];
    }
}

- (void)appBecameActive:(NSNotification*)notif {
    [self subscribeForKeyboardNotifications];
}

- (NSTimeInterval)animationDurationFromNotif:(NSNotification*)notif {
#if TARGET_OS_TV
    return 0;
#else
    return [[[notif userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
#endif
}

- (void)keyboardDidChangeFrameNotification:(NSNotification*)notif {
    [self log:SFLogLevelDebug format:@"Keyboard %@ changed frame: %@", self.delegate, NSStringFromCGRect([self keyboardFrameFromNotif:notif])];
    
    [self.delegate keyboardHelper:self
                  keyboardChanged:SFKeyboardHelperChangeFrameChanged
                    keyboardFrame:[self keyboardFrameFromNotif:notif]
             keyboardNotification:notif];
}

- (void)keyboardWillShowNotification:(NSNotification*)notif {
    [self log:SFLogLevelDebug format:@"Keyboard %@ will show: %@", self.delegate, NSStringFromCGRect([self keyboardFrameFromNotif:notif])];
    
    [self.delegate keyboardHelper:self
                  keyboardChanged:SFKeyboardHelperChangeWillShow
                    keyboardFrame:[self keyboardFrameFromNotif:notif]
             keyboardNotification:notif];
}

- (void)keyboardDidShowNotification:(NSNotification*)notif {
    self.keyboardVisible = YES;
    
    [self.delegate keyboardHelper:self
                  keyboardChanged:SFKeyboardHelperChangeDidShow
                    keyboardFrame:[self keyboardFrameFromNotif:notif]
             keyboardNotification:notif];
}

- (void)keyboardWillHideNotification:(NSNotification*)notif {
    [self log:SFLogLevelDebug format:@"Keyboard %@ will hide: %@", self.delegate, NSStringFromCGRect([self keyboardFrameFromNotif:notif])];
    
    [self.delegate keyboardHelper:self
                  keyboardChanged:SFKeyboardHelperChangeWillHide
                    keyboardFrame:[self keyboardFrameFromNotif:notif]
             keyboardNotification:notif];
}

- (void)keyboardDidHideNotification:(NSNotification*)notif {
    self.keyboardVisible = NO;
    
    [self.delegate keyboardHelper:self
                  keyboardChanged:SFKeyboardHelperChangeDidHide
                    keyboardFrame:[self keyboardFrameFromNotif:notif]
             keyboardNotification:notif];
}

- (void)animateWithNotification:(NSNotification*)notif animations:(void (^)(void))animations completion:(void (^)(BOOL finished))completion {
#if TARGET_OS_TV
    if (completion) completion(YES);
#else
    double duration = [[[notif userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationCurve curve = [[[notif userInfo] objectForKey:UIKeyboardAnimationCurveUserInfoKey] integerValue];
    
    [UIView animateWithDuration:duration
                          delay:0
                        options:animationOptionsWithCurve(curve)
                     animations:animations
                     completion:completion];
#endif
}

@end
