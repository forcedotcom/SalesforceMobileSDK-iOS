//
//  SalesforceKit_iOSTests.m
//  SalesforceKit-iOSTests
//
//  Created by Michael Nachbaur on 7/19/15.
//
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>

@import SalesforceKit;

@interface SalesforceKit_iOSTests : XCTestCase
@end

@implementation SalesforceKit_iOSTests

- (void)testSymbols {
    XCTAssertEqualObjects(NSStringFromClass([SFUserAccountManager class]), @"SFUserAccountManager");
    XCTAssertEqualObjects(NSStringFromClass([SFOAuthCredentials class]), @"SFOAuthCredentials");
    XCTAssertEqualObjects(NSStringFromClass([SFSmartStore class]), @"SFSmartStore");
    XCTAssertEqualObjects(NSStringFromClass([CSFNetwork class]), @"CSFNetwork");
}

@end
