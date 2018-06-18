/*
 Copyright (c) 2018-present, salesforce.com, inc. All rights reserved.
 
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
#import "NSString+SFAdditions.h"

#define ME @"me"
#define OTHER_ME @"ME"

#define USER_A_ID_15 @"005300000040EVc"
#define USER_B_ID_15 @"005300000040EvC"

#define USER_A_ID_18 @"005300000040EVcAAM"
#define USER_B_ID_18 @"005300000040EvCAAU"


@interface NSString_SFAdditionsTests : XCTestCase
@end

@implementation NSString_SFAdditionsTests

#pragma mark - NSString+SFAdditionsTests tests

- (void)testEntityId18
{
    XCTAssertEqual([USER_A_ID_18 compare:[USER_A_ID_15 entityId18]], NSOrderedSame);
    XCTAssertEqual([USER_B_ID_18 compare:[USER_B_ID_15 entityId18]], NSOrderedSame);
}

- (void)testIsEqualToEntityId
{
    XCTAssertTrue([@"" isEqualToEntityId:@""]);
    XCTAssertTrue([ME isEqualToEntityId:ME]);
    XCTAssertTrue([ME isEqualToEntityId:OTHER_ME]);
    XCTAssertTrue([OTHER_ME isEqualToEntityId:ME]);

    XCTAssertTrue([USER_A_ID_15 isEqualToEntityId:USER_A_ID_15]);
    XCTAssertTrue([USER_A_ID_15 isEqualToEntityId:USER_A_ID_18]);
    XCTAssertTrue([USER_A_ID_18 isEqualToEntityId:USER_A_ID_15]);
    XCTAssertTrue([USER_A_ID_18 isEqualToEntityId:USER_A_ID_18]);

    XCTAssertTrue([USER_B_ID_15 isEqualToEntityId:USER_B_ID_15]);
    XCTAssertTrue([USER_B_ID_15 isEqualToEntityId:USER_B_ID_18]);
    XCTAssertTrue([USER_B_ID_18 isEqualToEntityId:USER_B_ID_15]);
    XCTAssertTrue([USER_B_ID_18 isEqualToEntityId:USER_B_ID_18]);

    XCTAssertFalse([USER_A_ID_15 isEqualToEntityId:@""]);
    XCTAssertFalse([USER_A_ID_15 isEqualToEntityId:ME]);
    XCTAssertFalse([USER_A_ID_15 isEqualToEntityId:OTHER_ME]);
    XCTAssertFalse([USER_A_ID_15 isEqualToEntityId:USER_B_ID_15]);
    XCTAssertFalse([USER_A_ID_15 isEqualToEntityId:USER_B_ID_18]);

    XCTAssertFalse([@"" isEqualToEntityId:USER_A_ID_15]);
    XCTAssertFalse([ME isEqualToEntityId:USER_A_ID_15]);
    XCTAssertFalse([OTHER_ME isEqualToEntityId:USER_A_ID_15]);
    XCTAssertFalse([USER_B_ID_15 isEqualToEntityId:USER_A_ID_15]);
    XCTAssertFalse([USER_B_ID_18 isEqualToEntityId:USER_A_ID_15]);

}

@end
