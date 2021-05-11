
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
#import "SFApplicationHelper.h"
#import "SFSecurityLockout.h"
#import "SFSDKMacDetectUtil.h"

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

@interface SFSDKWindowManager()<SFSDKWindowContainerDelegate>

@property (nonatomic, strong) NSHashTable *delegates;
@property (nonatomic, strong, readonly) NSMapTable<NSString *, NSMapTable<NSString *, SFSDKWindowContainer *> *> *namedWindows; // <SceneId, <WindowName, Container>>
@property (nonatomic, strong) NSMapTable<NSString *, SFSDKWindowContainer *> *lastActiveWindows;
@property (nonatomic, strong, nonnull) NSMapTable<NSString *, UIWindow *> *lastKeyWindows;

- (void)makeTransparentWithCompletion:(SFSDKWindowContainer *)window completion:(void (^)(void))completion;
- (void)makeOpaqueWithCompletion:(SFSDKWindowContainer *)window completion:(void (^)(void))completion;
@end

@interface SFSDKUIWindow ()
- (instancetype)initWithFrame:(CGRect)frame;
- (instancetype)initWithFrame:(CGRect)frame andName:(NSString *)windowName;
- (void)stashRootViewController;
- (void)unstashRootViewController;
- (void)disableWindow;
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
        _userInterfaceStyle = UIUserInterfaceStyleUnspecified;
        _lastActiveWindows = [NSMapTable strongToWeakObjectsMapTable];
        _lastKeyWindows = [NSMapTable strongToWeakObjectsMapTable];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sceneDidDisconnect:) name:UISceneDidDisconnectNotification object:nil];
    }
    return self;
}

- (SFSDKWindowContainer *)activeWindow {
    return [self activeWindow:nil];
}

- (SFSDKWindowContainer *)activeWindow:(UIScene *)scene {
    scene = [self nonnullScene:scene];
    BOOL found = NO;
    UIWindow *activeWindow = [self findActiveWindowForScene:scene];
    SFSDKWindowContainer *window = nil;
    NSEnumerator *enumerator = [self.namedWindows objectForKey:scene.session.persistentIdentifier].objectEnumerator;
    while ((window = [enumerator nextObject]))  {
        if (window.isEnabled && window.window == activeWindow) {
            found = YES;
            break;
        }
    }
    return found?window:nil;
}

- (SFSDKWindowContainer *)mainWindow {
    return [self mainWindow:nil];
}

- (SFSDKWindowContainer *)mainWindow:(UIScene *)scene {
    scene = [self nonnullScene:scene];
    SFSDKWindowContainer *mainWindow = [self containerForWindowKey:kSFMainWindowKey scene:scene];

    if (!mainWindow) {
        UIWindow *keyWindow = [self findActiveWindowForScene:scene];
        if (keyWindow) {
            [self.lastKeyWindows setObject:keyWindow forKey:scene.session.persistentIdentifier];
            [self setMainUIWindow:keyWindow scene:scene];
        }
    }
    return [[self.namedWindows objectForKey:scene.session.persistentIdentifier] objectForKey:kSFMainWindowKey];
}

- (void)setMainUIWindow:(UIWindow *) window {
    [self setMainUIWindow:window scene:nil];
}

- (void)setMainUIWindow:(UIWindow *)window scene:(UIScene *)scene {
    scene = [self nonnullScene:scene];
    SFSDKWindowContainer *container = [[SFSDKWindowContainer alloc] initWithWindow:window name:kSFMainWindowKey];
    container.windowType = SFSDKWindowTypeMain;
    container.windowDelegate = self;
    container.window.alpha = 1.0;
    container.window.overrideUserInterfaceStyle = self.userInterfaceStyle;
    [self setContainer:container windowKey:kSFMainWindowKey scene:scene];
}

- (nullable SFSDKWindowContainer *)containerForWindowKey:(NSString *)window scene:(UIScene *)scene {
    NSMapTable<NSString *, SFSDKWindowContainer *> *sceneWindows = [self.namedWindows objectForKey:scene.session.persistentIdentifier];
    return [sceneWindows objectForKey:window];
}

