//
//  SFSDKWindowManagerTests.m
//  SalesforceSDKCore
//
//  Created by Raj Rao on 7/18/17.
//  Copyright © 2017 salesforce.com. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "SFSDKWindowManager.h"

@interface SFSDKWindowManagerTests : XCTestCase{
    UIWindow *_origApplicationWindow;
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
    XCTAssert([SFSDKWindowManager sharedManager].mainWindow.window==_origApplicationWindow);
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

- (void)testBringToFront {
    XCTAssert(_origApplicationWindow!=nil);
    SFSDKWindowContainer *passcodeWindow = [SFSDKWindowManager sharedManager].snapshotWindow;
    [[SFSDKWindowManager sharedManager] bringToFront:passcodeWindow];
    XCTAssert(passcodeWindow.window!=nil);
    XCTAssertTrue([passcodeWindow.window isKeyWindow]);
}

@end
