/*
 Copyright (c) 2015, salesforce.com, inc. All rights reserved.
 
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

#import <CocoaLumberjack/CocoaLumberjack.h>
#import <CocoaLumberjack/DDContextFilterLogFormatter.h>

#import "NSData+SFAdditions.h"
#import "SFLogger_Internal.h"
#import "SFPathUtil.h"
#import "NSString+SFAdditions.h"
#import <execinfo.h> // backtrace_symbols
#import "SFCocoaLumberJackCustomFormatter.h"

static inline SFLogFlag SFLogFlagForLogLevel(SFLogLevel level) {
    switch (level) {
        case SFLogLevelAll:
            return SFLogFlagVerbose;
            
        case SFLogLevelVerbose:
            return SFLogFlagVerbose;
            
        case SFLogLevelDebug:
            return SFLogFlagDebug;
            
        case SFLogLevelInfo:
            return SFLogFlagInfo;
            
        case SFLogLevelWarning:
            return SFLogFlagWarning;
            
        case SFLogLevelError:
        default:
            return SFLogFlagError;
    }
}

NSString * SFLogNameForLogLevel(SFLogLevel level) {
    switch (level) {
        case SFLogLevelVerbose:
            return kSFLogLevelVerboseString;
            
        case SFLogLevelDebug:
            return kSFLogLevelDebugString;
            
        case SFLogLevelInfo:
            return kSFLogLevelInfoString;
            
        case SFLogLevelWarning:
            return kSFLogLevelWarningString;
            
        case SFLogLevelError:
            return kSFLogLevelErrorString;
            
        default:
            return [NSString stringWithFormat:@"<unknown level %lu>", (unsigned long)level];
    }
}

NSString * SFLogNameForFlag(SFLogFlag flag) {
    switch (flag) {
        case SFLogFlagVerbose:
            return kSFLogLevelVerboseString;
            
        case SFLogFlagDebug:
            return kSFLogLevelDebugString;
            
        case SFLogFlagInfo:
            return kSFLogLevelInfoString;
            
        case SFLogFlagWarning:
            return kSFLogLevelWarningString;
            
        case SFLogFlagError:
            return kSFLogLevelErrorString;
            
        default:
            return [NSString stringWithFormat:@"<unknown flag %lu>", (unsigned long)flag];
    }
}

@interface SFLogger (PrivateLoggingMethods)

+ (void)logAsync:(BOOL)asynchronous
           level:(SFLogLevel)level
            flag:(SFLogFlag)flag
      identifier:(NSString*)identifier
            file:(const char *)file
        function:(const char *)function
            line:(NSUInteger)line
             tag:(id)tag
          format:(NSString *)format, ...;

- (void)logAsync:(BOOL)asynchronous
           level:(SFLogLevel)level
            flag:(SFLogFlag)flag
      identifier:(NSString*)identifier
            file:(const char *)file
        function:(const char *)function
            line:(NSUInteger)line
             tag:(id)tag
          format:(NSString *)format
            args:(va_list)args;

- (void)logAsync:(BOOL)asynchronous
           level:(SFLogLevel)level
            flag:(SFLogFlag)flag
         context:(NSInteger)context
            file:(const char *)file
        function:(const char *)function
            line:(NSUInteger)line
             tag:(id)tag
          format:(NSString *)format
            args:(va_list)args;

@end

NSString * const kSFLogLevelVerboseString = @"VERBOSE";
NSString * const kSFLogLevelDebugString = @"DEBUG";
NSString * const kSFLogLevelInfoString = @"INFO";
NSString * const kSFLogLevelWarningString = @"WARNING";
NSString * const kSFLogLevelErrorString = @"ERROR";
NSString * const kSFLogIdentifierDefault = @"com.salesforce";

static void * kObservingKey = &kObservingKey;
static NSString * const kSFLogLevelKey = @"logLevel";
SFLogLevel SFLoggerContextLogLevels[SF_LOG_MAX_IDENTIFIER_COUNT];

/////////////////

@implementation SFLogTag

- (instancetype)initWithClass:(Class)originClass selector:(SEL)selector {
    self = [self init];
    if (self) {
        _originClass = originClass;
        _selector = selector;
    }
    return self;
}

- (BOOL)isEqual:(SFLogTag*)object {
    BOOL result = YES;
    if (self == object) {
        result = YES;
    } else if (![object isMemberOfClass:self.class]) {
        result = NO;
    } else if (_originClass != object->_originClass) {
        result = NO;
    } else if (_selector != object->_selector) {
        result = NO;
    }
    return result;
}

@end

/////////////////

@implementation SFLogIdentifier

+ (NSSet*)keyPathsForValuesAffectingLogFlag {
    return [NSSet setWithObject:@"logLevel"];
}

- (instancetype)init {
    return [self initWithIdentifier:nil];
}

- (instancetype)initWithIdentifier:(NSString *)identifier {
    self = [super init];
    if (self) {
        _identifier = [identifier copy];
        _logLevel = SFLogLevelError;
        _logFlag = SFLogFlagError;
        
        // Default identifier receives a context of `1`, for backwards compatibility with MobileSDKLogContext
        if (!_identifier) {
            _context = 1;
        }
    }
    return self;
}

- (void)setLogLevel:(SFLogLevel)logLevel {
    _logLevel = logLevel;
    
    if (logLevel & SFLogFlagVerbose) {
        _logFlag = SFLogFlagVerbose;
    } else if (logLevel & SFLogFlagDebug) {
        _logFlag = SFLogFlagDebug;
    } else if (logLevel & SFLogFlagInfo) {
        _logFlag = SFLogFlagInfo;
    } else if (logLevel & SFLogFlagWarning) {
        _logFlag = SFLogFlagWarning;
    } else if (logLevel & SFLogFlagError) {
        _logFlag = SFLogFlagError;
    }
}

@end

/////////////////

@implementation NSObject (SFLogging)

+ (NSString*)loggingIdentifier {
    return nil;
}

- (void)log:(SFLogLevel)level msg:(NSString *)msg {
    [self log:level identifier:[self.class loggingIdentifier] msg:msg];
}

- (void)log:(SFLogLevel)level identifier:(NSString*)logIdentifier msg:(NSString *)msg {
    SFLogger *logger = [SFLogger sharedLogger];
    NSString *identifierString = [self.class loggingIdentifier];
    SFLogIdentifier *identifier = [logger logIdentifierForIdentifier:identifierString];
    
    [logger logAsync:YES
               level:identifier.logLevel
                flag:SFLogFlagForLogLevel(level)
             context:identifier.context
                file:nil
            function:nil
                line:0
                 tag:[[SFLogTag alloc] initWithClass:self.class selector:nil]
              format:msg
                args:nil];
}

- (void)log:(SFLogLevel)level format:(NSString *)format, ... {
    SFLogger *logger = [SFLogger sharedLogger];
    NSString *identifierString = [self.class loggingIdentifier];
    SFLogIdentifier *identifier = [logger logIdentifierForIdentifier:identifierString];
    
    va_list args;
    va_start(args, format);
    [logger logAsync:YES
               level:identifier.logLevel
                flag:SFLogFlagForLogLevel(level)
             context:identifier.context
                file:nil
            function:nil
                line:0
                 tag:[[SFLogTag alloc] initWithClass:self.class selector:nil]
              format:format
                args:args];
    va_end(args);
}

- (void)log:(SFLogLevel)level context:(SFLogContext)logContext msg:(NSString *)msg {
    [self log:level msg:msg];
}

- (void)log:(SFLogLevel)level context:(SFLogContext)logContext format:(NSString *)format, ... {
    SFLogger *logger = [SFLogger sharedLogger];
    SFLogIdentifier *identifier = [logger logIdentifierForIdentifier:nil];
    
    va_list args;
    va_start(args, format);
    [logger logAsync:YES
               level:identifier.logLevel
                flag:SFLogFlagForLogLevel(level)
             context:identifier.context
                file:nil
            function:nil
                line:0
                 tag:[[SFLogTag alloc] initWithClass:self.class selector:nil]
              format:format
                args:args];
    va_end(args);
}

- (void)log:(SFLogLevel)level identifier:(NSString*)logIdentifier format:(NSString *)format, ... {
    SFLogger *logger = [SFLogger sharedLogger];
    SFLogIdentifier *identifier = [logger logIdentifierForIdentifier:logIdentifier];
    
    va_list args;
    va_start(args, format);
    [logger logAsync:YES
               level:identifier.logLevel
                flag:SFLogFlagForLogLevel(level)
             context:identifier.context
                file:nil
            function:nil
                line:0
                 tag:[[SFLogTag alloc] initWithClass:self.class selector:nil]
              format:format
                args:args];
    va_end(args);
}

@end

@interface SFLogger ()

@property (nonatomic, weak) DDASLLogger *consoleLogger;

@end

static BOOL recordAssertion = NO;
static BOOL assertionRecorded = NO;

//////////////////

@interface DDLog (SFLogger) <SFLogStorage>
@end

@implementation DDLog (SFLogger)
@end

//////////////////

@implementation SFLogger

+ (instancetype)sharedLogger {
    static id sharedInstance = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _contextCounter = 2;
        _logIdentifiers = [NSMutableDictionary new];
        _logIdentifiersByContext = [NSMutableArray new];
        
        [self resetLoggers];

        SFLogIdentifier *defaultIdentifier = [[SFLogIdentifier alloc] initWithIdentifier:kSFLogIdentifierDefault];
        defaultIdentifier.logger = self;
        defaultIdentifier.context = 1;
        _logIdentifiers[kSFLogIdentifierDefault] = defaultIdentifier;
        _logIdentifiersByContext[0] = defaultIdentifier;
        _logIdentifiersByContext[1] = defaultIdentifier;

        [defaultIdentifier addObserver:self
                            forKeyPath:kSFLogLevelKey
                               options:(NSKeyValueObservingOptionNew |
                                        NSKeyValueObservingOptionInitial)
                               context:kObservingKey];
    }
    return self;
}

- (void)resetLoggers {
    if (![_ddLog isKindOfClass:[DDLog class]]) {
        _ddLog = [DDLog new];
    }
    [_ddLog removeAllLoggers];
    
    // configure logging
    // NOTE: We're poking the sharedInstance, but use a separate instance so we can change the log formatter.
    _ttyLogger = [DDTTYLogger sharedInstance];
    _ttyLogger.colorsEnabled = YES;
    [_ttyLogger setForegroundColor:[UIColor greenColor]
                   backgroundColor:nil
                           forFlag:DDLogFlagInfo];
    [_ttyLogger setForegroundColor:[UIColor redColor]
                   backgroundColor:nil
                           forFlag:DDLogFlagError];
    [_ttyLogger setForegroundColor:[UIColor orangeColor]
                   backgroundColor:nil
                           forFlag:DDLogFlagWarning];
    _ttyLogger.logFormatter = [[SFCocoaLumberJackCustomFormatter alloc] initWithLogger:self];
    [_ddLog addLogger:_ttyLogger];
    
    if (kSFASLLoggerEnabledDefault) {
        [_ddLog addLogger:[DDASLLogger sharedInstance]];
    }
    
    _fileLogger = [[DDFileLogger alloc] init];
    _fileLogger.rollingFrequency = 60 * 60 * 48; // 48 hour rolling
    _fileLogger.logFileManager.maximumNumberOfLogFiles = 3;
    _fileLogger.logFormatter = [[SFCocoaLumberJackCustomFormatter alloc] initWithLogger:self];
}

- (void)dealloc {
    for (SFLogIdentifier *identifier in _logIdentifiers.allValues) {
        [identifier removeObserver:self forKeyPath:kSFLogLevelKey context:kObservingKey];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context {
    if (context == kObservingKey) {
        if ([keyPath isEqualToString:kSFLogLevelKey] && [object isKindOfClass:[SFLogIdentifier class]]) {
            SFLogIdentifier *logIdentifier = (SFLogIdentifier*)object;
            NSUInteger context = MAX(1, logIdentifier.context);
            SFLoggerContextLogLevels[context - 1] = logIdentifier.logLevel;
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (SFLogIdentifier*)registerIdentifierObject:(NSString*)identifier {
    SFLogIdentifier *result = nil;
    
    NSAssert1(identifier != nil, @"Must supply a nonnull identifier to %@", NSStringFromSelector(_cmd));
    @synchronized(_logIdentifiers) {
        NSAssert1(_logIdentifiers[identifier] == nil, @"Log identifier %@ already registered", identifier);
        NSAssert3(_contextCounter < SF_LOG_MAX_IDENTIFIER_COUNT - 1,
                  @"Call to %@ to register identifier %@ exceeds the maximum identifier count of %d",
                  NSStringFromSelector(_cmd),
                  identifier,
                  SF_LOG_MAX_IDENTIFIER_COUNT);
        
        result = [[SFLogIdentifier alloc] initWithIdentifier:identifier];
        result.logger = self;
        result.context = atomic_fetch_add_explicit(&_contextCounter, 1, memory_order_relaxed);
        _logIdentifiers[identifier] = result;
        _logIdentifiersByContext[result.context] = result;

        [result addObserver:self
                 forKeyPath:kSFLogLevelKey
                    options:(NSKeyValueObservingOptionNew |
                             NSKeyValueObservingOptionInitial)
                    context:kObservingKey];
    }
    
    return result;
}

- (NSInteger)registerIdentifier:(NSString*)identifier {
    SFLogIdentifier *identifierObject = [self logIdentifierForIdentifier:identifier];
    return identifierObject.context;
}

- (BOOL)shouldLogToASL {
    return [_ddLog.allLoggers containsObject:[DDASLLogger sharedInstance]];
}

- (void)setLogToASL:(BOOL)logToASL {
    BOOL hasLogger = [self shouldLogToASL];
    if (logToASL && !hasLogger) {
        [_ddLog addLogger:[DDASLLogger sharedInstance]];
    } else if (!logToASL && hasLogger) {
        [_ddLog removeLogger:[DDASLLogger sharedInstance]];
    }
}

+ (NSInteger)contextForIdentifier:(NSString*)identifier {
    return [self.sharedLogger contextForIdentifier:identifier];
}

- (NSInteger)contextForIdentifier:(NSString*)identifier {
    return [self logIdentifierForIdentifier:identifier].context;
}

- (SFLogLevel)logLevel {
    return [self logLevelForIdentifier:nil];
}

- (void)setLogLevel:(SFLogLevel)logLevel {
    [self setLogLevel:logLevel forIdentifier:nil];
}

- (SFLogLevel)logLevelForIdentifier:(NSString*)identifier {
    return [self logIdentifierForIdentifier:identifier].logLevel;
}

- (void)setLogLevel:(SFLogLevel)logLevel forIdentifier:(NSString*)identifier {
    [self logIdentifierForIdentifier:identifier].logLevel = logLevel;
}

- (void)setLogLevel:(SFLogLevel)logLevel forIdentifiersWithPrefix:(nonnull NSString*)identifierPrefix {
    NSArray<SFLogIdentifier*> *matchingIdentifiers = [_logIdentifiers.allValues filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"identifier beginswith %@", identifierPrefix]];
    for (SFLogIdentifier *identifer in matchingIdentifiers) {
        identifer.logLevel = logLevel;
    }
}

+ (SFLogIdentifier*)logIdentifierForIdentifier:(NSString*)identifier {
    return [self.sharedLogger logIdentifierForIdentifier:identifier];
}

- (SFLogIdentifier*)logIdentifierForIdentifier:(NSString*)identifier {
    SFLogIdentifier *result = nil;
    @synchronized(_logIdentifiers) {
        if (!identifier) {
            identifier = kSFLogIdentifierDefault;
        }
        
        result = _logIdentifiers[identifier];
        if (!result) {
            result = _logIdentifiers[identifier] = [self registerIdentifierObject:identifier];
        }
    }
    return result;
}

- (SFLogIdentifier*)logIdentifierForContext:(NSInteger)context {
    SFLogIdentifier *result = nil;
    if (context < _logIdentifiersByContext.count) {
        result = _logIdentifiersByContext[context];
    }
    return result;
}

#pragma mark Public logging methods

+ (void)log:(Class)cls level:(SFLogLevel)level msg:(NSString *)msg {
    NSString *identifierString = [cls loggingIdentifier];
    SFLogIdentifier *identifier = [self logIdentifierForIdentifier:identifierString];

    [self logAsync:YES
             level:identifier.logLevel
              flag:SFLogFlagForLogLevel(level)
        identifier:identifierString
              file:nil
          function:nil
              line:0
               tag:[[SFLogTag alloc] initWithClass:cls selector:nil]
            format:msg];
}

+ (void)log:(Class)cls level:(SFLogLevel)level identifier:(NSString*)logIdentifier msg:(NSString *)msg {
    SFLogIdentifier *identifier = [self logIdentifierForIdentifier:logIdentifier];
    
    [self logAsync:YES
             level:identifier.logLevel
              flag:SFLogFlagForLogLevel(level)
        identifier:logIdentifier
              file:nil
          function:nil
              line:0
               tag:[[SFLogTag alloc] initWithClass:cls selector:nil]
            format:msg];
}

+ (void)log:(Class)cls level:(SFLogLevel)level identifier:(NSString*)logIdentifier format:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    [self log:cls level:level identifier:logIdentifier msg:format arguments:args];
    va_end(args);
}

+ (void)log:(Class)cls level:(SFLogLevel)level format:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    [self log:cls level:level identifier:nil msg:format arguments:args];
    va_end(args);
}

#pragma mark -

- (NSString *)logFile {
    NSString *result = nil;
    if (_fileLogger) {
        NSArray *logFiles = [_fileLogger.logFileManager sortedLogFilePaths];
        if (logFiles.count > 0) {
            result = logFiles[0];
        }
    }
    return result;
}

+ (void)applyLogLevelFromPreferences {
    NSUInteger logLevel = [[NSUserDefaults standardUserDefaults] integerForKey:@"PrefLogLevel"];
    switch (logLevel) {
        case 1:
            [[self sharedLogger] setLogLevel:SFLogLevelDebug forIdentifier:nil];
            break;
            
        case 2:
            [[self sharedLogger] setLogLevel:SFLogLevelInfo forIdentifier:nil];
            break;
            
        case 3:
            [[self sharedLogger] setLogLevel:SFLogLevelWarning forIdentifier:nil];
            break;
            
        case 4:
            [[self sharedLogger] setLogLevel:SFLogLevelError forIdentifier:nil];
            break;
            
        default:
            [[self sharedLogger] setLogLevel:SFLogLevelVerbose forIdentifier:nil];
            break;
    }
}

- (void)setLogToFile:(BOOL)logToFile {
    @synchronized(self) {
        if (logToFile) {
            if (!_logToFile) {
                _logToFile = YES;
                
                // add file logger
                [_ddLog addLogger:_fileLogger];
            }
        } else {
            if (_logToFile) {
                _logToFile = NO;
                
                // remove existing log files
                NSFileManager *fileManager = [[NSFileManager alloc] init];
                NSArray *logFiles = [_fileLogger.logFileManager sortedLogFilePaths];
                for (NSString *logFile in logFiles) {
                    [fileManager removeItemAtPath:logFile error:nil];
                }
                
                // remove file logger
                [_ddLog removeLogger:_fileLogger];
            }
        }
    }
}

+ (void)log:(Class)cls level:(SFLogLevel)level msg:(NSString *)msg arguments:(va_list)args {
    NSString *formattedMsg = [[NSString alloc] initWithFormat:msg arguments:args];
    [self log:cls level:level msg:formattedMsg];
}

+ (void)log:(Class)cls level:(SFLogLevel)level identifier:(NSString*)logIdentifier msg:(NSString *)msg arguments:(va_list)args {
    NSString *formattedMsg = [[NSString alloc] initWithFormat:msg arguments:args];
    [self log:cls level:level identifier:logIdentifier msg:formattedMsg];
}

- (NSString *)logFileContents:(NSError**)error {
    if (![self shouldLogToFile]) {
        return nil;
    }
    
	NSString *logFilePath = [self logFile];
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    if ([fileManager fileExistsAtPath:logFilePath]) {
        NSString *fileContent = [NSString stringWithContentsOfFile:logFilePath
                                                          encoding:NSUTF8StringEncoding
                                                             error:error];
        return fileContent;
    }
    return nil;
}


+ (void)logAssertionFailureInMethod:(SEL)method object:(id)obj file:(NSString *)file lineNumber:(NSUInteger)line description:(NSString *)desc, ... {
#ifndef NS_BLOCK_ASSERTIONS
    SFLogIdentifier *identifier = [self logIdentifierForIdentifier:nil];

    NSString *message = [NSString stringWithFormat:@"ASSERTION FAILURE: [%@ %@] [file:%@ line:%lu]: %@",
                         NSStringFromClass([obj class]),
                         NSStringFromSelector(method),
                         file,
                         (unsigned long)line,
                         desc];
    va_list args;
    va_start(args, desc);
    [self.sharedLogger logAsync:NO
                          level:identifier.logLevel
                           flag:SFLogFlagError
                        context:identifier.context
                           file:[file cStringUsingEncoding:NSUTF8StringEncoding]
                       function:[NSStringFromSelector(method) cStringUsingEncoding:NSUTF8StringEncoding]
                           line:line
                            tag:[[SFLogTag alloc] initWithClass:[obj class] selector:method]
                         format:message
                           args:args];
    va_end(args);
    
    /* log backtrace: */
    void *array[100];
    int size;
    char **strings;
    size_t i;
    
    size = backtrace (array, 100);
    strings = backtrace_symbols (array, size);
    
    NSMutableString *stackTraces = [[NSMutableString alloc] init];
    for (i = 0; i < size; i++) {
        [stackTraces appendFormat:@"%s\n", strings[i]];
    }
    
    free(strings);
    [self.sharedLogger logAsync:NO
                          level:identifier.logLevel
                           flag:SFLogFlagError
                        context:identifier.context
                           file:[file cStringUsingEncoding:NSUTF8StringEncoding]
                       function:[NSStringFromSelector(method) cStringUsingEncoding:NSUTF8StringEncoding]
                           line:line
                            tag:[[SFLogTag alloc] initWithClass:[obj class] selector:method]
                         format:stackTraces
                           args:nil];
    
    if (recordAssertion) {
        [self setAssertionRecorded:YES];
    } else {
#ifdef DEBUG
        [[NSNotificationCenter defaultCenter] postNotificationName:SFApplicationWillAbortOrExitNotification object:nil userInfo:nil];
        abort();
#endif /* DEBUG */
    }
