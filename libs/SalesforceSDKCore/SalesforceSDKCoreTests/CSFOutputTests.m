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
#import "CSFOutput_Internal.h"

////////////
@interface PersonOutput : CSFOutput

@property (nonatomic, strong, readonly) NSString *name;
@property (nonatomic, strong, readonly) NSString *title;
@property (nonatomic, strong, readonly) NSArray *tags;

@end

@implementation PersonOutput
@dynamic name, tags; // Note that 'title' isn't dynamic

@end

@interface CourseOutput : CSFOutput

@property (nonatomic, strong, readonly) NSArray *students;
@property (nonatomic, strong, readonly) NSString *title;
@property (nonatomic, readonly) NSUInteger maxStudents;
@property (nonatomic, readonly) float averageScore;
@property (nonatomic, strong, readonly) NSDate *startDate;

@end

@implementation CourseOutput

+ (Class<CSFActionModel>)actionModelForPropertyName:(NSString*)propertyName propertyClass:(Class)originalClass contents:(id)contents {
    Class<CSFActionModel> result = nil;
    if ([propertyName isEqualToString:@"students"]) {
        result = [PersonOutput class];
    } else {
        result = [super actionModelForPropertyName:propertyName propertyClass:originalClass contents:contents];
    }
    return result;
}


@end
///////

@interface CSFOutputTests : XCTestCase

@end

@implementation CSFOutputTests

- (void)testBaseClass {
    CSFOutput *output = nil;
    
    output = [[CSFOutput alloc] init];
    XCTAssertNotNil(output);
    
    output = [[CSFOutput alloc] initWithJSON:nil context:nil];
    XCTAssertNotNil(output);
    
    output = [[CSFOutput alloc] initWithJSON:@{ @"foo": @"bar" } context:nil];
    XCTAssertNotNil(output);
    XCTAssertEqualObjects(output[@"foo"], @"bar");
    XCTAssertThrows([output setValue:@"baz" forKey:@"foo"]);
    XCTAssertEqualObjects(output[@"foo"], @"bar");
}

- (void)testSimpleProperties {
    PersonOutput *output = nil;
    
    output = [[PersonOutput alloc] initWithJSON:@{ @"name": @"Mike", @"title": @"Captain Awesome" } context:nil];
    XCTAssertNotNil(output);
    XCTAssertEqualObjects(output[@"name"], @"Mike");
    XCTAssertEqualObjects(output.name, @"Mike");
    XCTAssertEqualObjects(output[@"title"], @"Captain Awesome");
    XCTAssertEqualObjects(output.title, @"Captain Awesome");
}

- (void)testNestedAndPrimitiveProperties {
    CourseOutput *output = nil;

    NSDictionary *sourceJSON = @{ @"students": @[ @{ @"name": @"John" },
                                                  @{ @"name": @"Paul" },
                                                  @{ @"name": @"George" },
                                                  @{ @"name": @"Ringo" } ],
                                  @"title": @"Intro to drumming",
                                  @"maxStudents": @15,
                                  @"averageScore": @96.5,
                                  @"startDate": @"2015-03-15T09:30:00Z" };
    output = [[CourseOutput alloc] initWithJSON:sourceJSON context:nil];
    XCTAssertNotNil(output);
    XCTAssertEqualObjects(output[@"title"], @"Intro to drumming");
    XCTAssertEqual(output.students.count, 4);
    
    PersonOutput *person = output.students[0];
    XCTAssertNotNil(person);
    XCTAssertEqualObjects(person.name, @"John");
    
    person = output.students[1];
    XCTAssertNotNil(person);
    XCTAssertEqualObjects(person.name, @"Paul");
    
    person = output.students[2];
    XCTAssertNotNil(person);
    XCTAssertEqualObjects(person.name, @"George");
    
    person = output.students[3];
    XCTAssertNotNil(person);
    XCTAssertEqualObjects(person.name, @"Ringo");
    
    XCTAssertEqual(output.maxStudents, 15U);
    XCTAssertEqual(output.averageScore, 96.5f);
    XCTAssertEqualObjects(output.startDate, [NSDate dateWithTimeIntervalSinceReferenceDate:448104600]);
    XCTAssertEqualObjects(output[@"maxStudents"], @15);
    XCTAssertEqualObjects(output[@"averageScore"], @96.5);
    
    NSData *encodedData = [NSKeyedArchiver archivedDataWithRootObject:output];
    XCTAssertNotNil(encodedData);
    
    CourseOutput *decodedOutput = [NSKeyedUnarchiver unarchiveObjectWithData:encodedData];
    XCTAssertNotNil(decodedOutput);
    
    XCTAssertEqual(output.hash, decodedOutput.hash);
    XCTAssertEqualObjects(output, decodedOutput);
    XCTAssertEqual(output.maxStudents, decodedOutput.maxStudents);
    XCTAssertEqual(output.averageScore, decodedOutput.averageScore);
    XCTAssertEqualObjects(output.title, decodedOutput.title);
    XCTAssertEqualObjects(output.students, decodedOutput.students);
}

@end
