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

#import "CSFInputStreamElement.h"

@interface CSFInputStreamElementTests : XCTestCase

@end

@implementation CSFInputStreamElementTests

- (void)testStringInputElement {
    CSFInputStreamElement *element = nil;
    
    element = [[CSFInputStreamElement alloc] initWithObject:@"Test String" boundary:@"FOO123" key:@"name"];
    XCTAssertEqualObjects(element.key, @"name");
    XCTAssertEqualObjects(element.boundary, @"FOO123");
    XCTAssertNil(element.mimeType);
    XCTAssertNil(element.filename);
    XCTAssertEqual(element.bodyLength, 11U);
    XCTAssertEqual(element.headerLength, 57U);
    XCTAssertEqual(element.length, 70U);
    XCTAssertEqual(element.delivered, 0U);
    
    uint8_t *buffer = malloc(sizeof(uint8_t) * element.length);
    NSMutableData *data = [NSMutableData dataWithCapacity:element.length];
    
    NSInteger readCount = [element read:buffer maxLength:15];
    XCTAssertEqual(readCount, 15U);
    [data appendBytes:buffer length:readCount];
    
    readCount = [element read:buffer maxLength:50];
    XCTAssertEqual(readCount, 50U);
    [data appendBytes:buffer length:readCount];
    
    readCount = [element read:buffer maxLength:15];
    XCTAssertEqual(readCount, 5U);
    [data appendBytes:buffer length:readCount];
    
    NSString *stringData = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(stringData, @"--FOO123\r\nContent-Disposition: form-data; name=\"name\"\r\n\r\nTest String\r\n");
}

- (void)testDateInputElement {
    CSFInputStreamElement *element = nil;
    
    NSDateFormatter *dateFormatter = [NSDateFormatter new];
    dateFormatter.dateStyle = NSDateFormatterFullStyle;
    dateFormatter.timeStyle = NSDateFormatterFullStyle;

    NSDate *date = [dateFormatter dateFromString:@"Friday, July 24, 2015 at 7:21:02 AM Hawaii-Aleutian Standard Time"];
    element = [[CSFInputStreamElement alloc] initWithObject:date
                                                   boundary:@"FOO123"
                                                        key:@"date"];
    XCTAssertEqualObjects(element.key, @"date");
    XCTAssertEqualObjects(element.boundary, @"FOO123");
    XCTAssertNil(element.mimeType);
    XCTAssertNil(element.filename);
    XCTAssertEqual(element.bodyLength, 20U);
    XCTAssertEqual(element.headerLength, 57U);
    XCTAssertEqual(element.length, 79U);
    XCTAssertEqual(element.delivered, 0U);
    
    uint8_t *buffer = malloc(sizeof(uint8_t) * element.length);
    NSInteger readCount = [element read:buffer maxLength:element.length];
    XCTAssertEqual(readCount, 79U);
    
    dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss";
    NSString *dateString = [dateFormatter stringFromDate:date];
    
    NSString *stringData = [[NSString alloc] initWithBytesNoCopy:buffer length:element.length encoding:NSUTF8StringEncoding freeWhenDone:YES];
    NSString *expectedString = [NSString stringWithFormat:@"--FOO123\r\nContent-Disposition: form-data; name=\"date\"\r\n\r\n%@Z\r\n",dateString];
    XCTAssertEqualObjects(stringData, expectedString);
}

- (void)testStringWithMimeTypeInputElement {
    CSFInputStreamElement *element = nil;
    
    element = [[CSFInputStreamElement alloc] initWithObject:@"{\"json\":\"value\"}"
                                                   boundary:@"TESTING123"
                                                        key:@"jsonData"
                                                   mimeType:@"application/json"
                                                   filename:nil];
    XCTAssertEqualObjects(element.key, @"jsonData");
    XCTAssertEqualObjects(element.boundary, @"TESTING123");
    XCTAssertEqualObjects(element.mimeType, @"application/json");
    XCTAssertNil(element.filename);
    
    uint8_t *buffer = malloc(sizeof(uint8_t) * element.length);
    NSInteger readCount = [element read:buffer maxLength:element.length];
    XCTAssertEqual(readCount, 115U);
    
    NSString *stringData = [[NSString alloc] initWithBytesNoCopy:buffer length:element.length encoding:NSUTF8StringEncoding freeWhenDone:YES];
    XCTAssertEqualObjects(stringData, @"--TESTING123\r\nContent-Disposition: form-data; name=\"jsonData\"\r\nContent-Type: application/json\r\n\r\n{\"json\":\"value\"}\r\n");
}

- (void)testStringWithFileAndNoMimeTypeInputElement {
    CSFInputStreamElement *element = nil;
    
    element = [[CSFInputStreamElement alloc] initWithObject:@"{\"json\":\"value\"}"
                                                   boundary:@"TESTING123"
                                                        key:@"jsonData"
                                                   mimeType:nil
                                                   filename:@"payload.json"];
    XCTAssertEqualObjects(element.key, @"jsonData");
    XCTAssertEqualObjects(element.boundary, @"TESTING123");
    XCTAssertEqualObjects(element.mimeType, @"application/json");
    XCTAssertEqualObjects(element.filename, @"payload.json");
    
    uint8_t *buffer = malloc(sizeof(uint8_t) * element.length);
    NSInteger readCount = [element read:buffer maxLength:element.length];
    XCTAssertEqual(readCount, 140U);
    
    NSString *stringData = [[NSString alloc] initWithBytesNoCopy:buffer length:element.length encoding:NSUTF8StringEncoding freeWhenDone:YES];
    XCTAssertEqualObjects(stringData, @"--TESTING123\r\nContent-Disposition: form-data; name=\"jsonData\"; filename=\"payload.json\"\r\nContent-Type: application/json\r\n\r\n{\"json\":\"value\"}\r\n");
}

- (void)testFileWrapperInputElement {
    NSURL *path = [[NSBundle bundleForClass:self.class] URLForResource:@"SimpleFile" withExtension:@"json"];
    XCTAssertNotNil(path);
    
    CSFInputStreamElement *element = nil;
    element = [[CSFInputStreamElement alloc] initWithObject:path boundary:@"Boundary" key:@"file"];
    
    XCTAssertNotNil(element);
    XCTAssertEqualObjects(element.key, @"file");
    XCTAssertEqualObjects(element.boundary, @"Boundary");
    XCTAssertEqualObjects(element.mimeType, @"application/json");
    XCTAssertEqualObjects(element.filename, @"SimpleFile.json");
    
    uint8_t *buffer = malloc(sizeof(uint8_t) * element.length);
    NSInteger readCount = [element read:buffer maxLength:element.length];
    XCTAssertEqual(readCount, 158U);
    
    NSString *stringData = [[NSString alloc] initWithBytesNoCopy:buffer length:element.length encoding:NSUTF8StringEncoding freeWhenDone:YES];
    XCTAssertEqualObjects(stringData, @"--Boundary\r\nContent-Disposition: form-data; name=\"file\"; filename=\"SimpleFile.json\"\r\nContent-Type: application/json\r\n\r\n{\"simple\":{\"json\":\"data\"},\"count\":15}\r\n");
}

@end
