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
#import <CocoaLumberjack/DDASLLogger.h>
#import <CocoaLumberjack/DDContextFilterLogFormatter.h>
#import <CocoaLumberjack/DDFileLogger.h>
#import <CocoaLumberjack/DDLog.h>
#import <CocoaLumberjack/DDTTYLogger.h>
#import "NSData+SFAdditions.h"
#import "SFLogger.h"
#import "SFPathUtil.h"
#import "NSString+SFAdditions.h"
#import <execinfo.h> // backtrace_symbols
#import "SFCocoaLumberJackCustomFormatter.h"

//create alternatives to DDLogVerbose, Error, Warn, etc.
//operate the same way but have custom log contexts
#define LogWithContextVerbose(context, frmt, ...) LOG_MAYBE(LOG_ASYNC_ENABLED, ddLogLevel, DDLogFlagVerbose, context, nil, __PRETTY_FUNCTION__, frmt, ##__VA_ARGS__)
#define LogWithContextDebug(context, frmt, ...) LOG_MAYBE(LOG_ASYNC_ENABLED, ddLogLevel, DDLogFlagDebug, context, nil, __PRETTY_FUNCTION__, frmt, ##__VA_ARGS__)
#define LogWithContextError(context, frmt, ...) LOG_MAYBE(NO, ddLogLevel, DDLogFlagError, context, nil, __PRETTY_FUNCTION__, frmt, ##__VA_ARGS__)
#define LogWithContextInfo(context, frmt, ...) LOG_MAYBE(LOG_ASYNC_ENABLED, ddLogLevel, DDLogFlagInfo, context, nil, __PRETTY_FUNCTION__, frmt, ##__VA_ARGS__)
#define LogWithContextWarn(context, frmt, ...) LOG_MAYBE(LOG_ASYNC_ENABLED, ddLogLevel, DDLogFlagWarning, context, nil, __PRETTY_FUNCTION__, frmt, ##__VA_ARGS__)

#ifdef DEBUG
static int ddLogLevel = DDLogLevelVerbose;
#else
static int ddLogLevel = DDLogLevelInfo;
#endif

NSString * const kSFLogLevelVerboseString = @"VERBOSE";
NSString * const kSFLogLevelDebugString = @"DEBUG";
NSString * const kSFLogLevelInfoString = @"INFO";
NSString * const kSFLogLevelWarningString = @"WARNING";
NSString * const kSFLogLevelErrorString = @"ERROR";

@implementation NSObject (Logging)

- (void)log:(SFLogLevel)level msg:(NSString *)msg {
    [SFLogger log:[self class] level:level msg:msg];
}

- (void)log:(SFLogLevel)level format:(NSString *)msg, ... {
    va_list list;
    va_start(list, msg);
    if (level >= [SFLogger logLevel]) {
        NSString *formattedMsg = [[NSString alloc] initWithFormat:msg arguments:list];
        [SFLogger log:[self class] level:level msg:formattedMsg];
    }
    va_end(list);
}

- (void)log:(SFLogLevel)level context:(SFLogContext)logContext msg:(NSString *)msg {
    [SFLogger log:[self class] level:level context:logContext msg:msg];
}

- (void)log:(SFLogLevel)level context:(SFLogContext)logContext format:(NSString *)msg, ... {
    va_list list;
    va_start(list, msg);
    if (level >= [SFLogger logLevel]) {
        NSString *formattedMsg = [[NSString alloc] initWithFormat:msg arguments:list];
        [SFLogger log:[self class] level:level context:logContext msg:formattedMsg];
    }
    va_end(list);
}

@end

@interface SFLogger ()

+ (NSString *)levelName:(SFLogLevel)level;

@end

static DDFileLogger *fileLogger;
static DDContextBlacklistFilterLogFormatter *blackListFormatter;
static DDContextWhitelistFilterLogFormatter *whiteListFormatter;
static BOOL recordAssertion = NO;
static BOOL assertionRecorded = NO;
static BOOL loggingToFile = NO;

@implementation SFLogger