#endif /* NS_BLOCK_ASSERTIONS */
    
}

+ (void)setRecordAssertionEnabled:(BOOL)enabled {
    recordAssertion = enabled;
}

+ (void)setAssertionRecorded:(BOOL)flag {
    @synchronized (self) {
        assertionRecorded = flag;
    }
}

+ (BOOL)assertionRecordedAndClear {
    BOOL recorded = NO;
    @synchronized (self) {
        recorded = assertionRecorded;
        assertionRecorded = NO;
    }
    return recorded;
}

@end

@implementation SFLogger (MacroHelper)

+ (void)logAsync:(BOOL)asynchronous
           level:(SFLogLevel)level
            flag:(SFLogFlag)flag
         context:(NSInteger)context
            file:(const char *)file
        function:(const char *)function
            line:(NSUInteger)line
             tag:(id)tag
          format:(NSString *)format, ...
{
    va_list args;
    
    if (format) {
        va_start(args, format);
        if (tag && ![tag isKindOfClass:[SFLogTag class]]) {
            if ([tag conformsToProtocol:@protocol(NSObject)]) {
                tag = [[SFLogTag alloc] initWithClass:[(NSObject*)tag class] selector:nil];
            } else {
                tag = [[SFLogTag alloc] initWithClass:tag selector:nil];
            }
        }
        
        [self.sharedLogger logAsync:asynchronous
                              level:level
                               flag:flag
                            context:context
                               file:file
                           function:function
                               line:line
                                tag:tag
                             format:format
                               args:args];
        va_end(args);
    }
}

