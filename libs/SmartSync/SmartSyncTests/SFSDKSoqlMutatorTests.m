/*
Copyright (c) 2019-present, salesforce.com, inc. All rights reserved.

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
#import "SFSDKSoqlMutator.h"


@interface SFSDKSoqlMutatorTests : XCTestCase

@end


@implementation SFSDKSoqlMutatorTests

- (void) testMutatorNoChange {
    NSString* originalSoql = @"select Id, Name from Account where Id in (select Id from Account) and Name like 'Mad Max' limit 1000";
    NSString* mutatedSoql = [[[[SFSDKSoqlMutator alloc] init:originalSoql] asBuilder] build];
    NSString* expectedSoql = originalSoql;
    XCTAssertEqualObjects(expectedSoql, mutatedSoql);
}

- (void) testReplaceSelectFiel {
    NSString* originalSoql = @"SELECT Description FROM Account";
    NSString* mutatedSoql = [[[[[SFSDKSoqlMutator alloc] init:originalSoql] replaceSelectFields:@"Id"] asBuilder] build];
    NSString* expectedSoql = @"select Id from Account";
    XCTAssertEqualObjects(expectedSoql, mutatedSoql);
}



@end
