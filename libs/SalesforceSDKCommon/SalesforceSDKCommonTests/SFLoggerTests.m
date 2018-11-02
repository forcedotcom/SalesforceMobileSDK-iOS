//
//  SFLoggerTests.m
//  SalesforceSDKCommonTests
//
//  Created by Raj Rao on 11/1/18.
//  Copyright © 2018 Salesforce. All rights reserved.
//

#import <XCTest/XCTest.h>

#import <XCTest/XCTest.h>
#import <SalesforceSDKCommon/SFLogger.h>

static NSString * const kTestComponent1 = @"TestComponent1";
static NSString * const kTestComponent2 = @"TestComponent2";
static NSString * const kTestLogLine1 = @"This is test log line 1!";
static NSString * const kTestLogLine2 = @"This is test log line 2!";
static NSString * const kTestLogLine3 = @"This is test log line 3!";
static NSString * const kTestLogLine4 = @"This is test log line 4!";
unsigned long long const kDefaultMaxFileSize = 1024 * 1024; // 1 MB.

@interface TestLogger : NSObject<SFLogging>

@end


@implementation TestLogger
@dynamic componentName,logger,logLevel;

- (instancetype)initWithComponent:(NSString *)componentName {
    if (self == [super init]) {
        componentName = componentName;
    }
    return self;
}

- (void)log:(nonnull Class)cls level:(SFLogLevel)level message:(nonnull NSString *)message {
    
}

- (void)log:(nonnull Class)cls level:(SFLogLevel)level format:(nonnull NSString *)format, ... {
    
}


- (void)log:(Class)cls level:(SFLogLevel)level format:(NSString *)format args:(va_list)args {
    
}

@end


@interface SFLoggerTests : XCTestCase {
    SFLogLevel _origLogLevel;
}

@end

@implementation SFLoggerTests

- (void)setUp {
    [super setUp];
    [SFLogger setInstanceClass:[TestLogger class]];
    _origLogLevel = [SFLogger sharedInstanceWithComponent:kTestComponent1].logLevel;
    [[SFLogger sharedInstanceWithComponent:kTestComponent1] setLogLevel:SFLogLevelInfo];
    [NSThread sleepForTimeInterval:1.0]; // Flushing the log file is asynchronous.
}

