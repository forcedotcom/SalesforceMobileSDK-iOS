/*
 SFLoggerTests.m
 SFLoggerTests
 
 Created by Raj Rao on Tue Nov  6 12:04:13 PST 2018.
 
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

#import <XCTest/XCTest.h>
#import <SalesforceSDKCommon/SalesforceSDKCommon.h>

static NSString * const kTestDefaultComponent = @"TestDefaultComponent";
static NSString * const kTestComponent1 = @"TestComponent1";
static NSString * const kTestComponent2 = @"TestComponent2";
static NSString * const kTestLogLine1 = @"This is test log line 1!";
static NSString * const kTestLogLine2 = @"This is test log line 2!";
static NSString * const kTestLogLine3 = @"This is test log line 3!";
static NSString * const kTestLogLine4 = @"This is test log line 4!";
static NSString * const kLogNotification = @"LogNotification";
static NSString * const kLogLevelKey = @"loglevel";
static NSString * const kClassKey = @"class";
static NSString * const kMessageKey = @"message";


@interface SFLogger(Test)
+ (void)clearAllComponents;
@end

@interface TestLogger: SFLogger
@property id<SFLogging> logger;
- (id<SFLogging>)loggerImpl;
+ (void)clearAllComponents;

@end

@implementation TestLogger
@dynamic logger;

- (id<SFLogging>)loggerImpl {
    return self.logger;
}

+ (instancetype)sharedInstance {
    return [self loggerForComponent:kTestDefaultComponent];
}

+ (void)clearAllComponents {
    [super clearAllComponents];
}
@end

@interface TestLoggingImpl : NSObject<SFLogging>
@property (nonatomic, readonly, strong, nonnull) NSString *componentName;
@property (nonatomic, readonly, strong, nonnull) id logger;
@property (nonatomic, readwrite, assign) SFLogLevel logLevel;
@end

@implementation TestLoggingImpl
@synthesize  componentName,logger,logLevel = _logLevel;

- (instancetype)initWithComponent:(NSString *)componentName {
    if (self == [super init]) {
        componentName = componentName;
    }
    return self;
}

- (void)log:(nonnull Class)cls level:(SFLogLevel)level message:(nonnull NSString *)message {
    [[NSNotificationCenter defaultCenter]postNotificationName:kLogNotification object:self  userInfo:@{kLogLevelKey: @(level),kMessageKey:message,kClassKey:cls}];
}

- (void)log:(nonnull Class)cls level:(SFLogLevel)level format:(nonnull NSString *)format, ... {
    va_list args;
    va_start(args, format);
    [self log:cls level:level format:format args:args];
    va_end(args);
}

- (void)log:(Class)cls level:(SFLogLevel)level format:(NSString *)format args:(va_list)args {
    NSString *formattedMessage = [[NSString alloc] initWithFormat:format arguments:args];
    [self log:cls level:level message:formattedMessage];
}

- (void)setLogLevel:(SFLogLevel)level {
    if (_logLevel!=level) {
       _logLevel = level;
    }
}
- (SFLogLevel)logLevel {
    return _logLevel;
}
@end


@interface SFLoggerTests : XCTestCase {
    SFLogLevel _origLogLevel;
}

@end

@implementation SFLoggerTests

- (void)setUp {
    [super setUp];
    [TestLogger setInstanceClass:[TestLoggingImpl class]];
    _origLogLevel = [TestLogger loggerForComponent:kTestDefaultComponent].logLevel;
}

- (void)tearDown {
    [TestLogger setInstanceClass:[SFDefaultLogger class]];
    [TestLogger clearAllComponents];
}

/**
 * Test Logger Class is correct
 */
- (void)testLoggerInstance {
    TestLogger *logger = [TestLogger sharedInstance];
    XCTAssertNotNil(logger, "Logger instance should have been created");
    XCTAssertTrue([logger.logger isKindOfClass:[TestLoggingImpl class]], "Logger should be an instance of TestLoggingImpl");
    TestLogger.logLevel = SFLogLevelDebug;
     XCTAssertTrue(TestLogger.logLevel == SFLogLevelDebug, "Logger level should be set to debug");
}

/**
 * Test Logger Class is correct
 */
- (void)testMultipleLoggerComponents {
    TestLogger *logger = [TestLogger sharedInstance];
    TestLogger *anotherLogger = [TestLogger loggerForComponent:kTestComponent1];
    XCTAssertNotNil(logger, "Logger instance should have been created");
    XCTAssertNotNil(anotherLogger, "Component Logger instance should have been created");
    XCTAssertTrue(logger!=anotherLogger, "Should be 2 different instances of logger");
    TestLogger.logLevel = SFLogLevelDebug;
    XCTAssertTrue(TestLogger.logLevel == SFLogLevelDebug, "Logger level should be set to debug");
    XCTAssertTrue(anotherLogger.logLevel == SFLogLevelDefault, "Component Logger level should not have changed");
}

/**
 * Test Log Level debug
 */
