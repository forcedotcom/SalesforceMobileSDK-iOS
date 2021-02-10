/*
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


#import <XCTest/XCTest.h>
#import "SFSDKWindowManager.h"
#import "SFApplicationHelper.h"

@interface SFSDKWindowManagerTests: XCTestCase{
    UIWindow *_origApplicationWindow;
}

@end

@interface SFSDKWindowManagerDelegateTest: NSObject<SFSDKWindowManagerDelegate>
@property (nonatomic,nonnull) XCTestExpectation *before;
@property (nonatomic,nonnull) XCTestExpectation *after;
@property (nonatomic,nonnull) SFSDKWindowContainer *notificationWindow;
@end

@implementation SFSDKWindowManagerDelegateTest

- (void)windowManager:(SFSDKWindowManager *_Nonnull)windowManager
    willPresentWindow:(SFSDKWindowContainer *_Nonnull)aWindow {
    _notificationWindow = aWindow;
    [_before fulfill];
    
}

- (void)windowManager:(SFSDKWindowManager *_Nonnull)windowManager
     didPresentWindow:(SFSDKWindowContainer *_Nonnull)aWindow {
    _notificationWindow = aWindow;
    [_after fulfill];
}

- (void)windowManager:(SFSDKWindowManager *_Nonnull)windowManager
    willDismissWindow:(SFSDKWindowContainer *_Nonnull)aWindow {
    _notificationWindow = aWindow;
    [_before fulfill];
}
- (void)windowManager:(SFSDKWindowManager *_Nonnull)windowManager
     didDismissWindow:(SFSDKWindowContainer *_Nonnull)aWindow {
    _notificationWindow = aWindow;
    [_after fulfill];
}
@end

@interface SFSDKWindowContainerDelegateTest: NSObject<SFSDKWindowContainerDelegate>

@property (nonatomic,nonnull) XCTestExpectation *enabledWindow;
@property (nonatomic,nonnull) XCTestExpectation *disabledWindow;
@property (nonatomic,nonnull) SFSDKWindowContainer *notificationWindow;
@end

@implementation SFSDKWindowContainerDelegateTest

- (void)presentWindow:(SFSDKWindowContainer *)window withCompletion:(void (^_Nullable)(void))completion {
    [_enabledWindow fulfill];
}

- (void)dismissWindow:(SFSDKWindowContainer *)window withCompletion:(void (^_Nullable)(void))completion {
    [_disabledWindow fulfill];
}

@end

@implementation SFSDKWindowManagerTests

- (void)setUp {
    [super setUp];
    _origApplicationWindow = [UIApplication sharedApplication].keyWindow;
}

- (void)tearDown {
    [_origApplicationWindow makeKeyAndVisible];
    [super tearDown];
}

- (void)testSetMainWindow {
    XCTAssert(_origApplicationWindow!=nil);
    [[SFSDKWindowManager sharedManager] setMainUIWindow:_origApplicationWindow];
    XCTAssert([[SFSDKWindowManager sharedManager] mainWindow: nil].window == _origApplicationWindow);
    XCTAssert([[SFSDKWindowManager sharedManager] mainWindow:nil].window == _origApplicationWindow);
    UIScene *scene = [SFApplicationHelper sharedApplication].connectedScenes.allObjects.firstObject;
    XCTAssert([[SFSDKWindowManager sharedManager] mainWindow:scene].window == _origApplicationWindow);
}

- (void)testLoginWindow {
    SFSDKWindowContainer *authWindowNilScene = [[SFSDKWindowManager sharedManager] authWindow:nil];
    XCTAssert(authWindowNilScene.window != nil);
    XCTAssert(authWindowNilScene.windowType == SFSDKWindowTypeAuth);
    
    UIScene *scene = [SFApplicationHelper sharedApplication].connectedScenes.allObjects.firstObject;
    SFSDKWindowContainer *authWindowScene = [[SFSDKWindowManager sharedManager] authWindow:scene];
    XCTAssert(authWindowScene.window != nil);
    XCTAssert(authWindowScene.windowType == SFSDKWindowTypeAuth);
    XCTAssertEqualObjects(authWindowNilScene, authWindowScene);
}

- (void)testPasscodeWindow {
    SFSDKWindowContainer *passcodeWindow = [SFSDKWindowManager sharedManager].passcodeWindow;
    XCTAssert(passcodeWindow.window!=nil);
    XCTAssert(passcodeWindow.windowType == SFSDKWindowTypePasscode);
}

- (void)testSnapshotWindow {
    SFSDKWindowContainer *snapshotWindowNilScene = [[SFSDKWindowManager sharedManager] snapshotWindow:nil];
    XCTAssert(snapshotWindowNilScene.window != nil);
    XCTAssert(snapshotWindowNilScene.windowType == SFSDKWindowTypeSnapshot);
    
    UIScene *scene = [SFApplicationHelper sharedApplication].connectedScenes.allObjects.firstObject;
    SFSDKWindowContainer *snapshowWindowScene = [[SFSDKWindowManager sharedManager] snapshotWindow:scene];
    XCTAssert(snapshowWindowScene.window != nil);
    XCTAssert(snapshowWindowScene.windowType == SFSDKWindowTypeSnapshot);
    XCTAssertEqualObjects(snapshotWindowNilScene, snapshowWindowScene);
}

- (void)testEnable {
    SFSDKWindowContainer *passcodeWindow = [SFSDKWindowManager sharedManager].passcodeWindow;
    [passcodeWindow presentWindow];
    XCTAssert(passcodeWindow.window!=nil);
    XCTAssertTrue([passcodeWindow.window isKeyWindow]);
    XCTAssertTrue(passcodeWindow.isEnabled);
}

- (void)testDisable {
    SFSDKWindowContainer *passcodeWindow = [SFSDKWindowManager sharedManager].passcodeWindow;
    [passcodeWindow presentWindow];
    XCTAssert(passcodeWindow.window!=nil);
    XCTAssertTrue([passcodeWindow.window isKeyWindow]);
    [passcodeWindow dismissWindowAnimated:NO  withCompletion:^{
        XCTAssertFalse(passcodeWindow.window.isKeyWindow);
        XCTAssertFalse(passcodeWindow.isEnabled);
    }];
}

- (void)testStyleOverride {
    SFSDKWindowContainer *snapshotWindow = [[SFSDKWindowManager sharedManager] snapshotWindow:nil];
    SFSDKWindowContainer *passcodeWindow = [[SFSDKWindowManager sharedManager] passcodeWindow];

    // Check default
    XCTAssertEqual(snapshotWindow.window.overrideUserInterfaceStyle, UIUserInterfaceStyleUnspecified);
    XCTAssertEqual(passcodeWindow.window.overrideUserInterfaceStyle, UIUserInterfaceStyleUnspecified);

    // Set it directly
    [SFSDKWindowManager sharedManager].userInterfaceStyle = UIUserInterfaceStyleDark;
    XCTAssertEqual(snapshotWindow.window.overrideUserInterfaceStyle, UIUserInterfaceStyleDark);
    XCTAssertEqual(passcodeWindow.window.overrideUserInterfaceStyle, UIUserInterfaceStyleDark);
}

- (void)testActive {
    XCTestExpectation *expectation = [self expectationWithDescription:@"ActiveWindow"];
    
    SFSDKWindowContainer *passcodeWindow = [SFSDKWindowManager sharedManager].passcodeWindow;
    [passcodeWindow presentWindow];
    SFSDKWindowContainer *activeWindow = [[SFSDKWindowManager sharedManager] activeWindow:nil];
    XCTAssert(passcodeWindow==activeWindow);
    [passcodeWindow dismissWindowAnimated:NO withCompletion:^{
        XCTAssertFalse(passcodeWindow.window.isKeyWindow);
        [expectation fulfill];
    }];
    [self waitForExpectations:@[expectation] timeout:10];
    activeWindow = [[SFSDKWindowManager sharedManager] activeWindow:nil];
    XCTAssert(passcodeWindow!=activeWindow);

}

- (void)testLevels {
    // these 3 statements should not make any difference
    [[SFSDKWindowManager sharedManager] snapshotWindow:nil].window.windowLevel = 1;
    [[SFSDKWindowManager sharedManager] passcodeWindow].window.windowLevel = 4;
    [[SFSDKWindowManager sharedManager] authWindow:nil].window.windowLevel = 3;
    XCTAssertTrue([[SFSDKWindowManager sharedManager] snapshotWindow:nil].windowLevel != 1);
    XCTAssertTrue([[SFSDKWindowManager sharedManager] passcodeWindow].windowLevel != 4);
    XCTAssertTrue([[SFSDKWindowManager sharedManager] authWindow:nil].windowLevel != 3);
   
}

- (void)testCompletionBlockForEnable {
    XCTestExpectation *completionBlock  = [[XCTestExpectation alloc] initWithDescription:@"CompletionBlockCalled"];
    [[[SFSDKWindowManager sharedManager] authWindow:nil] presentWindowAnimated:NO withCompletion:^{
        [completionBlock fulfill];
    }];
    [self waitForExpectations:@[completionBlock] timeout:2];
    
}

- (void)testCompletionBlockForDisable {
    
    XCTestExpectation *completionBlock = [[XCTestExpectation alloc] initWithDescription:@"CompletionBlockCalled"];
    [[[SFSDKWindowManager sharedManager] authWindow:nil] presentWindow];
    [[[SFSDKWindowManager sharedManager] authWindow:nil] dismissWindowAnimated:NO withCompletion:^{
        [completionBlock fulfill];
    }];
    [self waitForExpectations:@[completionBlock] timeout:2];
    
}

- (void)testDelegate {
    
    SFSDKWindowManagerDelegateTest *delegate = [SFSDKWindowManagerDelegateTest new];
    delegate.before = [[XCTestExpectation alloc] initWithDescription:@"BeforeEnablement"];
    delegate.after = [[XCTestExpectation alloc] initWithDescription:@"AfterEnablement"];
    
    [[SFSDKWindowManager sharedManager] addDelegate:delegate];
    [[[SFSDKWindowManager sharedManager] authWindow:nil] presentWindow];
    
    [self waitForExpectations:@[delegate.before,delegate.after] timeout:2];
    
    delegate.before = [[XCTestExpectation alloc] initWithDescription:@"BeforeDisablement"];
    delegate.after = [[XCTestExpectation alloc] initWithDescription:@"AfterDisablement"];
    
    [[[SFSDKWindowManager sharedManager] authWindow:nil] dismissWindow];
    [self waitForExpectations:@[delegate.before,delegate.after] timeout:2];
    
    XCTAssertTrue(delegate.notificationWindow.isAuthWindow);
    
}
@end