+ (void)initialize {

	// configure logging
    DDTTYLogger *ttyLogger = [DDTTYLogger sharedInstance];
    [ttyLogger setColorsEnabled:YES];
    [ttyLogger setForegroundColor:[UIColor greenColor] backgroundColor:nil forFlag:DDLogFlagInfo];
    [ttyLogger setForegroundColor:[UIColor redColor] backgroundColor:nil forFlag:DDLogFlagError];
    [ttyLogger setForegroundColor:[UIColor orangeColor] backgroundColor:nil forFlag:DDLogFlagWarning];
    
    if (nil == blackListFormatter)
    {
        blackListFormatter = [[DDContextBlacklistFilterLogFormatter alloc] init];
    }
    if (nil == whiteListFormatter)
    {
        whiteListFormatter = [[DDContextWhitelistFilterLogFormatter alloc] init];
    }
    [ttyLogger setLogFormatter:blackListFormatter];
    
    [DDLog addLogger:ttyLogger];
    
    #ifdef DEBUG
    [DDLog addLogger:[DDASLLogger sharedInstance]];
    #endif
    
    if (nil == fileLogger) {
        fileLogger = [[DDFileLogger alloc] init];
        fileLogger.rollingFrequency = 60 * 60 * 48; // 48 hour rolling
        fileLogger.logFileManager.maximumNumberOfLogFiles = 3;
        [fileLogger setLogFormatter:[[SFCocoaLumberJackCustomFormatter alloc] init]];
    }
}

+ (void)setLogLevel:(SFLogLevel)newLevel {
	switch (newLevel) {
        case SFLogLevelInfo:
            ddLogLevel = DDLogLevelInfo;
            break;
        case SFLogLevelWarning:
            ddLogLevel = DDLogLevelWarning;
            break;
        case SFLogLevelError:
            ddLogLevel = DDLogLevelError;
            break;
        case SFLogLevelDebug:
            ddLogLevel = DDLogLevelDebug;
            break;
        default:
            ddLogLevel = DDLogLevelVerbose;
            break;
    }
}

+ (SFLogLevel)logLevel {
    switch (ddLogLevel) {
        case DDLogLevelInfo:
            return SFLogLevelInfo;
            break;
        case DDLogLevelWarning:
            return SFLogLevelWarning;
            break;
        case DDLogLevelError:
            return SFLogLevelError;
            break;
        case DDLogLevelDebug:
            return SFLogLevelDebug;
            break;
        default:
            return SFLogLevelVerbose;
            break;
    }
}

+ (NSString *)logFile {
    if (nil == fileLogger) {
        return nil;
    }
    
    NSArray *logFiles = [fileLogger.logFileManager sortedLogFilePaths];
    if (nil == logFiles || logFiles.count == 0) {
        return nil;
    }
	return logFiles[0];
}

+ (void)applyLogLevelFromPreferences {
    NSUInteger logLevel = [[NSUserDefaults standardUserDefaults] integerForKey:@"PrefLogLevel"];
    switch (logLevel) {
        case 1:
            [self setLogLevel:SFLogLevelDebug];
            break;
            
        case 2:
            [self setLogLevel:SFLogLevelInfo];
            break;
            
        case 3:
            [self setLogLevel:SFLogLevelWarning];
            break;
            
        case 4:
            [self setLogLevel:SFLogLevelError];
            break;
            
        default:
            [self setLogLevel:SFLogLevelVerbose];
            break;
    }
}

