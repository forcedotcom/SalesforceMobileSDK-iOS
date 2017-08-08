//
//  SFSDKWindowManagerTests.m
//  SalesforceSDKCore
//
//  Created by Raj Rao on 7/18/17.
//  Copyright © 2017 salesforce.com. All rights reserved.
//

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
     willEnableWindow:(SFSDKWindowContainer *_Nonnull)aWindow {
    _notificationWindow = aWindow;
    [_before fulfill];
    
}

- (void)windowManager:(SFSDKWindowManager *_Nonnull)windowManager
      didEnableWindow:(SFSDKWindowContainer *_Nonnull)aWindow {
    _notificationWindow = aWindow;
    [_after fulfill];
}

- (void)windowManager:(SFSDKWindowManager *_Nonnull)windowManager
    willDisableWindow:(SFSDKWindowContainer *_Nonnull)aWindow {
    _notificationWindow = aWindow;
    [_before fulfill];
}
- (void)windowManager:(SFSDKWindowManager *_Nonnull)windowManager
     didDisableWindow:(SFSDKWindowContainer *_Nonnull)aWindow {
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

- (void)windowEnable:(SFSDKWindowContainer *_Nonnull)window animated:(BOOL)animated withCompletion:(void (^_Nullable)(void))completion {
    [_enabledWindow fulfill];
}

- (void)windowDisable:(SFSDKWindowContainer *_Nonnull)window animated:(BOOL)animated withCompletion:(void (^_Nullable)(void))completion {
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
    XCTAssert(_origApplicationWindow!=nil);
    SFSDKWindowContainer *authWindow = [SFSDKWindowManager sharedManager].authWindow;
    XCTAssert(authWindow.window!=nil);
    XCTAssert(authWindow.windowType == SFSDKWindowTypeAuth);
}

- (void)testPasscodeWindow {
    XCTAssert(_origApplicationWindow!=nil);
    SFSDKWindowContainer *passcodeWindow = [SFSDKWindowManager sharedManager].passcodeWindow;
    XCTAssert(passcodeWindow.window!=nil);
    XCTAssert(passcodeWindow.windowType == SFSDKWindowTypePasscode);
}

- (void)testSnapshotWindow {
    XCTAssert(_origApplicationWindow!=nil);
    SFSDKWindowContainer *snapshotWindow = [SFSDKWindowManager sharedManager].snapshotWindow;
    XCTAssert(snapshotWindow.window!=nil);
    XCTAssert(snapshotWindow.windowType == SFSDKWindowTypeSnapshot);
}

- (void)testEnable {
    XCTAssert(_origApplicationWindow!=nil);
    SFSDKWindowContainer *passcodeWindow = [SFSDKWindowManager sharedManager].passcodeWindow;
    [passcodeWindow  enable];
    XCTAssert(passcodeWindow.window!=nil);
    XCTAssertTrue([passcodeWindow.window isKeyWindow]);
}


- (void)testDisable {
    XCTAssert(_origApplicationWindow!=nil);
    SFSDKWindowContainer *passcodeWindow = [SFSDKWindowManager sharedManager].passcodeWindow;
    [passcodeWindow  enable];
    XCTAssert(passcodeWindow.window!=nil);
    XCTAssertTrue([passcodeWindow.window isKeyWindow]);
    [passcodeWindow  disable:YES withCompletion:^{
        XCTAssertFalse(passcodeWindow.window.isKeyWindow);
    }];
    
}

- (void)testLevels {
    [SFSDKWindowManager sharedManager].snapshotWindow.window.windowLevel = 1;
    
    [SFSDKWindowManager sharedManager].passcodeWindow.window.windowLevel = 2;
    
    [SFSDKWindowManager sharedManager].authWindow.window.windowLevel = 3;
    
    XCTAssertTrue(
              [SFSDKWindowManager sharedManager].snapshotWindow.window.windowLevel >
                  [SFSDKWindowManager sharedManager].passcodeWindow.window.windowLevel );
    XCTAssertTrue([SFSDKWindowManager sharedManager].passcodeWindow.window.windowLevel >
                  [SFSDKWindowManager sharedManager].authWindow.window.windowLevel);
    XCTAssertTrue([SFSDKWindowManager sharedManager].authWindow.window.windowLevel >
                  [SFSDKWindowManager sharedManager].mainWindow.window.windowLevel);
        
}

- (void)testContainerDelegateCallback {
     SFSDKWindowContainerDelegateTest *delegate = [SFSDKWindowContainerDelegateTest new];
    delegate.enabledWindow = [[XCTestExpectation alloc] initWithDescription:@"Enabled"];
    
    delegate.disabledWindow = [[XCTestExpectation alloc] initWithDescription:@"Disabled"];
    
    SFSDKWindowContainer *container = [[SFSDKWindowManager sharedManager] createNewNamedWindow:@"Sample"];
    container.windowDelegate = delegate;
    
    XCTAssertNotNil(container);
    XCTAssertNotNil(container.window);
    XCTAssertNotNil(container.windowDelegate);
    
    container= [[SFSDKWindowManager sharedManager] windowWithName:@"Sample"];
    
    XCTAssertNotNil(container);
    
    [container enable];
    
    [self waitForExpectations:@[delegate.enabledWindow] timeout:2];
    [container disable];
    [self waitForExpectations:@[delegate.disabledWindow] timeout:2];
    
}

- (void)testCompletionBlockForEnable {
    
    XCTestExpectation *completionBlock  = [[XCTestExpectation alloc] initWithDescription:@"CompletionBlockCalled"];
    [[SFSDKWindowManager sharedManager].authWindow enable:YES withCompletion:^{
        [completionBlock fulfill];
    }];
    [self waitForExpectations:@[completionBlock] timeout:2];

}

- (void)testCompletionBlockForDisable {
    
    XCTestExpectation *completionBlock  = [[XCTestExpectation alloc] initWithDescription:@"CompletionBlockCalled"];
    [[SFSDKWindowManager sharedManager].authWindow disable:YES withCompletion:^{
        [completionBlock fulfill];
    }];
    [self waitForExpectations:@[completionBlock] timeout:2];
    
}

- (void)testDelegate {
 
    SFSDKWindowManagerDelegateTest *delegate = [SFSDKWindowManagerDelegateTest new];
    delegate.before = [[XCTestExpectation alloc] initWithDescription:@"BeforeEnablement"];
     delegate.after = [[XCTestExpectation alloc] initWithDescription:@"AfterEnablement"];
    
    [[SFSDKWindowManager sharedManager] addDelegate:delegate];
    [[SFSDKWindowManager sharedManager].authWindow enable];
    
    [self waitForExpectations:@[delegate.before,delegate.after] timeout:2];
    
    delegate.before = [[XCTestExpectation alloc] initWithDescription:@"BeforeDisablement"];
    delegate.after = [[XCTestExpectation alloc] initWithDescription:@"AfterDisablement"];
    
    [[SFSDKWindowManager sharedManager].authWindow disable];
    [self waitForExpectations:@[delegate.before,delegate.after] timeout:2];
    
    XCTAssertTrue([SFSDKWindowManager sharedManager].authWindow == delegate.notificationWindow);
    
}
@end
