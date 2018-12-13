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
    XCTAssertTrue([SFSDKWindowManager sharedManager].mainWindow.window==_origApplicationWindow);
}

- (void)testLoginWindow {
    SFSDKWindowContainer *authWindow = [SFSDKWindowManager sharedManager].authWindow;
    XCTAssert(authWindow.window!=nil);
    XCTAssert(authWindow.windowType == SFSDKWindowTypeAuth);
}

- (void)testPasscodeWindow {
    SFSDKWindowContainer *passcodeWindow = [SFSDKWindowManager sharedManager].passcodeWindow;
    XCTAssert(passcodeWindow.window!=nil);
    XCTAssert(passcodeWindow.windowType == SFSDKWindowTypePasscode);
}

- (void)testSnapshotWindow {
    SFSDKWindowContainer *snapshotWindow = [SFSDKWindowManager sharedManager].snapshotWindow;
    XCTAssert(snapshotWindow.window!=nil);
    XCTAssert(snapshotWindow.windowType == SFSDKWindowTypeSnapshot);
}

- (void)testEnable {
    SFSDKWindowContainer *passcodeWindow = [SFSDKWindowManager sharedManager].passcodeWindow;
    [passcodeWindow presentWindow];
    XCTAssert(passcodeWindow.window!=nil);
    XCTAssertTrue([passcodeWindow.window isKeyWindow]);
}


- (void)testDisable {
    SFSDKWindowContainer *passcodeWindow = [SFSDKWindowManager sharedManager].passcodeWindow;
    [passcodeWindow presentWindow];
    XCTAssert(passcodeWindow.window!=nil);
    XCTAssertTrue([passcodeWindow.window isKeyWindow]);
    [passcodeWindow dismissWindowAnimated:NO  withCompletion:^{
        XCTAssertFalse(passcodeWindow.window.isKeyWindow);
    }];
    
}

- (void)testActive {
    XCTestExpectation *expectation = [self expectationWithDescription:@"ActiveWindow"];
    
    SFSDKWindowContainer *passcodeWindow = [SFSDKWindowManager sharedManager].passcodeWindow;
    [passcodeWindow presentWindow];
    SFSDKWindowContainer *activeWindow = [SFSDKWindowManager sharedManager].activeWindow;
    XCTAssert(passcodeWindow==activeWindow);
    [passcodeWindow dismissWindowAnimated:NO withCompletion:^{
        XCTAssertFalse(passcodeWindow.window.isKeyWindow);
        [expectation fulfill];
    }];
    [self waitForExpectations:@[expectation] timeout:10];
    activeWindow = [SFSDKWindowManager sharedManager].activeWindow;
    XCTAssert(passcodeWindow!=activeWindow);
    
}

- (void)testLevels {
    // these 3 statements should not make any difference
    [SFSDKWindowManager sharedManager].snapshotWindow.window.windowLevel = 1;
    [SFSDKWindowManager sharedManager].passcodeWindow.window.windowLevel = 4;
    [SFSDKWindowManager sharedManager].authWindow.window.windowLevel = 3;
    XCTAssertTrue(
                  [SFSDKWindowManager sharedManager].snapshotWindow.windowLevel !=1  );
    XCTAssertTrue([SFSDKWindowManager sharedManager].passcodeWindow.windowLevel != 4);
    XCTAssertTrue([SFSDKWindowManager sharedManager].authWindow.windowLevel != 3);
   
}

- (void)testCompletionBlockForEnable {
    
    XCTestExpectation *completionBlock  = [[XCTestExpectation alloc] initWithDescription:@"CompletionBlockCalled"];
    [[SFSDKWindowManager sharedManager].authWindow presentWindowAnimated:NO withCompletion:^{
        [completionBlock fulfill];
    }];
    [self waitForExpectations:@[completionBlock] timeout:2];
    
}

- (void)testCompletionBlockForDisable {
    
    XCTestExpectation *completionBlock  = [[XCTestExpectation alloc] initWithDescription:@"CompletionBlockCalled"];
    [[SFSDKWindowManager sharedManager].authWindow presentWindow];
    [[SFSDKWindowManager sharedManager].authWindow dismissWindowAnimated:NO withCompletion:^{
        [completionBlock fulfill];
    }];
    [self waitForExpectations:@[completionBlock] timeout:2];
    
}

- (void)testDelegate {
    
    SFSDKWindowManagerDelegateTest *delegate = [SFSDKWindowManagerDelegateTest new];
    delegate.before = [[XCTestExpectation alloc] initWithDescription:@"BeforeEnablement"];
    delegate.after = [[XCTestExpectation alloc] initWithDescription:@"AfterEnablement"];
    
    [[SFSDKWindowManager sharedManager] addDelegate:delegate];
    [[SFSDKWindowManager sharedManager].authWindow presentWindow];
    
    [self waitForExpectations:@[delegate.before,delegate.after] timeout:2];
    
    delegate.before = [[XCTestExpectation alloc] initWithDescription:@"BeforeDisablement"];
    delegate.after = [[XCTestExpectation alloc] initWithDescription:@"AfterDisablement"];
    
    [[SFSDKWindowManager sharedManager].authWindow dismissWindow];
    [self waitForExpectations:@[delegate.before,delegate.after] timeout:2];
    
    XCTAssertTrue(delegate.notificationWindow.isAuthWindow);
    
}
@end