- (void)setContainer:(SFSDKWindowContainer *)window windowKey:(NSString *)windowKey scene:(UIScene *)scene {
    scene = [self nonnullScene:scene];
    NSMapTable<NSString *, SFSDKWindowContainer *> *sceneWindows = [self.namedWindows objectForKey:scene.session.persistentIdentifier];
    if (!sceneWindows) {
        sceneWindows = [NSMapTable mapTableWithKeyOptions:NSMapTableStrongMemory valueOptions:NSMapTableStrongMemory];
        [sceneWindows setObject:window forKey:windowKey];
        [_namedWindows setObject:sceneWindows forKey:scene.session.persistentIdentifier];
    } else {
        [[self.namedWindows objectForKey:scene.session.persistentIdentifier] setObject:window forKey:windowKey];
    }
}

- (SFSDKWindowContainer *)authWindow {
    return [self authWindow:nil];
}

- (SFSDKWindowContainer *)authWindow:(UIScene *)scene {
    scene = [self nonnullScene:scene];
    SFSDKWindowContainer *container = [self containerForWindowKey:kSFLoginWindowKey scene:scene];

    if (!container) {
        container = [self createAuthWindowForScene:scene];
    }
    [self setWindowScene:container scene:scene];
    //enforce WindowLevel
    container.windowLevel = [self mainWindow:scene].window.windowLevel + SFWindowLevelAuthOffset;
    return container;
}

- (SFSDKWindowContainer *)snapshotWindow {
    return [self snapshotWindow:nil];
}

- (SFSDKWindowContainer *)snapshotWindow:(UIScene *)scene {
    scene = [self nonnullScene:scene];
    SFSDKWindowContainer *container = [self containerForWindowKey:kSFSnaphotWindowKey scene:scene];
    if (!container) {
        container = [self createSnapshotWindowForScene:scene];
    }
    [self setWindowScene:container scene:scene];
    //enforce WindowLevel
    container.windowLevel = [self mainWindow:scene].window.windowLevel + SFWindowLevelSnapshotOffset;
    return container;
}

- (SFSDKWindowContainer *)passcodeWindow {
    return [self passcodeWindow:nil];
}

- (SFSDKWindowContainer *)passcodeWindow:(UIScene *)scene {
    scene = [self nonnullScene:scene];
    SFSDKWindowContainer *container = [self containerForWindowKey:kSFPasscodeWindowKey scene:scene];
    if (!container) {
        container = [self createPasscodeWindowForScene:scene];
    }
    [self setWindowScene:container scene:scene];
    //enforce WindowLevel
    container.windowLevel = [self mainWindow:scene].window.windowLevel + SFWindowLevelPasscodeOffset;
    return container;
}

- (SFSDKWindowContainer *)createNewNamedWindow:(NSString *)windowName {
    return [self createNewNamedWindow:windowName scene:nil];
}

- (SFSDKWindowContainer *)createNewNamedWindow:(NSString *)windowName scene:(nullable UIScene *)scene {
    scene = [self nonnullScene:scene];
    SFSDKWindowContainer * container = nil;
    if (![self isReservedName:windowName]) {
        container = [[SFSDKWindowContainer alloc] initWithName:windowName];
        container.windowDelegate = self;
        container.windowLevel = UIWindowLevelNormal;
        container.windowType = SFSDKWindowTypeOther;
        container.window.overrideUserInterfaceStyle = self.userInterfaceStyle;
        [self setContainer:container windowKey:windowName scene:scene];
    }
    return container;
}

- (BOOL)removeNamedWindow:(NSString *)windowName {
    return [self removeNamedWindow:windowName scene:nil];
}

- (BOOL)removeNamedWindow:(NSString *)windowName scene:(nullable UIScene *)scene {
    scene = [self nonnullScene:scene];
    BOOL result = NO;
    if (![self isReservedName:windowName]) {
        [[self.namedWindows objectForKey:scene.session.persistentIdentifier] removeObjectForKey:windowName];
        result = YES;
    }
    return result;
}