@end

@implementation SFLogger (PrivateLoggingMethods)

+ (void)logAsync:(BOOL)asynchronous
           level:(SFLogLevel)level
            flag:(SFLogFlag)flag
      identifier:(NSString*)identifier
            file:(const char *)file
        function:(const char *)function
            line:(NSUInteger)line
             tag:(id)tag
          format:(NSString *)format, ...
{
    va_list args;
    if (format) {
        va_start(args, format);
        [self.sharedLogger logAsync:asynchronous
                              level:level
                               flag:flag
                            context:[self contextForIdentifier:identifier]
                               file:file
                           function:function
                               line:line
                                tag:tag
                             format:format
                               args:args];
        va_end(args);
    }
}

- (void)logAsync:(BOOL)asynchronous
           level:(SFLogLevel)level
            flag:(SFLogFlag)flag
      identifier:(NSString*)identifier
            file:(const char *)file
        function:(const char *)function
            line:(NSUInteger)line
             tag:(id)tag
          format:(NSString *)format
            args:(va_list)args
{
    if (level & flag) {
        [_ddLog log:asynchronous
              level:(DDLogLevel)level
               flag:(DDLogFlag)flag
            context:[self contextForIdentifier:identifier]
               file:file
           function:function
               line:line
                tag:tag
             format:format
               args:args];
    }
}

