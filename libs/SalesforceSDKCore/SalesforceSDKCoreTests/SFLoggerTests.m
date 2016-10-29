/*
 Copyright (c) 2016-present, salesforce.com, inc. All rights reserved.
 
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
#import <CocoaLumberjack/CocoaLumberjack.h>
#import "SFLogger_Internal.h"
#import "SFCocoaLumberJackCustomFormatter.h"

@interface LogItem : NSObject

@property (nonatomic, assign, readonly) BOOL async;
@property (nonatomic, assign, readonly) DDLogLevel level;
@property (nonatomic, assign, readonly) DDLogFlag flag;
@property (nonatomic, assign, readonly) NSInteger context;
@property (nonatomic, strong, readonly) NSString *file;
@property (nonatomic, strong, readonly) NSString *function;
@property (nonatomic, assign, readonly) NSUInteger line;
@property (nonatomic, strong, readonly) id tag;
@property (nonatomic, strong, readonly) NSString *format;
@property (nonatomic, strong, readonly) NSString *message;

- (instancetype)initWithAsync:(BOOL)asynchronous
                        level:(DDLogLevel)level
                         flag:(DDLogFlag)flag
                      context:(NSInteger)context
                         file:(const char *)file
                     function:(const char *)function
                         line:(NSUInteger)line
                          tag:(id)tag
                       format:(NSString *)format
                         args:(va_list)args;

@end

@implementation LogItem

- (instancetype)initWithAsync:(BOOL)asynchronous
                        level:(DDLogLevel)level
                         flag:(DDLogFlag)flag
                      context:(NSInteger)context
                         file:(const char *)file
                     function:(const char *)function
                         line:(NSUInteger)line
                          tag:(id)tag
                       format:(NSString *)format
                         args:(va_list)args
{
    self = [self init];
    if (self) {
        _async = asynchronous;
        _level = level;
        _flag = flag;
        _context = context;
        if (file) {
            _file = [NSString stringWithCString:file encoding:NSUTF8StringEncoding];
        }
        if (function) {
            _function = [NSString stringWithCString:function encoding:NSUTF8StringEncoding];
        }
        _line = line;
        _tag = tag;
        _format = format;
        if (format && args) {
            _message = [[NSString alloc] initWithFormat:format arguments:args];
        }
    }
    return self;
}

- (instancetype)initWithAsync:(BOOL)asynchronous
                        level:(DDLogLevel)level
                         flag:(DDLogFlag)flag
                      context:(NSInteger)context
                         file:(const char *)file
                     function:(const char *)function
                         line:(NSUInteger)line
                          tag:(id)tag
                       format:(NSString *)format
                      message:(NSString *)message
{
    self = [self initWithAsync:asynchronous level:level flag:flag context:context file:file function:function line:line tag:tag format:format args:nil];
    if (self) {
        _message = message;
    }
    return self;
}

- (NSString*)description {
    NSString *flagName = nil;
    switch (_flag) {
        case DDLogFlagInfo:
            flagName = @"INFO";
            break;
            
        case DDLogFlagDebug:
            flagName = @"DEBUG";
            break;
            
        case DDLogFlagVerbose:
            flagName = @"VERBOSE";
            break;
            
        case DDLogFlagError:
            flagName = @"ERROR";
            break;
            
        case DDLogFlagWarning:
            flagName = @"WARNING";
            break;
            
        default:
            flagName = @"Unknown";
            break;
    }

    NSString *filename = @"<unknown>";
    if (_file) {
        filename = [NSString stringWithFormat:@"%@:%ld", _file, (unsigned long)_line];
    }
    
    return [NSString stringWithFormat:@"<%@ %p, %@, %@/%@ (%ld), \"%@\", %@, %@>",
            NSStringFromClass(self.class), self,
            (_async ? @"async" : @"sync"),
            SFLogNameForLogLevel((SFLogLevel)_level),
            flagName,
            (unsigned long)_context,
            _message,
            filename,
            _function ?: @"<unknown>"];
}

- (BOOL)isEqual:(LogItem*)object {
    BOOL result = YES;
    if (object == self) {
        result = YES;
    } else if (![object isMemberOfClass:self.class]) {
        result = NO;
    } else if (_async != object->_async) {
        result = NO;
    } else if (_level != object->_level) {
        result = NO;
    } else if (_flag != object->_flag) {
        result = NO;
    } else if (_context != object->_context) {
        result = NO;
    } else if (_line != object->_line) {
        result = NO;
    } else if ((_tag || object->_tag) && (![_tag isEqual:object->_tag])) {
        result = NO;
    } else if ((_file || object->_file) && (![_file isEqualToString:object->_file])) {
        result = NO;
    } else if ((_function || object->_function) && (![_function isEqualToString:object->_function])) {
        result = NO;
    } else if ((_format || object->_format) && (![_format isEqualToString:object->_format])) {
        result = NO;
    } else if ((_message || object->_message) && (![_message isEqualToString:object->_message])) {
        result = NO;
    }
    return result;
}

@end


@interface LogStorageRecorder : NSObject<SFLogStorage>

@property (nonatomic, strong, readwrite) NSArray<id<DDLogger>> *allLoggers;
@property (nonatomic, strong) NSMutableArray<LogItem*> *results;

@end

@implementation LogStorageRecorder

- (instancetype)init {
    self = [super init];
    if (self) {
        self.results = [NSMutableArray new];
    }
    return self;
}

- (void)addLogger:(id <DDLogger>)logger {
    NSMutableArray<id<DDLogger>> *loggers = [self.allLoggers mutableCopy] ?: [NSMutableArray new];
    [loggers addObject:logger];
    self.allLoggers = [NSArray arrayWithArray:loggers];
}

- (void)removeLogger:(id <DDLogger>)logger {
    NSMutableArray<id<DDLogger>> *loggers = [self.allLoggers mutableCopy] ?: [NSMutableArray new];
    [loggers removeObject:logger];
    self.allLoggers = [NSArray arrayWithArray:loggers];
}

- (void)removeAllLoggers {
    self.allLoggers = [NSArray new];
}

- (void)log:(BOOL)asynchronous
      level:(DDLogLevel)level
       flag:(DDLogFlag)flag
    context:(NSInteger)context
       file:(const char *)file
   function:(const char *)function
       line:(NSUInteger)line
        tag:(id)tag
     format:(NSString *)format
       args:(va_list)args
{
    [self.results addObject:[[LogItem alloc] initWithAsync:asynchronous
                                                     level:level
                                                      flag:flag
                                                   context:context
                                                      file:file
                                                  function:function
                                                      line:line
                                                       tag:tag
                                                    format:format
                                                      args:args]];
}

@end

@interface TestLogger : NSObject<DDLogger>

@property (nonnull, strong, readonly) NSMutableArray<NSString*> *messages;

@end

@implementation TestLogger
@synthesize logFormatter = _logFormatter;

- (instancetype)init {
    self = [super init];
    if (self) {
        _messages = [NSMutableArray new];
    }
    return self;
}

- (void)logMessage:(DDLogMessage *)logMessage {
    NSString * message = _logFormatter ? [_logFormatter formatLogMessage:logMessage] : logMessage->_message;
    [_messages addObject:message];
}

@end

/////////////

@interface SFLoggerTests : XCTestCase

@end

@implementation SFLoggerTests

- (void)testFlagsAndLevels {
    XCTAssertTrue(SFLogLevelVerbose & SFLogFlagVerbose);
    XCTAssertTrue(SFLogLevelVerbose & SFLogFlagDebug);
    XCTAssertTrue(SFLogLevelVerbose & SFLogFlagInfo);
    XCTAssertTrue(SFLogLevelVerbose & SFLogFlagWarning);
    XCTAssertTrue(SFLogLevelVerbose & SFLogFlagError);
    
    XCTAssertFalse(SFLogLevelDebug & SFLogFlagVerbose);
    XCTAssertTrue(SFLogLevelDebug & SFLogFlagDebug);
    XCTAssertTrue(SFLogLevelDebug & SFLogFlagInfo);
    XCTAssertTrue(SFLogLevelDebug & SFLogFlagWarning);
    XCTAssertTrue(SFLogLevelDebug & SFLogFlagError);
    
    XCTAssertFalse(SFLogLevelInfo & SFLogFlagVerbose);
    XCTAssertFalse(SFLogLevelInfo & SFLogFlagDebug);
    XCTAssertTrue(SFLogLevelInfo & SFLogFlagInfo);
    XCTAssertTrue(SFLogLevelInfo & SFLogFlagWarning);
    XCTAssertTrue(SFLogLevelInfo & SFLogFlagError);
    
    XCTAssertFalse(SFLogLevelWarning & SFLogFlagVerbose);
    XCTAssertFalse(SFLogLevelWarning & SFLogFlagDebug);
    XCTAssertFalse(SFLogLevelWarning & SFLogFlagInfo);
    XCTAssertTrue(SFLogLevelWarning & SFLogFlagWarning);
    XCTAssertTrue(SFLogLevelWarning & SFLogFlagError);
    
    XCTAssertFalse(SFLogLevelError & SFLogFlagVerbose);
    XCTAssertFalse(SFLogLevelError & SFLogFlagDebug);
    XCTAssertFalse(SFLogLevelError & SFLogFlagInfo);
    XCTAssertFalse(SFLogLevelError & SFLogFlagWarning);
    XCTAssertTrue(SFLogLevelError & SFLogFlagError);
    
    XCTAssertFalse(SFLogLevelOff & SFLogFlagVerbose);
    XCTAssertFalse(SFLogLevelOff & SFLogFlagDebug);
    XCTAssertFalse(SFLogLevelOff & SFLogFlagInfo);
    XCTAssertFalse(SFLogLevelOff & SFLogFlagWarning);
    XCTAssertFalse(SFLogLevelOff & SFLogFlagError);
}

- (void)testSingletonHandlers {
    LogItem *expected = nil;
    
    SFLogger *logger = [SFLogger sharedLogger];
    XCTAssertNotNil(logger);
    
    LogStorageRecorder *recorder = [LogStorageRecorder new];
    logger->_ddLog = recorder;
    
    logger.logLevel = SFLogLevelWarning;
    XCTAssertEqual(logger.logLevel, SFLogLevelWarning);
    XCTAssertEqual(SFLoggerContextLogLevels[0], SFLogLevelWarning);
    
    SFLogIdentifier *identifier = [logger logIdentifierForIdentifier:nil];
    XCTAssertEqual(identifier.logFlag, SFLogFlagWarning);
    
    [SFLogger log:self.class level:SFLogLevelDebug msg:@"Debug message"];
    XCTAssertEqual(recorder.results.count, 0U);
    
    expected = [[LogItem alloc] initWithAsync:YES
                                        level:DDLogLevelWarning
                                         flag:DDLogFlagWarning
                                      context:1
                                         file:nil
                                     function:nil
                                         line:0
                                          tag:[[SFLogTag alloc] initWithClass:self.class selector:nil]
                                       format:@"Warning message"
                                      message:@"Warning message"];
    [SFLogger log:self.class level:SFLogLevelWarning msg:@"Warning message"];
    XCTAssertEqual(recorder.results.count, 1U);
    XCTAssertEqualObjects([recorder.results lastObject], expected);
    
    expected = [[LogItem alloc] initWithAsync:YES
                                        level:DDLogLevelWarning
                                         flag:DDLogFlagError
                                      context:1
                                         file:nil
                                     function:nil
                                         line:0
                                          tag:[[SFLogTag alloc] initWithClass:self.class selector:nil]
                                       format:@"Warning message with an argument"
                                      message:@"Warning message with an argument"];
    [SFLogger log:self.class level:SFLogLevelError format:@"Warning message with %@", @"an argument"];
    XCTAssertEqual(recorder.results.count, 2U);
    XCTAssertEqualObjects([recorder.results lastObject], expected);

    // Test custom identifiers with different log levels
    [recorder.results removeAllObjects];
    NSString *testIdentifier = @"Woof";
    logger.logLevel = SFLogLevelDebug;
    [SFLogger log:self.class level:SFLogLevelDebug identifier:testIdentifier msg:@"Message to Woof"];
    XCTAssertEqual(recorder.results.count, 0U); // Test that the default level is `warning`

    NSInteger context = [logger registerIdentifier:testIdentifier];
    [logger setLogLevel:SFLogLevelDebug forIdentifier:testIdentifier];
    [SFLogger log:self.class level:SFLogLevelDebug identifier:testIdentifier msg:@"Message to Woof"];
    XCTAssertEqual(recorder.results.count, 1U); // Test that the default level is `warning`
    XCTAssertEqual(SFLoggerContextLogLevels[context - 1], SFLogLevelDebug);

    expected = [[LogItem alloc] initWithAsync:YES
                                        level:DDLogLevelDebug
                                         flag:DDLogFlagDebug
                                      context:context
                                         file:nil
                                     function:nil
                                         line:0
                                          tag:[[SFLogTag alloc] initWithClass:self.class selector:nil]
                                       format:@"Message to Woof"
                                      message:@"Message to Woof"];
    XCTAssertEqualObjects([recorder.results lastObject], expected);
}

- (void)testMacroLogging {
    SFLogger *logger = [SFLogger sharedLogger];
    LogStorageRecorder *recorder = [LogStorageRecorder new];
    logger->_ddLog = recorder;
    logger.logLevel = SFLogLevelVerbose;

    NSUInteger baseLine = __LINE__;
    XCTAssertEqual(recorder.results.count, 0U);
    SFLogVerbose(@"This is a verbose message");
    XCTAssertEqual(recorder.results.count, 1U);
    SFLogDebug(@"This is a debug message: %d", 1U);
    XCTAssertEqual(recorder.results.count, 2U);
    SFLogInfo(@"This is a info message");
    XCTAssertEqual(recorder.results.count, 3U);
    SFLogWarn(@"This is a warning %@", @"message");
    XCTAssertEqual(recorder.results.count, 4U);
    SFLogError(@"This is a error message");
    XCTAssertEqual(recorder.results.count, 5U);
    
    XCTAssertEqualObjects(recorder.results[0],
                          [[LogItem alloc] initWithAsync:YES
                                                   level:DDLogLevelVerbose
                                                    flag:DDLogFlagVerbose
                                                 context:1
                                                    file:__FILE__
                                                function:"-[SFLoggerTests testMacroLogging]"
                                                    line:baseLine + 2
                                                     tag:[[SFLogTag alloc] initWithClass:self.class selector:nil]
                                                  format:@"This is a verbose message"
                                                 message:@"This is a verbose message"]);
    XCTAssertEqualObjects(recorder.results[1],
                          [[LogItem alloc] initWithAsync:YES
                                                   level:DDLogLevelVerbose
                                                    flag:DDLogFlagDebug
                                                 context:1
                                                    file:__FILE__
                                                function:"-[SFLoggerTests testMacroLogging]"
                                                    line:baseLine + 4
                                                     tag:[[SFLogTag alloc] initWithClass:self.class selector:nil]
                                                  format:@"This is a debug message: %d"
                                                 message:@"This is a debug message: 1"]);
    XCTAssertEqualObjects(recorder.results[2],
                          [[LogItem alloc] initWithAsync:YES
                                                   level:DDLogLevelVerbose
                                                    flag:DDLogFlagInfo
                                                 context:1
                                                    file:__FILE__
                                                function:"-[SFLoggerTests testMacroLogging]"
                                                    line:baseLine + 6
                                                     tag:[[SFLogTag alloc] initWithClass:self.class selector:nil]
                                                  format:@"This is a info message"
                                                 message:@"This is a info message"]);
    XCTAssertEqualObjects(recorder.results[3],
                          [[LogItem alloc] initWithAsync:YES
                                                   level:DDLogLevelVerbose
                                                    flag:DDLogFlagWarning
                                                 context:1
                                                    file:__FILE__
                                                function:"-[SFLoggerTests testMacroLogging]"
                                                    line:baseLine + 8
                                                     tag:[[SFLogTag alloc] initWithClass:self.class selector:nil]
                                                  format:@"This is a warning %@"
                                                 message:@"This is a warning message"]);
    XCTAssertEqualObjects(recorder.results[4],
                          [[LogItem alloc] initWithAsync:NO
                                                   level:DDLogLevelVerbose
                                                    flag:DDLogFlagError
                                                 context:1
                                                    file:__FILE__
                                                function:"-[SFLoggerTests testMacroLogging]"
                                                    line:baseLine + 10
                                                     tag:[[SFLogTag alloc] initWithClass:self.class selector:nil]
                                                  format:@"This is a error message"
                                                 message:@"This is a error message"]);
}

- (void)testClassMethods {
    SFLogger *logger = [SFLogger sharedLogger];
    LogStorageRecorder *recorder = [LogStorageRecorder new];
    logger->_ddLog = recorder;
    logger.logLevel = SFLogLevelVerbose;
    
    LogItem *expected = [[LogItem alloc] initWithAsync:YES
                                                 level:DDLogLevelVerbose
                                                  flag:DDLogFlagError
                                               context:1
                                                  file:nil
                                              function:nil
                                                  line:0
                                                   tag:[[SFLogTag alloc] initWithClass:self.class selector:nil]
                                                format:@"This is a error message"
                                               message:@"This is a error message"];
    
    [SFLogger log:self.class level:SFLogLevelError msg:@"This is a error message"];
    XCTAssertEqual(recorder.results.count, 1U);
    XCTAssertEqualObjects(recorder.results.lastObject, expected);
    [recorder.results removeAllObjects];
    
    [SFLogger log:self.class level:SFLogLevelError format:@"This is a error message"];
    XCTAssertEqual(recorder.results.count, 1U);
    XCTAssertEqualObjects(recorder.results.lastObject, expected);
    [recorder.results removeAllObjects];
    
    [SFLogger log:self.class level:SFLogLevelError identifier:kSFLogIdentifierDefault msg:@"This is a error message"];
    XCTAssertEqual(recorder.results.count, 1U);
    XCTAssertEqualObjects(recorder.results.lastObject, expected);
    [recorder.results removeAllObjects];
    
    [SFLogger log:self.class level:SFLogLevelError identifier:kSFLogIdentifierDefault format:@"This is a error message"];
    XCTAssertEqual(recorder.results.count, 1U);
    XCTAssertEqualObjects(recorder.results.lastObject, expected);
    [recorder.results removeAllObjects];
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [SFLogger log:self.class level:SFLogLevelError context:0 msg:@"This is a error message"];
#pragma clang diagnostic pop
    XCTAssertEqual(recorder.results.count, 1U);
    XCTAssertEqualObjects(recorder.results.lastObject, expected);
    [recorder.results removeAllObjects];
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [SFLogger log:self.class level:SFLogLevelError context:MobileSDKLogContext msg:@"This is a error message"];
#pragma clang diagnostic pop
    XCTAssertEqual(recorder.results.count, 1U);
    XCTAssertEqualObjects(recorder.results.lastObject, expected);
    [recorder.results removeAllObjects];
}

- (void)testObjectMethods {
    SFLogger *logger = [SFLogger sharedLogger];
    LogStorageRecorder *recorder = [LogStorageRecorder new];
    logger->_ddLog = recorder;
    logger.logLevel = SFLogLevelVerbose;
    
    LogItem *expectedMsg = [[LogItem alloc] initWithAsync:YES
                                                    level:DDLogLevelVerbose
                                                     flag:DDLogFlagError
                                                  context:1
                                                     file:nil
                                                 function:nil
                                                     line:0
                                                      tag:[[SFLogTag alloc] initWithClass:self.class selector:nil]
                                                   format:@"This is a error message"
                                                  message:nil];
    [self log:SFLogLevelError msg:@"This is a error message"];
    XCTAssertEqual(recorder.results.count, 1U);
    XCTAssertEqualObjects(recorder.results.lastObject, expectedMsg);
    [recorder.results removeAllObjects];
    
    [self log:SFLogLevelError identifier:kSFLogLevelInfoString msg:@"This is a error message"];
    XCTAssertEqual(recorder.results.count, 1U);
    XCTAssertEqualObjects(recorder.results.lastObject, expectedMsg);
    [recorder.results removeAllObjects];
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [self log:SFLogLevelError context:0 msg:@"This is a error message"];
#pragma clang diagnostic pop
    XCTAssertEqual(recorder.results.count, 1U);
    XCTAssertEqualObjects(recorder.results.lastObject, expectedMsg);
    [recorder.results removeAllObjects];

    LogItem *expectedFormat = [[LogItem alloc] initWithAsync:YES
                                                 level:DDLogLevelVerbose
                                                  flag:DDLogFlagError
                                               context:1
                                                  file:nil
                                              function:nil
                                                  line:0
                                                   tag:[[SFLogTag alloc] initWithClass:self.class selector:nil]
                                                format:@"This is a error message"
                                               message:@"This is a error message"];
    
    [self log:SFLogLevelError format:@"This is a error message"];
    XCTAssertEqual(recorder.results.count, 1U);
    XCTAssertEqualObjects(recorder.results.lastObject, expectedFormat);
    [recorder.results removeAllObjects];
    
    [self log:SFLogLevelError identifier:kSFLogIdentifierDefault format:@"This is a error message"];
    XCTAssertEqual(recorder.results.count, 1U);
    XCTAssertEqualObjects(recorder.results.lastObject, expectedFormat);
    [recorder.results removeAllObjects];
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [self log:SFLogLevelError context:MobileSDKLogContext format:@"This is a error message"];
#pragma clang diagnostic pop
    XCTAssertEqual(recorder.results.count, 1U);
    XCTAssertEqualObjects(recorder.results.lastObject, expectedFormat);
    [recorder.results removeAllObjects];
}

static NSString *identifier = @"com.salesforce.test";
static NSInteger kMyLogContext;
#define MyLogError(frmt, ...)      SFLogErrorToContext(kMyLogContext, self, frmt, ##__VA_ARGS__)
#define MyLogWarn(frmt, ...)        SFLogWarnToContext(kMyLogContext, self, frmt, ##__VA_ARGS__)
#define MyLogInfo(frmt, ...)        SFLogInfoToContext(kMyLogContext, self, frmt, ##__VA_ARGS__)
#define MyLogDebug(frmt, ...)      SFLogDebugToContext(kMyLogContext, self, frmt, ##__VA_ARGS__)
#define MyLogVerbose(frmt, ...)  SFLogVerboseToContext(kMyLogContext, self, frmt, ##__VA_ARGS__)

- (void)testCustomLogMacros {
    SFLogger *logger = [SFLogger sharedLogger];
    LogStorageRecorder *recorder = [LogStorageRecorder new];
    logger->_ddLog = recorder;
    logger.logLevel = SFLogLevelVerbose;
    
    kMyLogContext = [logger registerIdentifier:identifier];
    XCTAssertNotEqual(kMyLogContext, 0U);
    XCTAssertEqual([logger logLevelForIdentifier:identifier], SFLogLevelError);
    [logger setLogLevel:SFLogLevelVerbose forIdentifier:identifier];
    
    XCTAssertEqual(recorder.results.count, 0U);
    MyLogVerbose(@"This is a verbose message");
    XCTAssertEqual(recorder.results.count, 1U);
    XCTAssertEqual(recorder.results[0].context, kMyLogContext);
    
    MyLogDebug(@"This is a debug message: %d", 1U);
    XCTAssertEqual(recorder.results.count, 2U);
    XCTAssertEqual(recorder.results[1].context, kMyLogContext);
    
    MyLogInfo(@"This is a info message");
    XCTAssertEqual(recorder.results.count, 3U);
    XCTAssertEqual(recorder.results[2].context, kMyLogContext);
    
    MyLogWarn(@"This is a warning %@", @"message");
    XCTAssertEqual(recorder.results.count, 4U);
    XCTAssertEqual(recorder.results[3].context, kMyLogContext);

    MyLogError(@"This is a error message");
    XCTAssertEqual(recorder.results.count, 5U);
    XCTAssertEqual(recorder.results[4].context, kMyLogContext);
}

- (NSString*)trimmedLogWithString:(NSString*)string {
    NSError *error = nil;
    static NSRegularExpression *regex = nil;
    if (!regex) {
        regex = [NSRegularExpression regularExpressionWithPattern:@"^([\\d/]+ [\\d:\\.]+)\\sSalesforceSDKCoreTestApp\\[[\\w:]+\\]\\s(.*)"
                                                          options:0
                                                            error:&error];
        XCTAssertNil(error);
    }
    
    NSArray *matches = [regex matchesInString:string options:0 range:NSMakeRange(0, string.length)];
    NSString *result = nil;
    if (matches.count > 0) {
        NSTextCheckingResult *match = matches.lastObject;
        if (match.numberOfRanges > 2) {
            NSRange matchRange = [match rangeAtIndex:2];
            if (matchRange.location != NSNotFound) {
                result = [string substringWithRange:matchRange];
            }
        }
    }
    return result;
}

- (void)testLogFormatter {
    SFLogger *logger = [SFLogger sharedLogger];
    logger->_ddLog = [[DDLog alloc] init];

    TestLogger *testLogger = [[TestLogger alloc] init];
    testLogger.logFormatter = [[SFCocoaLumberJackCustomFormatter alloc] initWithLogger:logger];
    [logger->_ddLog addLogger:testLogger];
    logger.logLevel = SFLogLevelVerbose;
    [logger registerIdentifier:@"com.salesforce.test"];
    
    [SFLogger log:[LogStorageRecorder class] level:SFLogLevelError msg:@"Log message"];
    [SFLogger log:[LogStorageRecorder class] level:SFLogLevelError identifier:@"com.salesforce.test" msg:@"Log message"];
    SFLogError(@"Log message");
    [logger->_ddLog flushLog];
    
    [NSThread sleepForTimeInterval:2.0];
    
    XCTAssertEqual(testLogger.messages.count, 3U);
    XCTAssertEqualObjects([self trimmedLogWithString:testLogger.messages[0]], @"ERROR com.salesforce <LogStorageRecorder>: Log message");
    XCTAssertEqualObjects([self trimmedLogWithString:testLogger.messages[1]], @"ERROR com.salesforce.test <LogStorageRecorder>: Log message");
    XCTAssertEqualObjects([self trimmedLogWithString:testLogger.messages[2]], @"ERROR com.salesforce <SFLoggerTests.m:659 -[SFLoggerTests testLogFormatter]>: Log message");

}

- (void)testExtraLoggers {
    SFLogger *logger = [SFLogger sharedLogger];
    [logger resetLoggers];
    logger.logLevel = SFLogLevelVerbose;
    logger.logToFile = YES;
    logger.logToASL = YES;

    XCTestExpectation *expectation = [self expectationWithDescription:@"Rolling log file"];
    logger->_fileLogger.doNotReuseLogFiles = YES;
    [logger->_fileLogger rollLogFileWithCompletionBlock:^{
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:0.25 handler:^(NSError * _Nullable error) {
        NSLog(@"Waited for log rolling: %@", error);
    }];
    
    NSString *path = [[logger->_fileLogger currentLogFileInfo] filePath];
    SFLogWarn(@"Log warning");
    SFLogVerbose(@"Log verbose");
    [logger->_ddLog flushLog];
    
    [NSThread sleepForTimeInterval:2.0];
    
    NSError *error = nil;
    NSString *logContents = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
    XCTAssertNil(error);
    
    NSArray<NSString*> *messages = [logContents componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    XCTAssertEqual(messages.count, 3U);
    XCTAssertEqualObjects([self trimmedLogWithString:messages[0]], @"WARNING com.salesforce <SFLoggerTests.m:688 -[SFLoggerTests testExtraLoggers]>: Log warning");
    XCTAssertEqualObjects([self trimmedLogWithString:messages[1]], @"VERBOSE com.salesforce <SFLoggerTests.m:689 -[SFLoggerTests testExtraLoggers]>: Log verbose");

}



@end
