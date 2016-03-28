/*
 SFSDKLoginHostTests.m
 SalesforceSDKCore
 
 Created by Kunal Chitalia on 3/28/16.
 Copyright (c) 2016, salesforce.com, inc. All rights reserved.
 
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
#import "SFSDKLoginHost.h"

@interface SFSDKLoginHostTests : XCTestCase

@end

@implementation SFSDKLoginHostTests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testLoginHost{
    NSString *name = @"dummyname";
    NSString *host = @"dummyhost";
    BOOL deletable = YES;
    
    SFSDKLoginHost *loginHost = [SFSDKLoginHost hostWithName:name host:host deletable:deletable];
    
    XCTAssertEqualObjects(host, loginHost.host, @"%@ Should be equal to %@", host, loginHost.host);
    XCTAssertEqualObjects(name, loginHost.name, @"%@ Should be equal to %@", name, loginHost.name);
    XCTAssertEqual(deletable, loginHost.deletable, @"%d Should be equal to %d", deletable, loginHost.deletable);
    
    //Only testing name to be nil as host can never be nil and deletable will always have a YES or NO value
    loginHost = [SFSDKLoginHost hostWithName:nil host:host deletable:deletable];
    
    XCTAssertNotNil(loginHost.name, @"Name shoud not be nil");
    
}

@end
