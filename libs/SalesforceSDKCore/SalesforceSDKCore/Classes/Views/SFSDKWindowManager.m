/*
 SFUIWindowManager.m
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
#import "SFSDKWindowManager.h"
#import "SFSDKWindowContainer.h"
#import "SFSDKRootController.h"
#import "SFApplicationHelper.h"
#import "SFSecurityLockout.h"

@interface SFSDKWindowManager()<SFSDKWindowContainerDelegate>

@property (nonatomic, strong) NSHashTable *delegates;
@property (nonatomic, strong,readonly) NSMapTable<NSString *,SFSDKWindowContainer *> * _Nonnull namedWindows;

- (void)makeTransparentWithCompletion:(SFSDKWindowContainer *)window completion:(void (^)(void))completion;
- (void)makeOpaqueWithCompletion:(SFSDKWindowContainer *)window completion:(void (^)(void))completion;
@end

@implementation SFSDKWindowManager

static const CGFloat SFWindowLevelPasscodeOffset  = 100;
static const CGFloat SFWindowLevelAuthOffset      = 120;
static const CGFloat SFWindowLevelSnapshotOffset  = 1000;
static NSString *const kSFMainWindowKey     = @"main";
static NSString *const kSFLoginWindowKey    = @"auth";
static NSString *const kSFSnaphotWindowKey  = @"snapshot";
static NSString *const kSFPasscodeWindowKey = @"passcode";

- (instancetype)init {
    
    self = [super init];
    if (self) {
        _namedWindows = [NSMapTable mapTableWithKeyOptions:NSMapTableStrongMemory
                                              valueOptions:NSMapTableStrongMemory];
        _delegates = [NSHashTable weakObjectsHashTable];
    }
    return self;
}

- (SFSDKWindowContainer *)activeWindow {
    BOOL found = NO;
    UIWindow *activeWindow = [self findActiveWindow];
    SFSDKWindowContainer *window = nil;
    NSEnumerator *enumerator = self.namedWindows.objectEnumerator;
    while ((window = [enumerator nextObject]))  {
        if(window.window==activeWindow) {
            found = YES;
            break;
        }
    }
    return found?window:nil;
}

- (SFSDKWindowContainer *)mainWindow {
    SFSDKWindowContainer *mainWindow = [self.namedWindows objectForKey:kSFMainWindowKey];
    
    if (!mainWindow) {
        [self setMainUIWindow:[SFApplicationHelper sharedApplication].delegate.window];
        mainWindow = [self.namedWindows objectForKey:kSFMainWindowKey];
    }
    
    return [self.namedWindows objectForKey:kSFMainWindowKey];
}

- (void)setMainUIWindow:(UIWindow *) window {
    SFSDKWindowContainer *container = [[SFSDKWindowContainer alloc] initWithWindow:window name:kSFMainWindowKey];
    container.windowType = SFSDKWindowTypeMain;
    container.windowDelegate = self;
    container.window.alpha = 1.0;
    [self.namedWindows setObject:container forKey:kSFMainWindowKey];
}

- (SFSDKWindowContainer *)authWindow {
    SFSDKWindowContainer *container = [self.namedWindows objectForKey:kSFLoginWindowKey];
    if (!container) {
        container = [self createAuthWindow];
    }
    //enforce WindowLevel
    container.window.windowLevel = self.mainWindow.window.windowLevel + SFWindowLevelAuthOffset;
    return container;
}

- (SFSDKWindowContainer *)snapshotWindow {
    SFSDKWindowContainer *container = [self.namedWindows objectForKey:kSFSnaphotWindowKey];
    if (!container) {
        container = [self createSnapshotWindow];
    }
    //enforce WindowLevel
    container.window.windowLevel = self.mainWindow.window.windowLevel + SFWindowLevelSnapshotOffset;
    return container;
}

- (SFSDKWindowContainer *)passcodeWindow {
    SFSDKWindowContainer *container = [self.namedWindows objectForKey:kSFPasscodeWindowKey];
    if (!container) {
        container = [self createPasscodeWindow];
    }
    //enforce WindowLevel
    container.window.windowLevel = self.mainWindow.window.windowLevel + SFWindowLevelPasscodeOffset;
    return container;
}

- (SFSDKWindowContainer *)createNewNamedWindow:(NSString *)windowName {
    SFSDKWindowContainer * container = nil;
    if ( ![self isReservedName:windowName] ) {
        UIWindow *window = [self createDefaultUIWindow];
        container = [[SFSDKWindowContainer alloc] initWithWindow:window name:windowName];
        container.windowDelegate = self;
        container.window.windowLevel = UIWindowLevelNormal;
        container.windowType = SFSDKWindowTypeOther;
        [self.namedWindows setObject:container forKey:windowName];
    }
    return container;
}

- (BOOL)isReservedName:(NSString *) windowName {
    return ([windowName isEqualToString:kSFMainWindowKey] ||
            [windowName isEqualToString:kSFLoginWindowKey] ||
            [windowName isEqualToString:kSFPasscodeWindowKey] ||
            [windowName isEqualToString:kSFSnaphotWindowKey]);
    
}

- (BOOL)removeNamedWindow:(NSString *)windowName {
    BOOL result = NO;
    if (![self isReservedName:windowName]) {
        [self.namedWindows removeObjectForKey:windowName];
        result = YES;
    }
    return result;
}

- (SFSDKWindowContainer *)windowWithName:(NSString *)name {
    return [self.namedWindows objectForKey:name];
}

- (void)addDelegate:(id<SFSDKWindowManagerDelegate>)delegate
{
    @synchronized (self) {
        [_delegates addObject:[NSValue valueWithNonretainedObject:delegate]];
    }
}

- (void)removeDelegate:(id<SFSDKWindowManagerDelegate>)delegate
{
    @synchronized (self) {
        [_delegates removeObject:[NSValue valueWithNonretainedObject:delegate]];
    }
}

- (void)enumerateDelegates:(void (^)(id<SFSDKWindowManagerDelegate> delegate))block
{
    @synchronized(self) {
        [_delegates.allObjects enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            id<SFSDKWindowManagerDelegate> delegate = [obj nonretainedObjectValue];
            if (delegate) {
                if (block) block(delegate);
            }
        }];
    }
}
#pragma mark - SFSDKWindowContainerDelegate
- (void)presentWindow:(SFSDKWindowContainer *)window animated:(BOOL)animated withCompletion:(void (^ _Nullable)(void))completion{

    if (![NSThread isMainThread]) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self presentWindow:window animated:animated withCompletion:completion];
        });
        return;
    }

    [self enumerateDelegates:^(id<SFSDKWindowManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(windowManager:willPresentWindow:)]){
            [delegate windowManager:self willPresentWindow:window];
        }
    }];
    
    if (animated) {
        __weak typeof (self) weakSelf = self;
        UIViewPropertyAnimator *animator = [[UIViewPropertyAnimator alloc] initWithDuration:0.25 curve:UIViewAnimationCurveEaseInOut animations:^{
            [weakSelf makeOpaqueWithCompletion:window completion:completion];
        }];
        [animator startAnimation];
    } else {
        [self makeOpaqueWithCompletion:window completion:completion];
    }
}

- (void)dismissWindow:(SFSDKWindowContainer *)window animated:(BOOL)animated withCompletion:(void (^ _Nullable)(void))completion{
    if (![NSThread isMainThread]) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self dismissWindow:window animated:animated withCompletion:completion];
        });
        return;
    }

    [self enumerateDelegates:^(id<SFSDKWindowManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(windowManager:willDismissWindow:)]){
            [delegate windowManager:self willDismissWindow:window];
        }
    }];
   
    if (animated) {
        __weak typeof (self) weakSelf = self;
        UIViewPropertyAnimator *animator = [[UIViewPropertyAnimator alloc] initWithDuration:0.25 curve:UIViewAnimationCurveEaseInOut animations:^{
            [weakSelf makeTransparentWithCompletion:window completion:completion];
        }];
        
        [animator startAnimation];
    } else {
        [self makeTransparentWithCompletion:window completion:completion];
    }
    
}


#pragma mark - private methods
- (void)makeTransparentWithCompletion:(SFSDKWindowContainer *)window completion:(void (^)(void))completion {
    window.window.alpha = 0.0; //make Transparent
    
    [self updateKeyWindow:nil];
    [self enumerateDelegates:^(id<SFSDKWindowManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(windowManager:didDismissWindow:)]){
            [delegate windowManager:self didDismissWindow:window];
        }
    }];
    if (completion)
        completion();
}

- (void)makeOpaqueWithCompletion:(SFSDKWindowContainer *)window completion:(void (^)(void))completion {
    window.window.alpha = 1.0; //make Opaque
    [self updateKeyWindow:window];
    [self enumerateDelegates:^(id<SFSDKWindowManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(windowManager:didPresentWindow:)]){
            [delegate windowManager:self didPresentWindow:window];
        }
    }];
    if (completion)
        completion();
    
}
- (SFSDKWindowContainer *)createSnapshotWindow {
    UIWindow *window = [self createDefaultUIWindow];
    SFSDKWindowContainer *container = [[SFSDKWindowContainer alloc] initWithWindow:window name:kSFSnaphotWindowKey];
    container.windowDelegate = self;
    container.windowType = SFSDKWindowTypeSnapshot;
    [self.namedWindows setObject:container forKey:kSFSnaphotWindowKey];
    return container;
}

- (SFSDKWindowContainer *)createAuthWindow {
    UIWindow *window = [self createDefaultUIWindow];
    SFSDKWindowContainer *container = [[SFSDKWindowContainer alloc] initWithWindow:window name:kSFLoginWindowKey];
    container.windowDelegate = self;
    container.windowType = SFSDKWindowTypeAuth;
    
    [self.namedWindows setObject:container forKey:kSFLoginWindowKey];
    return container;
}

- (SFSDKWindowContainer *)createPasscodeWindow {
    UIWindow *window = [self createDefaultUIWindow];
    SFSDKWindowContainer *container = [[SFSDKWindowContainer alloc] initWithWindow:window name:kSFPasscodeWindowKey];
    container.windowDelegate = self;
    container.windowType = SFSDKWindowTypePasscode;
    [self.namedWindows setObject:container forKey:kSFPasscodeWindowKey];
    return container;
}

-(UIWindow *)createDefaultUIWindow {
    UIWindow *window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    [window setAlpha:0.0];
    window.rootViewController = [[SFSDKRootController alloc] init];
    return  window;
}

- (BOOL)isKeyboard:(UIWindow *) window {
    return ([NSStringFromClass([window class]) hasPrefix:@"UIRemoteKeyboardWindow"]
            || [NSStringFromClass([window class])hasPrefix:@"UITextEffectsWindow"]);
}

- (void)updateKeyWindow:(SFSDKWindowContainer *)window {
   
    if ([self.snapshotWindow isEnabled])
        return;

    BOOL windowFound = NO;
    for (NSInteger i = [SFApplicationHelper sharedApplication].windows.count - 1; i >= 0; i--) {
        UIWindow *win = ([SFApplicationHelper sharedApplication].windows)[i];
        if (win.alpha == 0.0 || [self isKeyboard:win]) {
            continue;
        } else if (window!=nil && window.window!=win) {
            continue; // in case the window is not the keywindow is not the enabled window (applies for enable only)
        } else {
            windowFound = YES;
            [win makeKeyWindow];
            break;
        }
    }
    //Should not be the case but if we do find ourselves in this situation, we can make the mainWindow
    //the key window as a fallback
    if (!windowFound) {
        [SFSDKCoreLogger e:[self class] format:@"SFSDKWindowManager could not make a window key: %@ will fallback to making mainWindow as Key Window", window.windowName];
        [[self mainWindow].window makeKeyWindow];
    }
    
}

- (UIWindow *)findActiveWindow {

    UIWindow *foundWindow = nil;
    for (NSInteger i = [SFApplicationHelper sharedApplication].windows.count - 1; i >= 0; i--) {
        UIWindow *win = ([SFApplicationHelper sharedApplication].windows)[i];
        if (win.alpha == 0.0 || [self isKeyboard:win]) {
            continue;
        } else {
            foundWindow = win;
            break;
        }
    }

    return foundWindow;
}

+ (instancetype)sharedManager {
    static dispatch_once_t token;
    static SFSDKWindowManager *sharedInstance = nil;
    dispatch_once(&token,^{
        sharedInstance = [[SFSDKWindowManager alloc]init];
    });
    return sharedInstance;
}
@end
