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
@interface SFSDKWindowManager() <SFSDKWindowContainerDelegate> {
    SFSDKWindowContainer *_prevActiveWindow;
    SFSDKWindowContainer *_currentWindow;
}
@property (nonatomic, strong) NSMutableOrderedSet *delegates;

@end

@implementation SFSDKWindowManager

static const CGFloat SFWindowLevelAuthOffset      = 100;
static const CGFloat SFWindowLevelPasscodeOffset  = 200;
static const CGFloat SFWindowLevelSnapshotOffset  = 2000;
static NSString *const kSFMainWindowKey     = @"main";
static NSString *const kSFLoginWindowKey    = @"auth";
static NSString *const kSFSnaphotWindowKey  = @"snapshot";
static NSString *const kSFPasscodeWindowKey = @"passcode";

- (instancetype)init {
    
    self = [super init];
    if (self) {
        _namedWindows = [NSMapTable mapTableWithKeyOptions:NSMapTableStrongMemory
                                              valueOptions:NSMapTableStrongMemory];
        _delegates = [NSMutableOrderedSet orderedSet];
    }
    return self;
    
}

- (SFSDKWindowContainer *)mainWindow {
    if (![self.namedWindows objectForKey:kSFMainWindowKey]) {
        [self setMainUIWindow:[SFApplicationHelper sharedApplication].windows[0]];
    }
    return [self.namedWindows objectForKey:kSFMainWindowKey];
}

- (void)setMainUIWindow:(UIWindow *) window {
    SFSDKWindowContainer *container = [[SFSDKWindowContainer alloc] initWithWindow:window andName:kSFMainWindowKey];
    
    container.windowType = SFSDKWindowTypeMain;
    container.windowLevel = window.windowLevel;
    [container addDelegate:self];
    _prevActiveWindow = container;
    _currentWindow = container;
    [self.namedWindows setObject:container forKey:kSFMainWindowKey];
}

- (SFSDKWindowContainer *)authWindow {
    SFSDKWindowContainer *window = [self.namedWindows objectForKey:kSFLoginWindowKey];
    if (!window) {
        window = [self createAuthWindow];
    }
    return window;
}

- (SFSDKWindowContainer *)snapshotWindow {
    SFSDKWindowContainer *window = [self.namedWindows objectForKey:kSFSnaphotWindowKey];
    if (!window) {
        window = [self createSnapshotWindow];
    }
    return window;
}

- (SFSDKWindowContainer *)passcodeWindow {
    SFSDKWindowContainer *window = [self.namedWindows objectForKey:kSFPasscodeWindowKey];
    if (!window) {
        window = [self createPasscodeWindow];
    }
    return window;
}

