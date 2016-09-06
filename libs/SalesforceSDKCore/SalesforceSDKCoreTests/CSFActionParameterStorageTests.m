/*
 Copyright (c) 2015-present, salesforce.com, inc. All rights reserved.
 
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
#import <SalesforceSDKCore/SalesforceSDKCore.h>
#import "CSFParameterStorage_Internal.h"

@interface CSFParameterStorageTests : XCTestCase

@end

@implementation CSFParameterStorageTests

- (void)testQueryStringParameters {
    NSArray *expectedArray = nil;
    
    CSFParameterStorage *storage = [[CSFParameterStorage alloc] init];
    XCTAssertEqual(storage.parameterStyle, CSFParameterStyleNone);
    XCTAssertEqual(storage.allKeys.count, 0U);
    
    expectedArray = @[ @"firstname" ];
    [storage setObject:@"Michael" forKey:@"firstname"];
    XCTAssertEqualObjects([storage.allKeys sortedArrayUsingSelector:@selector(compare:)], expectedArray);
    XCTAssertEqualObjects([storage mimeTypeForKey:@"firstname"], nil);
    XCTAssertEqualObjects([storage fileNameForKey:@"firstname"], nil);
    XCTAssertEqualObjects([storage objectForKey:@"firstname"], @"Michael");
    XCTAssertEqualObjects(storage[@"firstname"], @"Michael");
    XCTAssertEqual(storage.parameterStyle, CSFParameterStyleQueryString);
    
    expectedArray = @[ @"firstname", @"lastname" ];
    storage[@"lastname"] = @"Nachbaur";
    XCTAssertEqualObjects([storage.allKeys sortedArrayUsingSelector:@selector(compare:)], expectedArray);
    XCTAssertEqualObjects([storage mimeTypeForKey:@"lastname"], nil);
    XCTAssertEqualObjects([storage fileNameForKey:@"lastname"], nil);
    XCTAssertEqualObjects([storage objectForKey:@"lastname"], @"Nachbaur");
    XCTAssertEqualObjects(storage[@"lastname"], @"Nachbaur");
    XCTAssertEqual(storage.parameterStyle, CSFParameterStyleQueryString);
    
    NSError *error = nil;
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:@"http://example.org/api"]];
    request.HTTPMethod = @"GET";
    
    BOOL success = [storage bindParametersToRequest:request error:&error];
    XCTAssertTrue(success);
    XCTAssertNil(error);
    
    XCTAssertNil(request.HTTPBody);
    XCTAssertNil(request.HTTPBodyStream);
    XCTAssertEqualObjects(request.URL, [NSURL URLWithString:@"http://example.org/api?firstname=Michael&lastname=Nachbaur"]);
}

- (void)testMultipartParameterStyle {
    NSArray *expectedArray = nil;
    
    CSFParameterStorage *storage = [[CSFParameterStorage alloc] init];
    XCTAssertEqual(storage.parameterStyle, CSFParameterStyleNone);
    XCTAssertEqual(storage.allKeys.count, 0U);
    
    expectedArray = @[ @"firstname" ];
    [storage setObject:@"Michael" forKey:@"firstname"];
    XCTAssertEqualObjects([storage.allKeys sortedArrayUsingSelector:@selector(compare:)], expectedArray);
    XCTAssertEqualObjects([storage mimeTypeForKey:@"firstname"], nil);
    XCTAssertEqualObjects([storage fileNameForKey:@"firstname"], nil);
    XCTAssertEqualObjects([storage objectForKey:@"firstname"], @"Michael");
    XCTAssertEqualObjects(storage[@"firstname"], @"Michael");
    XCTAssertEqual(storage.parameterStyle, CSFParameterStyleQueryString);
    
    expectedArray = @[ @"firstname", @"lastname" ];
    storage[@"lastname"] = @"Nachbaur";
    XCTAssertEqualObjects([storage.allKeys sortedArrayUsingSelector:@selector(compare:)], expectedArray);
    XCTAssertEqualObjects([storage mimeTypeForKey:@"lastname"], nil);
    XCTAssertEqualObjects([storage fileNameForKey:@"lastname"], nil);
    XCTAssertEqualObjects([storage objectForKey:@"lastname"], @"Nachbaur");
    XCTAssertEqualObjects(storage[@"lastname"], @"Nachbaur");
    XCTAssertEqual(storage.parameterStyle, CSFParameterStyleQueryString);

    [storage setFileName:@"Name.txt" forKey:@"lastname"];
    XCTAssertEqual(storage.parameterStyle, CSFParameterStyleMultipart);

    NSError *error = nil;
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:@"http://example.org/api"]];
    request.HTTPMethod = @"POST";
    
    BOOL success = [storage bindParametersToRequest:request error:&error];
    XCTAssertTrue(success);
    XCTAssertNil(error);

    XCTAssertNil(request.HTTPBody);
    XCTAssertNotNil(request.HTTPBodyStream);
    XCTAssertEqualObjects(request.URL, [NSURL URLWithString:@"http://example.org/api"]);
    
    NSString *multipartBoundary = [request valueForHTTPHeaderField:@"Content-Type"];
    NSRange boundaryRange = [multipartBoundary rangeOfString:@"boundary="];
    NSString *boundary = nil;
    if (boundaryRange.location != NSNotFound) {
        boundary = [multipartBoundary substringFromIndex:NSMaxRange(boundaryRange)];
    }
    
    uint8_t *buffer = malloc(sizeof(uint8_t) * 1024);
    NSMutableData *data = [NSMutableData new];
    
    [request.HTTPBodyStream open];
    while ([request.HTTPBodyStream hasBytesAvailable]) {
        NSInteger readCount = [request.HTTPBodyStream read:buffer maxLength:1024];
        [data appendBytes:buffer length:readCount];
    }
    free(buffer);
    
    NSString *stringData = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSMutableString *expectedString = [NSMutableString new];
    [expectedString appendFormat:@"--%@\r\nContent-Disposition: form-data; name=\"firstname\"\r\n\r\nMichael\r\n", boundary];
    [expectedString appendFormat:@"--%@\r\nContent-Disposition: form-data; name=\"lastname\"; filename=\"Name.txt\"\r\nContent-Type: text/plain\r\n\r\nNachbaur\r\n", boundary];
    [expectedString appendFormat:@"--%@--\r\n", boundary];
    XCTAssertEqualObjects(stringData, expectedString);
}

@end