- (void)logAsync:(BOOL)asynchronous
           level:(SFLogLevel)level
            flag:(SFLogFlag)flag
         context:(NSInteger)context
            file:(const char *)file
        function:(const char *)function
            line:(NSUInteger)line
             tag:(id)tag
          format:(NSString *)format
            args:(va_list)args
{
    if (level & flag) {
        [_ddLog log:asynchronous
              level:(DDLogLevel)level
               flag:(DDLogFlag)flag
            context:context
               file:file
           function:function
               line:line
                tag:tag
             format:format
               args:args];
    }
}

@end

@implementation SFLogger (Deprecated)

+ (void)log:(Class)cls level:(SFLogLevel)level context:(SFLogContext)logContext msg:(NSString *)msg {
    [self log:cls level:level msg:msg];
}

+ (void)log:(Class)cls level:(SFLogLevel)level context:(SFLogContext)logContext format:(NSString *)msg, ... {
    va_list args;
    if (msg) {
        va_start(args, msg);
        [self log:cls level:level msg:msg arguments:args];
        va_end(args);
    }
}

+ (void)setLogLevel:(SFLogLevel)newLevel {
    SFLogger *logger = [self sharedLogger];
    logger.logLevel = newLevel;
}

+ (SFLogLevel)logLevel {
    SFLogger *logger = [self sharedLogger];
    return logger.logLevel;
}