- (SFSDKWindowContainer *)windowWithName:(NSString *)name {
    return [self windowWithName:name scene:nil];
}

- (SFSDKWindowContainer *)windowWithName:(NSString *)name scene:(nullable UIScene *)scene {
    scene = [self nonnullScene:scene];
    SFSDKWindowContainer *container = [[self.namedWindows objectForKey:scene.session.persistentIdentifier] objectForKey:name];
    [self setWindowScene:container scene:nil];
    return container;
}

- (void)setWindowScene:(SFSDKWindowContainer *)container scene:(UIScene *)scene {
    scene = [self nonnullScene:scene];
    if (![scene isEqual:container.window.windowScene]) {
        container.window.windowScene = (UIWindowScene *)scene;
    }
    container.window.frame = container.window.windowScene.coordinateSpace.bounds;
}

- (void)setUserInterfaceStyle:(UIUserInterfaceStyle)userInterfaceStyle {
    _userInterfaceStyle = userInterfaceStyle;
    NSEnumerator *sceneEnumerator = [self.namedWindows objectEnumerator];
    NSMapTable<NSString *, SFSDKWindowContainer *> *sceneWindows;
    while (sceneWindows = [sceneEnumerator nextObject]) {
        NSEnumerator *windowEnumerator = [sceneWindows objectEnumerator];
        SFSDKWindowContainer *container;
        while (container = [windowEnumerator nextObject]) {
            container.window.overrideUserInterfaceStyle = userInterfaceStyle;
        }
    }
}

#pragma mark - SFSDKWindowManagerDelegate

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
- (BOOL)isReservedName:(NSString *) windowName {
    return ([windowName isEqualToString:kSFMainWindowKey] ||
            [windowName isEqualToString:kSFLoginWindowKey] ||
            [windowName isEqualToString:kSFPasscodeWindowKey] ||
            [windowName isEqualToString:kSFSnaphotWindowKey]);
}

