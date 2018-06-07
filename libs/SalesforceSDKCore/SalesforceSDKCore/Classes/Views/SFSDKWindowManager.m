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
/*
Attempt to resolve issues related to  the multi-windowing implementation in the SDK. Multiple visible UI windows tend to have some really bad side effects with rotations (keyboard and views) and status bar. We previously resorted to using the hidden property, unfortunately using hidden property on the UIWindow leads to really bad flicker issues ( black screen ). Reverted back to using alpha with a slightly different strategy.
 
 A debugging of UIKIT revealed the following facts.
 
 All UIWindows are rotated when rotation occurs.
 
 All preference calls are delegated to the window's rootviewcontroller if present.
 
 Multiple windows with different behaviors will lead to weird UI experience. For instance a visible window may be locked to portrait mode, but during rotation the status bar will still continue to rotate because another window may allow rotations. It will also lead to keyboard window being in the wrong orientation.
 
 Strategy used.
 
 Stash(nullify) the rootviewcontroller when the window is presented and unstash(restore) when dismissed. Extended UIWindow (SFSDKUIWindow) to handle the stash and unstash.
 Windows are created lazily and the references are removed when the windows are dismissed.
 */
@interface SFSDKUIWindow ()
- (instancetype)initWithFrame:(CGRect)frame;
- (instancetype)initWithFrame:(CGRect)frame andName:(NSString *)windowName;
- (void)stashRootViewController;
- (void)unstashRootViewController;

@end

@implementation SFSDKUIWindow

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _windowName = @"NONAME";
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame andName:(NSString *)windowName {
    self = [super initWithFrame:frame];
    if (self) {
        _windowName = windowName;
    }
    return self;
}

- (void)stashRootViewController {
    if (self.rootViewController) {
        _stashedController = self.rootViewController;
        super.rootViewController = nil;
    }
}

- (void)unstashRootViewController {
    if (_stashedController)
        super.rootViewController = _stashedController;
}

- (void)setRootViewController:(UIViewController *)rootViewController {
    _stashedController = rootViewController;
    super.rootViewController = rootViewController;
}

- (void)makeKeyAndVisible {
    [super makeKeyAndVisible];
}

- (void)becomeKeyWindow {
    [self unstashRootViewController];
    if (self.windowLevel <0)
        self.windowLevel = self.windowLevel * -1;
    self.alpha = 1.0;
}

- (void)resignKeyWindow{
    if ([self isSnapshotWindow] || [SFApplicationHelper sharedApplication].applicationState == UIApplicationStateActive){
        if (self.windowLevel>0)
            self.windowLevel = self.windowLevel * -1;
        self.alpha = 0.0;
        super.rootViewController = nil;
        [self stashRootViewController];
    }
}
- (BOOL)isSnapshotWindow {
    return [self.windowName isEqualToString:[SFSDKWindowManager sharedManager].snapshotWindow.windowName];
}

@end

@interface SFSDKWindowManager()<SFSDKWindowContainerDelegate>

@property (nonatomic, strong) NSHashTable *delegates;
@property (nonatomic, strong,readonly) NSMapTable<NSString *,SFSDKWindowContainer *> * _Nonnull namedWindows;
@property (nonatomic,weak) SFSDKWindowContainer *lastActiveWindow;

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
        if(window.isEnabled && window.window==activeWindow) {
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
    container.windowLevel = self.mainWindow.window.windowLevel + SFWindowLevelAuthOffset;
    return container;
}

- (SFSDKWindowContainer *)snapshotWindow {
    SFSDKWindowContainer *container = [self.namedWindows objectForKey:kSFSnaphotWindowKey];
    if (!container) {
        container = [self createSnapshotWindow];
    }
    //enforce WindowLevel
    container.windowLevel = self.mainWindow.window.windowLevel + SFWindowLevelSnapshotOffset;
    return container;
}

- (SFSDKWindowContainer *)passcodeWindow {
    SFSDKWindowContainer *container = [self.namedWindows objectForKey:kSFPasscodeWindowKey];
    if (!container) {
        container = [self createPasscodeWindow];
    }
    //enforce WindowLevel
    container.windowLevel = self.mainWindow.window.windowLevel + SFWindowLevelPasscodeOffset;
    return container;
}