+ (void)logToFile:(BOOL)logToFile {
    [SFLogger sharedLogger].logToFile = logToFile;
}

+ (NSString *)logFileContents {
    return [[SFLogger sharedLogger] logFileContents:nil];
}

+ (SFLogLevel)logLevelForString:(NSString *)value {
    
    // Default to most restrictive level
    SFLogLevel level = SFLogLevelError;
    if ([value caseInsensitiveCompare:kSFLogLevelVerboseString] == NSOrderedSame) {
        level = SFLogLevelVerbose;
    } else if ([value caseInsensitiveCompare:kSFLogLevelDebugString] == NSOrderedSame) {
        level = SFLogLevelDebug;
    } else if ([value caseInsensitiveCompare:kSFLogLevelInfoString] == NSOrderedSame) {
        level = SFLogLevelInfo;
    } else if ([value caseInsensitiveCompare:kSFLogLevelWarningString] == NSOrderedSame) {
        level = SFLogLevelWarning;
    } else if ([value caseInsensitiveCompare:kSFLogLevelErrorString] == NSOrderedSame) {
        level = SFLogLevelError;
    }
    
    return level;
}

//Formatter
+ (void)setBlackListFilter
{
}

+ (void)setWhiteListFilter
{
}

//black list
+ (void)blackListFilterAddContext:(SFLogContext)logContext
{
}

+ (void)blackListFilterRemoveContext:(SFLogContext)logContext
{
}

+ (NSArray *)contextsOnBlackList
{
    return nil;
}

+ (BOOL)isOnContextBlackList:(SFLogContext)logContext
{
    return NO;
}

//white list
+ (void)whiteListFilterAddContext:(SFLogContext)logContext
{
}

+ (void)whiteListFilterRemoveContext:(SFLogContext)logContext
{
}

//Individual Context Filter -- Resets White Filter and filters a single context
//can still add to it
+ (void)filterByContext:(SFLogContext)logContext; //if you want to RESET the whitelist and filter only ONE context
{
}

+ (NSArray *)contextsOnWhiteList
{
    return nil;
}

+ (BOOL)isOnContextWhiteList:(SFLogContext)logContext
{
    return NO;
}

+ (void) resetLoggingFilter
{
}

@end
