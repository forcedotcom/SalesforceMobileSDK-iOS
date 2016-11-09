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
#import "CSFMultipartInputStream.h"

@interface CSFMultipartInputStreamTests : XCTestCase

@end

@implementation CSFMultipartInputStreamTests

- (void)testSingleStringElement {
    CSFMultipartInputStream *stream = [[CSFMultipartInputStream alloc] init];
    XCTAssertEqual(stream.numberOfParts, 0U);
    
    [stream addObject:@"Test String" forKey:@"name"];
    XCTAssertEqual(stream.numberOfParts, 1U);
    XCTAssertEqual(stream.length, 188U);
    
    XCTAssertEqual(stream.streamStatus, NSStreamStatusNotOpen);
    [stream open];
    XCTAssertEqual(stream.streamStatus, NSStreamStatusOpen);
    
    uint8_t *buffer = malloc(sizeof(uint8_t) * 1024);
    NSMutableData *data = [NSMutableData dataWithCapacity:stream.length];
    
    NSInteger readCount = [stream read:buffer maxLength:1024];
    XCTAssertEqual(readCount, 188U);
    [data appendBytes:buffer length:readCount];
    
    NSString *stringData = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSString *expectedString = [NSString stringWithFormat:@"--%@\r\nContent-Disposition: form-data; name=\"name\"\r\n\r\nTest String\r\n--%@--\r\n", stream.boundary, stream.boundary];
    XCTAssertEqualObjects(stringData, expectedString);
    free(buffer);
}

- (void)testMultipleStringElements {
    CSFMultipartInputStream *stream = [[CSFMultipartInputStream alloc] init];
    XCTAssertEqual(stream.numberOfParts, 0U);
    
    [stream addObject:@"Test String" forKey:@"title"];
    XCTAssertEqual(stream.numberOfParts, 1U);
    XCTAssertEqual(stream.length, 189U);
    
    [stream addObject:@"Michael" forKey:@"firstname"];
    XCTAssertEqual(stream.numberOfParts, 2U);
    XCTAssertEqual(stream.length, 313U);
    
    [stream addObject:@"Nachbaur" forKey:@"lastname"];
    XCTAssertEqual(stream.numberOfParts, 3U);
    XCTAssertEqual(stream.length, 437U);
    
    XCTAssertEqual(stream.streamStatus, NSStreamStatusNotOpen);
    [stream open];
    XCTAssertEqual(stream.streamStatus, NSStreamStatusOpen);
    
    uint8_t *buffer = malloc(sizeof(uint8_t) * 1024);
    NSMutableData *data = [NSMutableData dataWithCapacity:stream.length];
    
    NSInteger readCount = [stream read:buffer maxLength:1024];
    XCTAssertEqual(readCount, 437U);
    [data appendBytes:buffer length:readCount];
    
    NSString *stringData = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSMutableString *expectedString = [NSMutableString new];
    [expectedString appendFormat:@"--%@\r\nContent-Disposition: form-data; name=\"title\"\r\n\r\nTest String\r\n", stream.boundary];
    [expectedString appendFormat:@"--%@\r\nContent-Disposition: form-data; name=\"firstname\"\r\n\r\nMichael\r\n", stream.boundary];
    [expectedString appendFormat:@"--%@\r\nContent-Disposition: form-data; name=\"lastname\"\r\n\r\nNachbaur\r\n", stream.boundary];
    [expectedString appendFormat:@"--%@--\r\n", stream.boundary];
    XCTAssertEqualObjects(stringData, expectedString);
    free(buffer);
}

- (void)testMixedObjectElements {
    CSFMultipartInputStream *stream = [[CSFMultipartInputStream alloc] init];
    XCTAssertEqual(stream.numberOfParts, 0U);
    
    [stream addObject:@"Test String" forKey:@"title"];
    XCTAssertEqual(stream.numberOfParts, 1U);
    XCTAssertEqual(stream.length, 189U);
    
    NSDateFormatter *dateFormatter = [NSDateFormatter new];
    dateFormatter.dateStyle = NSDateFormatterFullStyle;
    dateFormatter.timeStyle = NSDateFormatterFullStyle;
    
    NSDate *someDate =[dateFormatter dateFromString:@"Friday, July 24, 2015 at 7:21:02 AM Hawaii-Aleutian Standard Time"];
    [stream addObject:someDate forKey:@"date"];
    XCTAssertEqual(stream.numberOfParts, 2U);
    XCTAssertEqual(stream.length, 321U);
    
    [stream addObject:[NSURL URLWithString:@"http://example.org/path/to?something=else"] forKey:@"url"];
    XCTAssertEqual(stream.numberOfParts, 3U);
    XCTAssertEqual(stream.length, 473U);
    
    NSURL *path = [[NSBundle bundleForClass:self.class] URLForResource:@"SimpleFile" withExtension:@"json"];
    XCTAssertNotNil(path);
    [stream addObject:path forKey:@"file"];
    XCTAssertEqual(stream.numberOfParts, 4U);
    XCTAssertEqual(stream.length, 682U);
    
    XCTAssertEqual(stream.streamStatus, NSStreamStatusNotOpen);
    [stream open];
    XCTAssertEqual(stream.streamStatus, NSStreamStatusOpen);
    
    uint8_t *buffer = malloc(sizeof(uint8_t) * 1024);
    NSMutableData *data = [NSMutableData dataWithCapacity:stream.length];
    
    NSInteger readCount = [stream read:buffer maxLength:1024];
    XCTAssertEqual(readCount, 682U);
    [data appendBytes:buffer length:readCount];
    
    [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
    NSString *stringData = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSMutableString *expectedString = [NSMutableString new];
    [expectedString appendFormat:@"--%@\r\nContent-Disposition: form-data; name=\"title\"\r\n\r\nTest String\r\n", stream.boundary];
    [expectedString appendFormat:@"--%@\r\nContent-Disposition: form-data; name=\"date\"\r\n\r\n%@\r\n", stream.boundary, [dateFormatter stringFromDate:someDate]];
    [expectedString appendFormat:@"--%@\r\nContent-Disposition: form-data; name=\"url\"\r\n\r\nhttp://example.org/path/to?something=else\r\n", stream.boundary];
    [expectedString appendFormat:@"--%@\r\nContent-Disposition: form-data; name=\"file\"; filename=\"SimpleFile.json\"\r\nContent-Type: application/json\r\n\r\n{\"simple\":{\"json\":\"data\"},\"count\":15}\r\n", stream.boundary];
    [expectedString appendFormat:@"--%@--\r\n", stream.boundary];
    XCTAssertEqualObjects(stringData, expectedString);
    free(buffer);
}

@end
