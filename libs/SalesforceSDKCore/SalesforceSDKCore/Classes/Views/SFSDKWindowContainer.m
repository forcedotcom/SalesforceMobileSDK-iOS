/*
 SFSDKWindowContainer.m
 SalesforceSDKCore
 
 Created by Raj Rao on 7/4/17.
 
 Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.
 
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
#import "SFSDKWindowContainer.h"

@interface SFSDKWindowContainer()

@end

@implementation SFSDKWindowContainer
@synthesize window = _window;

- (instancetype)initWithWindow:(UIWindow *)window name:(NSString *) windowName {
    
    self = [super init];
    if (self) {
        _window = window;
        _window.hidden = NO;
        _windowName = windowName;
        _viewController = window.rootViewController;
    }
    return self;
}

- (UIWindow *)window {
    if (_window == nil) {
        _window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
         _window.hidden = NO;
        _window.rootViewController = _viewController;
    }
    return _window;
}

- (void)setViewController:(UIViewController *) viewController {
    if (_viewController != viewController) {
        _viewController = viewController;
        self.window.rootViewController = viewController;
    }
}

- (void)enable {
    [self enable:NO withCompletion:nil];
}

- (BOOL)isEnabled {
    return self.window.alpha == 1.0;
}
- (void)enable:(BOOL)animated withCompletion:(void (^)(void))completion {
    if ( [self.windowDelegate respondsToSelector:@selector(windowEnable:animated:withCompletion:)]) {
        [self.windowDelegate windowEnable:self animated:animated withCompletion:completion];
    }
}

- (void)disable {
    [self disable:NO withCompletion:nil];
}

- (void)disable:(BOOL)animated withCompletion:(void (^)(void))completion {
    if ([self isEnabled]) {
        if ( [self.windowDelegate respondsToSelector:@selector(windowDisable:animated:withCompletion:)]) {
            [self.windowDelegate windowDisable:self animated:animated withCompletion:completion];
        }
    }
}

- (BOOL)isMainWindow {
    return _windowType == SFSDKWindowTypeMain;
}

- (BOOL)isAuthWindow {
    return _windowType == SFSDKWindowTypeAuth;
}


- (BOOL)isSnapshotWindow {
    return _windowType == SFSDKWindowTypeSnapshot;
}

- (BOOL)isPasscodeWindow {
    return _windowType == SFSDKWindowTypePasscode;
}

@end