- (SFSDKWindowContainer *)createNewNamedWindow:(NSString *)windowName {
    SFSDKWindowContainer * container = nil;
    if ( ![self isReservedName:windowName] ) {
        UIWindow *window = [self createDefaultUIWindow];
        container = [[SFSDKWindowContainer alloc] initWithWindow:window andName:windowName];
        container.windowType = SFSDKWindowTypeOther;
        [container addDelegate:self];
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

- (void)bringToFront:(SFSDKWindowContainer *)windowContainer {
    
    if (!windowContainer)
        return;

    SFSDKWindowContainer *snapshotWindow = [self.namedWindows objectForKey:kSFSnaphotWindowKey];
    
    if ((_currentWindow != snapshotWindow) && (_currentWindow!=windowContainer) )
        _prevActiveWindow = _currentWindow;
    
    _currentWindow = windowContainer;
    [windowContainer makeKeyVisible];
    
    //send the rest of the windows to back
    for ( NSString *wName in self.namedWindows.keyEnumerator ) {
        SFSDKWindowContainer *wContainer = [self.namedWindows objectForKey:wName];
        if (![wName isEqualToString:windowContainer.windowName]) {
            [wContainer sendToBack];
        }
    }
}

- (void)addDelegate:(id<SFWindowManagerDelegate>)delegate
{
    @synchronized (self) {
        [_delegates addObject:[NSValue valueWithNonretainedObject:delegate]];
    }
}

- (void)removeDelegate:(id<SFWindowManagerDelegate>)delegate
{
    @synchronized (self) {
        [_delegates removeObject:[NSValue valueWithNonretainedObject:delegate]];
    }
}

- (void)enumerateDelegates:(void (^)(id<SFWindowManagerDelegate> delegate))block
{
    @synchronized(self) {
        [_delegates enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            id<SFWindowManagerDelegate> delegate = [obj nonretainedObjectValue];
            if (delegate) {
                if (block) block(delegate);
            }
        }];
    }
}

- (void)restorePreviousActiveWindow {
    if ([SFSecurityLockout locked] && [SFSecurityLockout passcodeViewController] ) {
        [self pushViewController:[SFSecurityLockout passcodeViewController] window:self.passcodeWindow withCompletion:nil];
    }else if( _prevActiveWindow ) {
        [self bringToFront:_prevActiveWindow];
    } else {
        [self bringToFront:self.mainWindow];
    }
}

- (void)pushViewController:(UIViewController *)controller window:(SFSDKWindowContainer *)window withCompletion:(void (^)(void))completion {
    [self bringToFront:window];
    [window pushViewController:controller animated:NO completion:completion];
}

- (void)popViewController:(UIViewController *)controller window:(SFSDKWindowContainer *)window withCompletion:(void (^)(void))completion {
    [window popViewController:controller animated:NO completion:completion];
}

#pragma mark - private methods
- (SFSDKWindowContainer *)createSnapshotWindow {
    UIWindow *window = [self createDefaultUIWindow];
    SFSDKWindowContainer *container = [[SFSDKWindowContainer alloc] initWithWindow:window andName:kSFSnaphotWindowKey];
    container.windowLevel = self.mainWindow.windowLevel + SFWindowLevelSnapshotOffset;
    container.windowType = SFSDKWindowTypeSnapshot;
    [self.namedWindows setObject:container forKey:kSFSnaphotWindowKey];
    return container;
}

- (SFSDKWindowContainer *)createAuthWindow {
    UIWindow *window = [self createDefaultUIWindow];
    SFSDKWindowContainer *container = [[SFSDKWindowContainer alloc] initWithWindow:window andName:kSFLoginWindowKey];
    container.windowLevel = self.mainWindow.windowLevel + SFWindowLevelAuthOffset;
    container.windowType = SFSDKWindowTypeAuth;
    [container addDelegate:self];
    [self.namedWindows setObject:container forKey:kSFLoginWindowKey];
    return container;
}

- (SFSDKWindowContainer *)createPasscodeWindow {
    UIWindow *window = [self createDefaultUIWindow];
    SFSDKWindowContainer *container = [[SFSDKWindowContainer alloc] initWithWindow:window andName:kSFPasscodeWindowKey];
    container.windowLevel = self.mainWindow.windowLevel + SFWindowLevelPasscodeOffset;
    container.windowType = SFSDKWindowTypePasscode;
    [container addDelegate:self];
    [self.namedWindows setObject:container forKey:kSFPasscodeWindowKey];
    return container;
}

-(UIWindow *)createDefaultUIWindow {
    UIWindow *window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    [window setHidden:YES];
    window.rootViewController = [[SFSDKRootController alloc] init];
    return  window;
}

- (void)windowWillMakeKeyVisible:(SFSDKWindowContainer *)window {
    __weak typeof(self) weakSelf = self;
    [self enumerateDelegates:^(id <SFWindowManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(windowManager:willBringToFront:)]) {
            [delegate windowManager:weakSelf willBringToFront:window];
        }
    }];
}

- (void)windowDidMakeKeyVisible:(SFSDKWindowContainer *)window {
    __weak typeof(self) weakSelf = self;
    [self enumerateDelegates:^(id <SFWindowManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(windowManager:didBringToFront:)]) {
            [delegate windowManager:weakSelf didBringToFront:window];
        }
    }];
}

- (void)windowWillPushViewController:(SFSDKWindowContainer *)window controller:(UIViewController *)controller {
    __weak typeof(self) weakSelf = self;
    [self enumerateDelegates:^(id <SFWindowManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(windowManager:willPushViewController:controller:)]) {
            [delegate windowManager:weakSelf willPushViewController:window controller:controller];
        }
    }];
    
}

- (void)windowDidPushViewController:(SFSDKWindowContainer *)window controller:(UIViewController *)controller {
    __weak typeof(self) weakSelf = self;
    [self enumerateDelegates:^(id <SFWindowManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(windowManager:didPushViewController:controller:)]) {
            [delegate windowManager:weakSelf didPushViewController:window controller:controller];
        }
    }];
    
}

- (void)windowWillPopViewController:(SFSDKWindowContainer *)window controller:(UIViewController *)controller {
    __weak typeof(self) weakSelf = self;
    [self enumerateDelegates:^(id <SFWindowManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(windowManager:willPopViewController:controller:)]) {
            [delegate windowManager:weakSelf willPopViewController:window controller:controller];
        }
    }];
}

- (void)windowDidPopViewController:(SFSDKWindowContainer *)window controller:(UIViewController *)controller {
    __weak typeof(self) weakSelf = self;
    [self enumerateDelegates:^(id <SFWindowManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(windowManager:didPopViewController:controller:)]) {
            [delegate windowManager:weakSelf didPopViewController:window controller:controller];
        }
    }];
    
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