//- (void)tearDown {
//    [SFSDKLogger flushAllComponents];
//    [NSThread sleepForTimeInterval:1.0]; // Flushing the log file is asynchronous.
//    [[SFSDKLogger sharedInstanceWithComponent:kTestComponent1] setLogLevel:_origLogLevel];
//    [super tearDown];
//}
//
///**
// * Test for setting maximum size of log file.
// */
//- (void)testSetMaxSize {
//    SFLogger *logger = [SFLogger sharedInstanceWithComponent:kTestComponent1];
//    XCTAssertEqual(kDefaultMaxFileSize, logger.fileLogger.maximumFileSize, @"Max size didn't match expected max size");
//    long long newMaxSize = 1024;
//    logger.fileLogger.maximumFileSize = newMaxSize;
//    XCTAssertEqual(newMaxSize, logger.fileLogger.maximumFileSize, @"Max size didn't match expected max size");
//}
//
///**
// * Test for flushing the log file.
// */
//- (void)testFlushLogFile {
//    SFSDKLogger *logger = [SFSDKLogger sharedInstanceWithComponent:kTestComponent1];
//    XCTAssertEqualObjects(nil, [logger.fileLogger readFile], @"Log file should be empty");
//    [logger.logger log:NO message:[self messageForLogLine:kTestLogLine1]];
//    XCTAssertNotEqualObjects(nil, [logger.fileLogger readFile], @"Log file should not be empty");
//    [logger.fileLogger flushLogWithCompletionBlock:nil];
//
//    // Flushing the log file is asynchronous.
//    [NSThread sleepForTimeInterval:1.0];
//    XCTAssertEqualObjects(nil, [logger.fileLogger readFile], @"Log file should be empty");
//}
//
///**
// * Test for adding a log line.
// */
//- (void)testAddLogLine {
//    SFSDKLogger *logger = [SFSDKLogger sharedInstanceWithComponent:kTestComponent1];
//    XCTAssertEqualObjects(nil, [logger.fileLogger readFile], @"Log file should be empty");
//    [logger.logger log:NO message:[self messageForLogLine:kTestLogLine1]];
//    XCTAssertNotEqualObjects(nil, [logger.fileLogger readFile], @"Log file should not be empty");
//    XCTAssertTrue([[logger.fileLogger readFile] containsString:kTestLogLine1], @"Log file doesn't contain expected log line");
//}
//
///**
// * Test for adding multiple log lines.
// */
//- (void) testAddMultipleLogLines {
//    SFSDKLogger *logger = [SFSDKLogger sharedInstanceWithComponent:kTestComponent1];
//    XCTAssertEqualObjects(nil, [logger.fileLogger readFile], @"Log file should be empty");
//    [logger.logger log:NO message:[self messageForLogLine:kTestLogLine1]];
//    [logger.logger log:NO message:[self messageForLogLine:kTestLogLine2]];
//    [logger.logger log:NO message:[self messageForLogLine:kTestLogLine3]];
//    XCTAssertNotEqualObjects(nil, [logger.fileLogger readFile], @"Log file should not be empty");
//    XCTAssertTrue([[logger.fileLogger readFile] containsString:kTestLogLine1], @"Log file doesn't contain expected log line");
//    XCTAssertTrue([[logger.fileLogger readFile] containsString:kTestLogLine2], @"Log file doesn't contain expected log line");
//    XCTAssertTrue([[logger.fileLogger readFile] containsString:kTestLogLine3], @"Log file doesn't contain expected log line");
//}
//
//- (void)testChangeFileLogger {
//    // Original file logger.
//    SFSDKLogger *logger = [SFSDKLogger sharedInstanceWithComponent:kTestComponent1];
//    SFSDKFileLogger *origFileLogger = logger.fileLogger;
//    XCTAssertNil([logger.fileLogger readFile], @"Log file should be empty");
//    [logger.logger log:NO message:[self messageForLogLine:kTestLogLine1]];
//    XCTAssertNotNil([logger.fileLogger readFile], @"Log file should not be empty");
//    XCTAssertTrue([[logger.fileLogger readFile] containsString:kTestLogLine1], @"Log file doesn't contain expected log line");
//
//    // New file logger.
//    SFSDKFileLogger *newFileLogger = [[SFSDKFileLogger alloc] initWithComponent:kTestComponent2];
//    logger.fileLogger = newFileLogger;
//    XCTAssertNotEqual(logger.fileLogger, origFileLogger, @"File logger should have changed to the new file logger.");
//    XCTAssertNil([logger.fileLogger readFile], @"Log file should be empty");
//    [logger.logger log:NO message:[self messageForLogLine:kTestLogLine2]];
//    XCTAssertNotNil([logger.fileLogger readFile], @"Log file should not be empty");
//    XCTAssertTrue([[logger.fileLogger readFile] containsString:kTestLogLine2], @"New log file doesn't contain expected log line");
//    XCTAssertFalse([[logger.fileLogger readFile] containsString:kTestLogLine1], @"New log file contains unexpected log line");
//    XCTAssertTrue([[origFileLogger readFile] containsString:kTestLogLine1], @"Original log file doesn't contain expected log line");
//    XCTAssertFalse([[origFileLogger readFile] containsString:kTestLogLine2], @"Original log file contains unexpected log line");
//
//    // Clean up old file logger.
//    XCTestExpectation *flushOrigFileLogger = [self expectationWithDescription:@"flushOrigFileLogger"];
//    [origFileLogger flushLogWithCompletionBlock:^{
//        [flushOrigFileLogger fulfill];
//        XCTAssertNil([origFileLogger readFile], @"Original file log should be empty.");
//    }];
//    [self waitForExpectationsWithTimeout:5.0 handler:nil];
//}
//
///**
// * Test for logging to a shared file logger.
// */
//- (void) testLogToSharedFileLogger {
//    SFSDKLogger *logger1 = [SFSDKLogger sharedInstanceWithComponent:kTestComponent1];
//    SFSDKLogger *logger2 = [SFSDKLogger sharedInstanceWithComponent:kTestComponent2];
//    logger2.fileLogger = logger1.fileLogger;
//    XCTAssertEqual(logger1.fileLogger, logger2.fileLogger, @"File logger should be the same for both components.");
//    XCTAssertNil([logger1.fileLogger readFile], @"Log file should be empty");
//    [logger1.logger log:NO message:[self messageForLogLine:kTestLogLine1]];
//    [logger2.logger log:NO message:[self messageForLogLine:kTestLogLine2]];
//    [logger1.logger log:NO message:[self messageForLogLine:kTestLogLine3]];
//    for (SFSDKFileLogger *fileLogger in @[ logger1.fileLogger, logger2.fileLogger ]) {
//        XCTAssertNotNil([fileLogger readFile], @"Log file should not be empty");
//        XCTAssertTrue([[fileLogger readFile] containsString:kTestLogLine1], @"Log file doesn't contain expected log line");
//        XCTAssertTrue([[fileLogger readFile] containsString:kTestLogLine2], @"Log file doesn't contain expected log line");
//        XCTAssertTrue([[fileLogger readFile] containsString:kTestLogLine3], @"Log file doesn't contain expected log line");
//    }
//}
//
///**
// * Test for writing a log line after max size has been reached.
// */
//- (void)testWriteAfterMaxSizeReached {
//    SFSDKLogger *logger = [SFSDKLogger sharedInstanceWithComponent:kTestComponent1];
//    XCTAssertEqualObjects(nil, [logger.fileLogger readFile], @"Log file should be empty");
//    [logger.logger log:NO message:[self messageForLogLine:kTestLogLine1]];
//    [logger.logger log:NO message:[self messageForLogLine:kTestLogLine2]];
//    [logger.logger log:NO message:[self messageForLogLine:kTestLogLine3]];
//    XCTAssertNotEqualObjects(nil, [logger.fileLogger readFile], @"Log file should not be empty");
//    logger.fileLogger.maximumFileSize = 1;
//    XCTAssertEqual(1, logger.fileLogger.maximumFileSize, @"Max size didn't match expected max size");
//    [logger.logger log:NO message:[self messageForLogLine:kTestLogLine4]];
//    XCTAssertTrue([[logger.fileLogger readFile] containsString:kTestLogLine4], @"Log file doesn't contain expected log line");
//    XCTAssertFalse([[logger.fileLogger readFile] containsString:kTestLogLine1], @"Log file contains unexpected log line");
//}
//
///**
// * Test for adding a single component.
// */
//- (void)testAddSingleComponent {
//    SFSDKLogger *logger = [SFSDKLogger sharedInstanceWithComponent:kTestComponent1];
//    XCTAssertNotNil(logger, @"SFSDKLogger instance should not be nil");
//    XCTAssertEqual(1, [SFSDKLogger allComponents].count, @"Number of components should be 1");
//}
//
///**
// * Test for adding multiple components.
// */
//- (void)testAddMultipleComponents {
//    SFSDKLogger *logger = [SFSDKLogger sharedInstanceWithComponent:kTestComponent1];
//    XCTAssertNotNil(logger, @"SFSDKLogger instance should not be nil");
//    logger = [SFSDKLogger sharedInstanceWithComponent:kTestComponent2];
//    XCTAssertNotNil(logger, @"SFSDKLogger instance should not be nil");
//    XCTAssertEqual(2, [SFSDKLogger allComponents].count, @"Number of components should be 2");
//    XCTAssertTrue([[SFSDKLogger allComponents] containsObject:kTestComponent1], @"Component should be present in results");
//    XCTAssertTrue([[SFSDKLogger allComponents] containsObject:kTestComponent2], @"Component should be present in results");
//}
//
///**
// * Test for setting log level.
// */
//- (void)testSetLogLevel {
//    SFSDKLogger *logger = [SFSDKLogger sharedInstanceWithComponent:kTestComponent1];
//    XCTAssertNotNil(logger, @"SFSDKLogger instance should not be nil");
//    XCTAssertNotEqual(DDLogLevelVerbose, logger.logLevel, @"Log levels should not be same");
//    logger.logLevel = DDLogLevelVerbose;
//    XCTAssertEqual(DDLogLevelVerbose, logger.logLevel, @"Log levels should be the same");
//}
//
///**
// * Test for checking if the file logger is enabled by default.
// */
//- (void)testDefaultFileLoggerEnabled {
//    SFSDKLogger *logger = [SFSDKLogger sharedInstanceWithComponent:kTestComponent1];
//    XCTAssertTrue([logger isFileLoggingEnabled], @"File logger should be enabled");
//}
//
///**
// * Test for disabling the file logger.
// */
//- (void)testDisableFileLogger {
//    SFSDKLogger *logger = [SFSDKLogger sharedInstanceWithComponent:kTestComponent1];
//    XCTAssertTrue([logger isFileLoggingEnabled], @"File logger should be enabled");
//    [logger setFileLoggingEnabled:NO];
//    XCTAssertFalse([logger isFileLoggingEnabled], @"File logger should not be enabled");
//    [logger setFileLoggingEnabled:YES];
//}
//
///**
// * Test for enabling the file logger.
// */
//- (void)testEnableFileLogger {
//    SFSDKLogger *logger = [SFSDKLogger sharedInstanceWithComponent:kTestComponent1];
//    XCTAssertTrue([logger isFileLoggingEnabled], @"File logger should be enabled");
//    [logger setFileLoggingEnabled:NO];
//    XCTAssertFalse([logger isFileLoggingEnabled], @"File logger should not be enabled");
//    [logger setFileLoggingEnabled:YES];
//    XCTAssertTrue([logger isFileLoggingEnabled], @"File logger should be enabled");
//}
//
///**
// * Test for disabling the file logger twice in a row.
// */
//- (void)testDisableFileLoggerTwice {
//    SFSDKLogger *logger = [SFSDKLogger sharedInstanceWithComponent:kTestComponent1];
//    XCTAssertTrue([logger isFileLoggingEnabled], @"File logger should be enabled");
//    [logger setFileLoggingEnabled:NO];
//    XCTAssertFalse([logger isFileLoggingEnabled], @"File logger should not be enabled");
//    [logger setFileLoggingEnabled:NO];
//    XCTAssertFalse([logger isFileLoggingEnabled], @"File logger should not be enabled");
//    [logger setFileLoggingEnabled:YES];
//}
//
///**
// * Test for enabling the file logger twice in a row.
// */
//- (void)testEnableFileLoggerTwice {
//    SFSDKLogger *logger = [SFSDKLogger sharedInstanceWithComponent:kTestComponent1];
//    XCTAssertTrue([logger isFileLoggingEnabled], @"File logger should be enabled");
//    [logger setFileLoggingEnabled:YES];
//    XCTAssertTrue([logger isFileLoggingEnabled], @"File logger should be enabled");
//}
//
//- (DDLogMessage *)messageForLogLine:(NSString *)logLine {
//    return [[DDLogMessage alloc] initWithMessage:logLine level:DDLogLevelError flag:DDLogFlagError context:0 file:nil function:nil line:0 tag:[self class] options:0 timestamp:[NSDate date]];
//}

@end