- (SFSDKWindowContainer *)createNewNamedWindow:(NSString *)windowName {
    SFSDKWindowContainer * container = nil;
    if ( ![self isReservedName:windowName] ) {
        container = [[SFSDKWindowContainer alloc] initWithName:windowName];
        container.windowDelegate = self;
        container.windowLevel = UIWindowLevelNormal;
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
        UIViewPropertyAnimator *animator = [[UIViewPropertyAnimator alloc] initWithDuration:0.25 curve:UIViewAnimationCurveEaseInOut animations:^{
            window.window.alpha = 1.0;
        }];
        [animator startAnimation];
        [self makeOpaqueWithCompletion:window completion:completion];
        
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
    if (!window.isEnabled) {
        if (completion)
            completion();
    }
    
    [self enumerateDelegates:^(id<SFSDKWindowManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(windowManager:willDismissWindow:)]){
            [delegate windowManager:self willDismissWindow:window];
        }
    }];
    
    if (animated) {
        UIViewPropertyAnimator *animator = [[UIViewPropertyAnimator alloc] initWithDuration:0.25 curve:UIViewAnimationCurveEaseInOut animations:^{
            window.window.alpha = 1.0;
        }];
        [animator startAnimation];
        [self makeTransparentWithCompletion:window completion:completion];
        
    } else {
        [self makeTransparentWithCompletion:window completion:completion];
    }
    
}

#pragma mark - private methods
- (void)makeTransparentWithCompletion:(SFSDKWindowContainer *)window completion:(void (^)(void))completion {
    SFSDKWindowContainer *fallbackWindow = self.mainWindow;
   
    if (window.isSnapshotWindow) {
        
        [window.window resignKeyWindow];
        if (_lastActiveWindow) {
            fallbackWindow = _lastActiveWindow;
            _lastActiveWindow = nil;
        }
        
    }
    [window.window resignKeyWindow];
    if (!window.isMainWindow) {
        [self.namedWindows removeObjectForKey:window.windowName];
    }
    //fallback to a window
    [fallbackWindow.window makeKeyAndVisible];
    
    [self enumerateDelegates:^(id<SFSDKWindowManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(windowManager:didDismissWindow:)]){
            [delegate windowManager:self didDismissWindow:window];
        }
    }];
    
    if (completion)
        completion();
}

- (void)makeOpaqueWithCompletion:(SFSDKWindowContainer *)window completion:(void (^)(void))completion {
    if (window.isSnapshotWindow) {
        SFSDKWindowContainer *activeWindow = [self activeWindow];
        if (![activeWindow isSnapshotWindow]){
            _lastActiveWindow = activeWindow;
        }
    }
    
    if ([window isEnabled]) {
        if (completion)
            completion();
        return;
    }
    
    [window.window makeKeyAndVisible];
    [self enumerateDelegates:^(id<SFSDKWindowManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(windowManager:didPresentWindow:)]){
            [delegate windowManager:self didPresentWindow:window];
        }
    }];
    if (completion)
        completion();

}

- (SFSDKWindowContainer *)createSnapshotWindow {
    SFSDKWindowContainer *container = [[SFSDKWindowContainer alloc] initWithName:kSFSnaphotWindowKey];
    container.windowDelegate = self;
    container.windowType = SFSDKWindowTypeSnapshot;
    [self.namedWindows setObject:container forKey:kSFSnaphotWindowKey];
    return container;
}

- (SFSDKWindowContainer *)createAuthWindow {
    SFSDKWindowContainer *container = [[SFSDKWindowContainer alloc] initWithName:kSFLoginWindowKey];
    container.windowDelegate = self;
    container.windowType = SFSDKWindowTypeAuth;
    [self.namedWindows setObject:container forKey:kSFLoginWindowKey];
    return container;
}

- (SFSDKWindowContainer *)createPasscodeWindow {
    SFSDKWindowContainer *container = [[SFSDKWindowContainer alloc] initWithName:kSFPasscodeWindowKey];
    container.windowDelegate = self;
    container.windowType = SFSDKWindowTypePasscode;
    [self.namedWindows setObject:container forKey:kSFPasscodeWindowKey];
    return container;
}

-(UIWindow *)createDefaultUIWindowNamed:(NSString *)name {
    UIWindow *window = [[SFSDKUIWindow alloc]  initWithFrame:UIScreen.mainScreen.bounds andName:name];
    [window setAlpha:0.0];
    window.rootViewController = [[SFSDKRootController alloc] init];
    return  window;
}

- (BOOL)isManagedWindow:(UIWindow *) window {
    return [window isKindOfClass:[SFSDKUIWindow class]];
}

- (UIWindow *)findActiveWindow {
    return [SFApplicationHelper sharedApplication].keyWindow;
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
