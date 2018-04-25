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
@property (nonatomic, strong,readonly) NSMapTable<UIWindow *,SFSDKWindowContainer *> * _Nonnull reverseLookupTable;
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
        _reverseLookupTable = [NSMapTable mapTableWithKeyOptions:NSMapTableStrongMemory
                                              valueOptions:NSMapTableStrongMemory];
        _delegates = [NSHashTable weakObjectsHashTable];
    }
    return self;
}

- (SFSDKWindowContainer *)activeWindow {
    UIWindow *activeWindow = [self findActiveWindow];
    SFSDKWindowContainer *window = [self.reverseLookupTable objectForKey:activeWindow];
    return window;
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
    container.window.hidden = NO;
    [self.namedWindows setObject:container forKey:kSFMainWindowKey];
    [self.reverseLookupTable setObject:container forKey:container.window];
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
    container.window.accessibilityElementsHidden = YES;
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
        [self.reverseLookupTable setObject:container forKey:container.window];
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
        SFSDKWindowContainer *container = [self.namedWindows objectForKey:windowName];
        [self.namedWindows removeObjectForKey:windowName];
        if (container)
            [self.reverseLookupTable removeObjectForKey:container.window];
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
- (void)presentWindow:(SFSDKWindowContainer *)window withCompletion:(void (^ _Nullable)(void))completion{

    if (![NSThread isMainThread]) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self presentWindow:window withCompletion:completion];
        });
        return;
    }

    [self enumerateDelegates:^(id<SFSDKWindowManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(windowManager:willPresentWindow:)]){
            [delegate windowManager:self willPresentWindow:window];
        }
    }];
    
    [self showWindow:window];
    
    [self enumerateDelegates:^(id<SFSDKWindowManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(windowManager:didPresentWindow:)]){
            [delegate windowManager:self didPresentWindow:window];
        }
    }];
    if (completion)
        completion();
    
}

- (void)dismissWindow:(SFSDKWindowContainer *)window withCompletion:(void (^ _Nullable)(void))completion{
    if (![NSThread isMainThread]) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self dismissWindow:window withCompletion:completion];
        });
        return;
    }

    [self enumerateDelegates:^(id<SFSDKWindowManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(windowManager:willDismissWindow:)]){
            [delegate windowManager:self willDismissWindow:window];
        }
    }];
   
    [self hideWindow:window];
    
    [self enumerateDelegates:^(id<SFSDKWindowManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(windowManager:didDismissWindow:)]){
            [delegate windowManager:self didDismissWindow:window];
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
     container.window.alpha = 1.0;
    [self.namedWindows setObject:container forKey:kSFSnaphotWindowKey];
    [self.reverseLookupTable setObject:container forKey:container.window];
    return container;
}

- (SFSDKWindowContainer *)createAuthWindow {
    UIWindow *window = [self createDefaultUIWindow];
    SFSDKWindowContainer *container = [[SFSDKWindowContainer alloc] initWithWindow:window name:kSFLoginWindowKey];
    container.windowDelegate = self;
    container.windowType = SFSDKWindowTypeAuth;
    container.window.alpha = 1.0;
    [self.namedWindows setObject:container forKey:kSFLoginWindowKey];
    [self.reverseLookupTable setObject:container forKey:container.window];
    return container;
}

- (SFSDKWindowContainer *)createPasscodeWindow {
    UIWindow *window = [self createDefaultUIWindow];
    SFSDKWindowContainer *container = [[SFSDKWindowContainer alloc] initWithWindow:window name:kSFPasscodeWindowKey];
    container.windowDelegate = self;
    container.windowType = SFSDKWindowTypePasscode;
    container.window.alpha = 1.0;
    [self.namedWindows setObject:container forKey:kSFPasscodeWindowKey];
    [self.reverseLookupTable setObject:container forKey:container.window];
    return container;
}

-(UIWindow *)createDefaultUIWindow {
    UIWindow *window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    window.hidden = YES;
    window.backgroundColor = [UIColor whiteColor];
    window.rootViewController = [[SFSDKRootController alloc] init];
    return  window;
}

- (BOOL)isManaged:(UIWindow *) window {
    return [self.reverseLookupTable objectForKey:window]!=nil;
}

- (void)hideWindow:(SFSDKWindowContainer *)window {
    if (window.isSnapshotWindow) {
        window.window.hidden = YES;
        return;
    }
    window.window.hidden = YES;
    //Switch back to main window, any other window should present itself if needed.
    self.mainWindow.window.hidden = NO;
    [self.mainWindow.window makeKeyWindow];
}

- (void)showWindow:(SFSDKWindowContainer *)window {
    
    if (window) {
        window.window.hidden = NO;
        [window.window makeKeyWindow];
        if (window.isSnapshotWindow)
            return;
    }
    
    // hide all other windows
    NSInteger i = [SFApplicationHelper sharedApplication].windows.count - 1;
    for (; i >= 0; i--) {
        UIWindow *win = ([SFApplicationHelper sharedApplication].windows)[i];
        if (![self isManaged:win]) {
            continue;
        } else if (window.window == win) {
            continue;
        }
        else {
          win.hidden = YES;
        }
    }
}

- (UIWindow *)findActiveWindow {

    UIWindow *foundWindow = nil;
    for (NSInteger i = [SFApplicationHelper sharedApplication].windows.count - 1; i >= 0; i--) {
        UIWindow *win = ([SFApplicationHelper sharedApplication].windows)[i];
         if (!win.isKeyWindow || ![self isManaged:win]) {
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
