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
#import "SFHybridViewConfig.h"

@interface SFHybridViewConfigTestSuite : XCTestCase

@property (nonnull, nonatomic, strong) SFHybridViewConfig *hybridViewConfig;

@end

@implementation SFHybridViewConfigTestSuite

- (void)setUp {
    [super setUp];
    [self setupHybridViewConfig];
}

- (void)testStartPageMustExist {
    self.hybridViewConfig.startPage = @"";
    [self validateViewConfigWithErrorCode:SFSDKHybridAppConfigErrorCodeNoStartPage];
}

- (void)testStartPageIsRelativeUrl {
    self.hybridViewConfig.startPage = @"https://www.example.com";
    [self validateViewConfigWithErrorCode:SFSDKHybridAppConfigErrorCodeStartPageAbsoluteURL];
}

- (void)testUnauthenticatedStartPageIsAbsoluteURL {
    self.hybridViewConfig.unauthenticatedStartPage = @"/blah.html";
    [self validateViewConfigWithErrorCode:SFSDKHybridAppConfigErrorCodeUnauthenticatedStartPageNotAbsoluteURL];
}

- (void)testRemoteWithDeferredAuthNoUnauthenticatedStartPage {
    self.hybridViewConfig.isLocal = NO;
    self.hybridViewConfig.shouldAuthenticate = NO;
    self.hybridViewConfig.unauthenticatedStartPage = nil;
    [self validateViewConfigWithErrorCode:SFSDKHybridAppConfigErrorCodeNoUnauthenticatedStartPage];
}

#pragma mark - Private methods

- (void)setupHybridViewConfig {
    self.hybridViewConfig = [[SFHybridViewConfig alloc] init];
    self.hybridViewConfig.remoteAccessConsumerKey = @"testConsumerKey";
    self.hybridViewConfig.oauthRedirectURI = @"test:///redirectUri";
    self.hybridViewConfig.oauthScopes = [NSSet setWithArray:@[ @"web", @"api" ]];
}

- (void)validateViewConfigWithErrorCode:(SFSDKHybridAppConfigErrorCode)expectedCode {
    NSError *configError = nil;
    BOOL validateResult = [self.hybridViewConfig validate:&configError];
    XCTAssertFalse(validateResult, @"Validation should have failed.");
    XCTAssertNotNil(configError, @"Should be a validation error.");
    XCTAssertEqualObjects(configError.domain, SFSDKAppConfigErrorDomain, @"Wrong error domain.");
    XCTAssertEqual(configError.code, expectedCode, @"Wrong error code.");
}

@end