- (void)makeTransparentWithCompletion:(SFSDKWindowContainer *)window completion:(void (^)(void))completion {
    UIScene *scene = window.window.windowScene;
    SFSDKWindowContainer *fallbackWindow = [self mainWindow:scene];
   
    if (window.isSnapshotWindow) {
        NSString *sceneId = scene.session.persistentIdentifier;
        if ([_lastActiveWindows objectForKey:sceneId]) {
            fallbackWindow = [_lastActiveWindows objectForKey:sceneId];
            [_lastActiveWindows removeObjectForKey:sceneId];
        }
    }

    if ([window.window isKindOfClass:[SFSDKUIWindow class]]) {
        [(SFSDKUIWindow *)window.window disableWindow];
    }

    if (!window.isMainWindow) {
        [[self.namedWindows objectForKey:scene.session.persistentIdentifier] removeObjectForKey:window.windowName];
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
    UIScene *scene = window.window.windowScene;
    if (window.isSnapshotWindow) {
        SFSDKWindowContainer *activeWindow = [self activeWindow:scene];
        if (![activeWindow isSnapshotWindow]){
            [_lastActiveWindows setObject:activeWindow forKey:scene.session.persistentIdentifier];
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
    return [self createSnapshotWindowForScene:nil];
}

- (SFSDKWindowContainer *)createSnapshotWindowForScene:(UIScene *)scene {
    SFSDKWindowContainer *container = [[SFSDKWindowContainer alloc] initWithName:kSFSnaphotWindowKey];
    container.windowDelegate = self;
    container.windowType = SFSDKWindowTypeSnapshot;
    container.window.overrideUserInterfaceStyle = self.userInterfaceStyle;
    [self setContainer:container windowKey:kSFSnaphotWindowKey scene:scene];
    return container;
}

- (SFSDKWindowContainer *)createAuthWindowForScene:(UIScene *)scene {
    SFSDKWindowContainer *container = [[SFSDKWindowContainer alloc] initWithName:kSFLoginWindowKey];
    container.windowDelegate = self;
    container.windowType = SFSDKWindowTypeAuth;
    [self setContainer:container windowKey:kSFLoginWindowKey scene:scene];
    return container;
}

- (SFSDKWindowContainer *)createAuthWindow {
    return [self createAuthWindowForScene:nil];
}

- (SFSDKWindowContainer *)createPasscodeWindow {
   return [self createPasscodeWindowForScene:nil];
}

- (SFSDKWindowContainer *)createPasscodeWindowForScene:(UIScene *)scene {
    SFSDKWindowContainer *container = [[SFSDKWindowContainer alloc] initWithName:kSFPasscodeWindowKey];
    container.windowDelegate = self;
    container.windowType = SFSDKWindowTypePasscode;
    container.window.overrideUserInterfaceStyle = self.userInterfaceStyle;
    [self setContainer:container windowKey:kSFPasscodeWindowKey scene:scene];
    return container;
}

- (BOOL)isManagedWindow:(UIWindow *) window {
    return [window isKindOfClass:[SFSDKUIWindow class]];
}

- (UIWindow *)findActiveWindowForScene:(UIScene *)scene {
    scene = [self nonnullScene:scene];
    UIWindow *mainWindow = [_lastKeyWindows objectForKey:scene.session.persistentIdentifier];
    
    if (!mainWindow && [scene.delegate respondsToSelector:@selector(window)]) {
        mainWindow = [scene.delegate performSelector:@selector(window)];
    } else if (!mainWindow && [[SFApplicationHelper sharedApplication].delegate respondsToSelector:@selector(window)]) {
        mainWindow = [SFApplicationHelper sharedApplication].delegate.window;
    }
    
    UIWindowScene *windowScene = (UIWindowScene *)scene;
    for (UIWindow *window in windowScene.windows) {
        if (window.isKeyWindow) {
            mainWindow = window;
            break;
        }
    }
    return mainWindow;
}

- (UIScene *)nonnullScene:(UIScene *)scene {
    if (!scene) {
        return [self defaultScene];
    }
    return scene;
}

- (UIScene *)defaultScene {
    NSArray *connectedScenes = [SFApplicationHelper sharedApplication].connectedScenes.allObjects;
    for (UIScene *connectedScene in connectedScenes) {
        if (connectedScene.activationState == UISceneActivationStateForegroundActive) {
            return connectedScene;
        } else if (connectedScene.activationState == UISceneActivationStateForegroundInactive) {
            return connectedScene;
        }
    }
    return connectedScenes.firstObject;
}

- (void)sceneDidDisconnect:(NSNotification *)notification {
    UIScene *scene = (UIScene *)notification.object;
    [self.namedWindows removeObjectForKey:scene.session.persistentIdentifier];
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
    NSString *sceneId = self.windowScene.session.persistentIdentifier;
    [[SFSDKWindowManager sharedManager].lastKeyWindows setObject:self forKey:sceneId];
}

- (void)becomeKeyWindow {
    [self unstashRootViewController];
    if (self.windowLevel < 0)
        self.windowLevel = self.windowLevel * -1;
    self.alpha = 1.0;
}

- (void)resignKeyWindow {
    if ([SFApplicationHelper sharedApplication].supportsMultipleScenes || [SFSDKMacDetectUtil isOnMac]) {
        // Automatically disabling the window breaks in these cases, apps should use makeTransparentWithCompletion if needed
        return;
    }
   
    [self disableWindow];
}

- (void)disableWindow {
    BOOL isActive = self.windowScene.activationState == UISceneActivationStateForegroundActive;
    if ([self isSnapshotWindow] || isActive) {
        if (self.windowLevel > 0)
            self.windowLevel = self.windowLevel * -1;
        self.alpha = 0.0;
        super.rootViewController = nil;
        [self stashRootViewController];
    }
}

- (BOOL)isSnapshotWindow {
    return [self.windowName isEqualToString:kSFSnaphotWindowKey];
}

@end