+ (void)logToFile:(BOOL)logToFile {
    @synchronized([self class]) {
        if (logToFile) {
            if (!loggingToFile) {
                loggingToFile = YES;
                
                // add file logger
                [DDLog addLogger:fileLogger];
            }
        } else {
            if (loggingToFile) {
                loggingToFile = NO;
                
                // remove existing log files
                NSFileManager *fileManager = [[NSFileManager alloc] init];
                NSArray *logFiles = [fileLogger.logFileManager sortedLogFilePaths];
                for (NSString *logFile in logFiles) {
                    [fileManager removeItemAtPath:logFile error:nil];
                }
                
                // remove file logger
                [DDLog removeLogger:fileLogger];
            }
        }
    }
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

+ (NSString *)levelName:(SFLogLevel)level {
	switch (level) {
        case SFLogLevelVerbose  : return kSFLogLevelVerboseString;
		case SFLogLevelDebug    : return kSFLogLevelDebugString;
		case SFLogLevelInfo     : return kSFLogLevelInfoString;
		case SFLogLevelWarning  : return kSFLogLevelWarningString;
		case SFLogLevelError    : return kSFLogLevelErrorString;
	}
	return [NSString stringWithFormat:@"<unknown level %lu>", (unsigned long)level];
}

- (NSString *)logFileContents {
   return [[self class] logFileContents];
}

- (void)log:(Class)cls level:(SFLogLevel)level msg:(NSString *)msg {
	if (level >= logLevel) {
		NSString *s = [NSString stringWithFormat:@"%@|%@|%@", [[self class] levelName:level], cls, msg];
		[[self class] log:level format:s];
	}
}

- (void)log:(Class)cls level:(SFLogLevel)level msg:(NSString *)msg arguments:(va_list)args {
	if (level >= logLevel) {
		NSString *formattedMsg = [[NSString alloc] initWithFormat:msg arguments:args];
		[self log:cls level:level msg:formattedMsg];
	}
}

+ (void)log:(Class)cls level:(SFLogLevel)level format:(NSString *)msg, ... {

    // initialize if needed
    va_list list;
    va_start(list, msg);
    [[self class] log:cls level:level msg:msg arguments:list];
    va_end(list);
}

+ (void)log:(Class)cls level:(SFLogLevel)level msg:(NSString *)msg {
    switch (level) {
            break;
        case SFLogLevelVerbose:
            DDLogVerbose(@"%@", [NSString stringWithFormat:@"%@|%@|%@", [[self class] levelName:level], cls, msg]);
            break;
            
        case SFLogLevelDebug:
            DDLogDebug(@"%@", [NSString stringWithFormat:@"%@|%@|%@", [[self class] levelName:level], cls, msg]);
            break;
            
        case SFLogLevelError:
            DDLogError(@"%@", [NSString stringWithFormat:@"%@|%@|%@", [[self class] levelName:level], cls, msg]);
            break;
            
        case SFLogLevelInfo:
            DDLogInfo(@"%@", [NSString stringWithFormat:@"%@|%@|%@", [[self class] levelName:level], cls, msg]);
            break;
            
        case SFLogLevelWarning:
            DDLogWarn(@"%@", [NSString stringWithFormat:@"%@|%@|%@", [[self class] levelName:level], cls, msg]);
            break;
            
        default:
            DDLogVerbose(@"%@", [NSString stringWithFormat:@"%@|%@|%@", [[self class] levelName:level], cls, msg]);
            break;
    }
}

+ (void)log:(Class)cls level:(SFLogLevel)level msg:(NSString *)msg arguments:(va_list)args {
    NSString *formattedMsg = [[NSString alloc] initWithFormat:msg arguments:args];
    [self log:cls level:level msg:formattedMsg];
}

//analogous methods for logging with particular context
+ (void)log:(Class)cls level:(SFLogLevel)level context:(SFLogContext)logContext format:(NSString *)msg, ... {

    // initialize if needed
    va_list list;
    va_start(list, msg);
    [[self class] log:cls level:level context:logContext msg:msg arguments:list];
    va_end(list);
}

+ (void)log:(Class)cls level:(SFLogLevel)level context:(SFLogContext)logContext msg:(NSString *)msg {
    switch (level) {
        case SFLogLevelVerbose:
            LogWithContextVerbose(logContext, @"%@", [NSString stringWithFormat:@"%@|%@|%@", [[self class] levelName:level], cls, msg]);
            break;
            
        case SFLogLevelDebug:
            LogWithContextDebug(logContext, @"%@", [NSString stringWithFormat:@"%@|%@|%@", [[self class] levelName:level], cls, msg]);
            break;
            
        case SFLogLevelError:
            LogWithContextError(logContext, @"%@", [NSString stringWithFormat:@"%@|%@|%@", [[self class] levelName:level], cls, msg]);
            break;
            
        case SFLogLevelInfo:
            LogWithContextInfo(logContext, @"%@", [NSString stringWithFormat:@"%@|%@|%@", [[self class] levelName:level], cls, msg]);
            break;
            
        case SFLogLevelWarning:
            LogWithContextWarn(logContext, @"%@", [NSString stringWithFormat:@"%@|%@|%@", [[self class] levelName:level], cls, msg]);
            break;
            
        default:
            LogWithContextVerbose(logContext, @"%@", [NSString stringWithFormat:@"%@", [NSString stringWithFormat:@"%@ (%lu):%@|%@|%@", @"unknown log level", (unsigned long)level, [[self class] levelName:level], cls, msg]]);
            break;
    }
}

+ (void)log:(Class)cls level:(SFLogLevel)level context:(SFLogContext)logContext msg:(NSString *)msg arguments:(va_list)args {
    NSString *formattedMsg = [[NSString alloc] initWithFormat:msg arguments:args];
    [self log:cls level:level context:logContext msg:formattedMsg];
}

+ (NSString *)logFileContents {
    if (!loggingToFile) {
        return nil;
    }
    
	NSString *logFilePath = [[self class] logFile];
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    if ([fileManager fileExistsAtPath:logFilePath]) {
        NSString *fileContent  =[ NSString stringWithContentsOfFile:logFilePath encoding:NSUTF8StringEncoding error:nil];
        return fileContent;
    }
    return nil;
}


+ (void)logAssertionFailureInMethod:(SEL)method object:(id)obj file:(NSString *)file lineNumber:(NSUInteger)line description:(NSString *)desc, ... {
#ifndef NS_BLOCK_ASSERTIONS
    NSString *message = [NSString stringWithFormat:@"ASSERTION FAILURE: [%@ %@] [file:%@ line:%lu]: ",
                         NSStringFromClass([obj class]), NSStringFromSelector(method),
                         file, (unsigned long)line];
    va_list args;
    va_start(args, desc);
    NSString *m = [[NSString alloc] initWithFormat:desc arguments:args];
    DDLogError(@"%@ %@", message, m);
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
    
    free (strings);
    DDLogError(@"%@", stackTraces);
    
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

//Formatter
+ (void)setBlackListFilter
{
    if ([[DDTTYLogger sharedInstance] logFormatter] != blackListFormatter)
    {
        [[DDTTYLogger sharedInstance] setLogFormatter:blackListFormatter];
    }
}

+ (void)setWhiteListFilter
{
    if ([[DDTTYLogger sharedInstance] logFormatter] != whiteListFormatter)
    {
        [[DDTTYLogger sharedInstance] setLogFormatter:whiteListFormatter];
    }
}

//black list
+ (void)blackListFilterAddContext:(SFLogContext)logContext
{
    if (![blackListFormatter isOnBlacklist:logContext])
    {
        [blackListFormatter addToBlacklist:logContext];
    }
}

+ (void)blackListFilterRemoveContext:(SFLogContext)logContext
{
    if ([blackListFormatter isOnBlacklist:logContext])
    {
        [blackListFormatter removeFromBlacklist:logContext];
    }
}

+ (NSArray *)contextsOnBlackList
{
    return [blackListFormatter blacklist];
}

+ (BOOL)isOnContextBlackList:(SFLogContext)logContext
{
    return [blackListFormatter isOnBlacklist:logContext];
}

//white list
+ (void)whiteListFilterAddContext:(SFLogContext)logContext
{
    if (![whiteListFormatter isOnWhitelist:logContext])
    {
        [whiteListFormatter addToWhitelist:logContext];
    }
}

+ (void)whiteListFilterRemoveContext:(SFLogContext)logContext
{
    if ([whiteListFormatter isOnWhitelist:logContext])
    {
        [whiteListFormatter removeFromWhitelist:logContext];
    }
}

//Individual Context Filter -- Resets White Filter and filters a single context
//can still add to it
+ (void)filterByContext:(SFLogContext)logContext; //if you want to RESET the whitelist and filter only ONE context
{
    [self setWhiteListFilter];
    for (id integer in [whiteListFormatter whitelist])
    {
        [whiteListFormatter removeFromWhitelist:[integer intValue]];
    }
    [whiteListFormatter addToWhitelist:logContext];
}

+ (NSArray *)contextsOnWhiteList
{
    return [whiteListFormatter whitelist];
}

+ (BOOL)isOnContextWhiteList:(SFLogContext)logContext
{
    return [whiteListFormatter isOnWhitelist:logContext];
}

+ (void) resetLoggingFilter
{
    for (id integer in [whiteListFormatter whitelist])
    {
        [whiteListFormatter removeFromWhitelist:[integer intValue]];
    }
    for (id integer in [blackListFormatter blacklist])
    {
        [blackListFormatter removeFromBlacklist:[integer intValue]];
    }
    [self setBlackListFilter];

}

@end