- (void)testLoggerDebugLog {
    TestLogger *logger = [TestLogger sharedInstance];
    XCTAssertNotNil(logger, "Logger instance should have been created");
    logger.logLevel = SFLogLevelDebug;
    XCTAssertTrue(logger.logLevel == SFLogLevelDebug, "Logger level should be set to debug");

    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"Log Notification"];
    
    __block SFLogLevel logLevelUsed  = SFLogLevelDefault;
    __block Class classUsed  = nil;
    __block NSString *message = nil;
    [[NSNotificationCenter defaultCenter] addObserverForName:@"LogNotification" object:nil   queue:nil usingBlock:^(NSNotification *note) {
         logLevelUsed = [(NSNumber *) note.userInfo[kLogLevelKey] intValue];
         classUsed = (Class) note.userInfo[kClassKey];
         message = (NSString *) note.userInfo[kMessageKey];
         [expectation fulfill];
    }];
    
    [logger d:self.class format:@"TestDebugStatement %@",@"TestValue"];
    [self waitForExpectations:@[expectation] timeout:10];
    XCTAssertTrue(logLevelUsed==SFLogLevelDebug,"Log statement should have been at Debug level");
    XCTAssertTrue([self isKindOfClass:classUsed],"Log statement should have been logged against  the class");
    XCTAssertTrue(message && message.length > 0 ,"Log statement should not be emtpty");
}

/**
 * Test Log Level Info
 */
- (void)testLoggerInfoLog {
    TestLogger *logger = [TestLogger sharedInstance];
    XCTAssertNotNil(logger, "Logger instance should have been created");
    logger.logLevel = SFLogLevelInfo;
    XCTAssertTrue(logger.logLevel == SFLogLevelInfo, "Logger level should be set to info");
    
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"Log Notification"];
    __block SFLogLevel logLevelUsed  = SFLogLevelDefault;
    __block Class classUsed  = nil;
    __block NSString *message = nil;
    [[NSNotificationCenter defaultCenter] addObserverForName:kLogNotification object:nil   queue:nil usingBlock:^(NSNotification *note) {
        logLevelUsed = [(NSNumber *) note.userInfo[kLogLevelKey] intValue];
        classUsed = (Class) note.userInfo[kClassKey];
        message = (NSString *) note.userInfo[kMessageKey];
        [expectation fulfill];
    }];
    
    [logger i:self.class format:@"TestDebugStatement %@",@"TestValue"];
    [self waitForExpectations:@[expectation] timeout:10];
    XCTAssertTrue(logLevelUsed==SFLogLevelInfo,"Log statement should have been at Info  level");
    XCTAssertTrue([self isKindOfClass:classUsed],"Log statement should have been logged against  the class");
    XCTAssertTrue(message && message.length > 0 ,"Log statement should not be emtpty");
}

/**
 * Test Log Level Error
 */
- (void)testLoggerErrorLog {
    TestLogger *logger = [TestLogger sharedInstance];
    XCTAssertNotNil(logger, "Logger instance should have been created");
    logger.logLevel = SFLogLevelError;
    XCTAssertTrue(logger.logLevel == SFLogLevelError, "Logger level should be set to error");
    
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"Log Notification"];
    __block SFLogLevel logLevelUsed  = SFLogLevelDefault;
    __block Class classUsed  = nil;
    __block NSString *message = nil;
    [[NSNotificationCenter defaultCenter] addObserverForName:kLogNotification object:nil   queue:nil usingBlock:^(NSNotification *note) {
        logLevelUsed = [(NSNumber *) note.userInfo[kLogLevelKey] intValue];
        classUsed = (Class) note.userInfo[kClassKey];
        message = (NSString *) note.userInfo[kMessageKey];
        [expectation fulfill];
    }];
    
    [logger e:self.class format:@"TestDebugStatement %@",@"TestValue"];
    [self waitForExpectations:@[expectation] timeout:10];
    XCTAssertTrue(logLevelUsed==SFLogLevelError,"Log statement should have been at Error  level");
    XCTAssertTrue([self isKindOfClass:classUsed],"Log statement should have been logged against  the class");
    XCTAssertTrue(message && message.length > 0 ,"Log statement should not be emtpty");
}

/**
 * Test Log Level Fault
 */
- (void)testLoggerFaultLog {
    TestLogger *logger = [TestLogger sharedInstance];
    XCTAssertNotNil(logger, "Logger instance should have been created");
    logger.logLevel = SFLogLevelFault;
    XCTAssertTrue(logger.logLevel == SFLogLevelFault, "Logger level should be set to error");
    
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"Log Notification"];
    __block SFLogLevel logLevelUsed  = SFLogLevelDefault;
    __block Class classUsed  = nil;
    __block NSString *message = nil;
    [[NSNotificationCenter defaultCenter] addObserverForName:kLogNotification object:nil   queue:nil usingBlock:^(NSNotification *note) {
        logLevelUsed = [(NSNumber *) note.userInfo[kLogLevelKey] intValue];
        classUsed = (Class) note.userInfo[kClassKey];
        message = (NSString *) note.userInfo[kMessageKey];
        [expectation fulfill];
    }];
    
    [logger f:self.class format:@"TestDebugStatement %@",@"TestValue"];
    [self waitForExpectations:@[expectation] timeout:10];
    XCTAssertTrue(logLevelUsed==SFLogLevelFault,"Log statement should have been at Fault   level");
    XCTAssertTrue([self isKindOfClass:classUsed],"Log statement should have been logged against  the class");
    XCTAssertTrue(message && message.length > 0 ,"Log statement should not be emtpty");
}
@end
