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

#import <Foundation/Foundation.h>
#import "NSNotificationCenter+SFAdditions.h"
#import "SFLoggerMacros.h"

NS_ASSUME_NONNULL_BEGIN

//Prevent all NSLog commands in release versions
#ifndef DEBUG
#define NSLog(__FORMAT__, ...)
#endif

extern NSString * const kSFLogLevelVerboseString;
extern NSString * const kSFLogLevelDebugString;
extern NSString * const kSFLogLevelInfoString;
extern NSString * const kSFLogLevelWarningString;
extern NSString * const kSFLogLevelErrorString;
extern NSString * const kSFLogIdentifierDefault;

typedef NS_ENUM(NSUInteger, SFLogContext) {
    MobileSDKLogContext = 1
} __attribute__((deprecated("Use logging identifiers instead")));


#define SFLogAssert(_cond, _desc, ...) \
do { \
if (!(_cond)) { \
[SFLogger logAssertionFailureInMethod:_cmd object:(self) file:[NSString stringWithUTF8String:__FILE__] lineNumber:__LINE__ description:(_desc), ##__VA_ARGS__]; \
} \
} while (0) \

/*!
 Allows your class to log messages specific to that class.
 You should be able to use this 99% of the time.
 */
@interface NSObject (SFLogging)

/**
 * Default logging identifier to use when none is supplied
 * @return Logging identifier string, or `nil` for default.
 */
+ (NSString*)loggingIdentifier;

/**
 * Logs a message with the given level.
 * @param level The minimum log level to observe.
 * @param msg The message to log.
 */
- (void)log:(SFLogLevel)level msg:(NSString *)msg;

/**
 * Logs a formatted message with the given log level and format parameters.
 * @param level The minimum log level to log at.
 * @param format The format message, and optional arguments to expand in the format.
 * @param ... The arguments to the message format string.
 */
- (void)log:(SFLogLevel)level format:(NSString *)format, ...;

/**
 * Log method with the addition of context.
 * @param level The minimum log level to observe.
 * @param logIdentifier Identifier to use when scoping the context of this log message.
 * @param msg The format message.
*/
- (void)log:(SFLogLevel)level identifier:(NSString*)logIdentifier msg:(NSString *)msg;

/**
 * Log method with the addition of context
 * @param level The minimum log level to observe.
 * @param logIdentifier Identifier to use when scoping the context of this log message.
 * @param format The format message.
 * @param ... Optional arguments for the message format string.
 */
- (void)log:(SFLogLevel)level identifier:(NSString*)logIdentifier format:(NSString *)format, ...;

- (void)log:(SFLogLevel)level context:(SFLogContext)logContext msg:(NSString *)msg __attribute__((deprecated("Use log:identifier:msg: instead")));
- (void)log:(SFLogLevel)level context:(SFLogContext)logContext format:(NSString *)format, ... __attribute__((deprecated("Use log:identifier:format: instead")));

@end

/*!
 Generic logging utility: logs to both console and persistent file.
 
 When creating a new logging identifier, it is recommended to create your own logging macros to encapsulate that behavior, since the log:level:msg: and other methods impose additional performance overhead into your code base that could otherwise be avoided.
 
 Simply create logging macros like so:
    extern NSString * const MyLogIdentifier;
    static NSInteger kMyLogContext;
 
    #define MyLogError(frmt, ...)      SFLogErrorToContext(kMyLogContext, self, frmt, ##__VA_ARGS__)
    #define MyLogWarn(frmt, ...)        SFLogWarnToContext(kMyLogContext, self, frmt, ##__VA_ARGS__)
    #define MyLogInfo(frmt, ...)        SFLogInfoToContext(kMyLogContext, self, frmt, ##__VA_ARGS__)
    #define MyLogDebug(frmt, ...)      SFLogDebugToContext(kMyLogContext, self, frmt, ##__VA_ARGS__)
    #define MyLogVerbose(frmt, ...)  SFLogVerboseToContext(kMyLogContext, self, frmt, ##__VA_ARGS__)

 And make sure you initilize your log context at some early point within your application, preferably within the `+initialize` or `+load` method of one of your application's classes.

    NSString * const MyLogIdentifier = @"com.my.application";

    @implementation MyClass
 
    + (void)load {
        if (self == [MyClass class]) {
            kMyLogContext = [[SFLogger sharedLogger] registerIdentifier:MyLogIdentifier]
        }
    }
 
    @end
 
 Alternatively once you register your identifier, you can use the SFLogErrorToIdentifier and other companion macros with the log identifier string, or you can use the log:level:identifier:format: method directly.  Furthermore, if your [NSObject loggingIdentifier] returns a valid log identifier string, the [NSObject log:msg:] and [NSObject log:format:] methods can be used as well, though those will incur additional performance overhead as well.
 */
@interface SFLogger : NSObject

+ (instancetype)sharedLogger;

@property (nonatomic, assign, getter=shouldLogToASL) BOOL logToASL;

/** Turn on and off for logging to a file
 Set to `YES` to log to file. Set to `NO` will turn off logging to file and also remove existing logging file.
 */
@property (nonatomic, assign, getter=shouldLogToFile) BOOL logToFile;

@property (nonatomic, assign) SFLogLevel logLevel;

- (SFLogLevel)logLevelForIdentifier:(nullable NSString*)identifier;
- (void)setLogLevel:(SFLogLevel)logLevel forIdentifier:(nullable NSString*)identifier;
- (void)setLogLevel:(SFLogLevel)logLevel forIdentifiersWithPrefix:(nonnull NSString*)identifierPrefix;

/** Get access to the content of the application log file.
 */
- (nullable NSString *)logFileContents:(NSError * _Nullable *)error;

/**
 * Logs at the Class level.  Should only be used if you don't have an NSObject instance to
 * log from.
 * @param cls The class associated with the log event.
 * @param level The level to log at.
 * @param msg The message to log.
 */
+ (void)log:(Class)cls level:(SFLogLevel)level msg:(NSString *)msg;

/**
 * Logs at the Class level.  Should only be used if you don't have an NSObject instance to
 * log from.
 * @param cls The class associated with the log event.
 * @param level The level to log at.
 * @param logIdentifier The context of the log
 * @param msg The message to log.
 */
+ (void)log:(Class)cls level:(SFLogLevel)level identifier:(NSString*)logIdentifier msg:(NSString *)msg;

/**
 * Logs an assertion failure to a file.
 * @param method The method where the assertion failure occurred.
 * @param obj The object where the assertion failure occurred.
 * @param file The file to log to.
 * @param line The line number of the failure.
 * @param desc The formatted description to log.
 * @param ... The format arguments of the description.
 */
+ (void)logAssertionFailureInMethod:(SEL)method object:(nullable id)obj file:(nullable NSString *)file lineNumber:(NSUInteger)line description:(NSString *)desc, ...;

/**
 * Logs a formatted message with the given log level and format parameters.
 * @param cls The class associated with the log event.
 * @param level The minimum log level to log at.
 * @param format The format message, and optional arguments to expand in the format.
 * @param ... The arguments to the message format string.
 */
+ (void)log:(Class)cls level:(SFLogLevel)level format:(NSString *)format, ...;

/**
 * Logs a formatted message with the given log level and format parameters.
 * @param cls The class associated with the log event.
 * @param level The minimum log level to log at.
 * @param logIdentifier The context of the log
 * @param format The format message, and optional arguments to expand in the format.
 * @param ... The arguments to the message format string.
 */
+ (void)log:(Class)cls level:(SFLogLevel)level identifier:(NSString*)logIdentifier format:(NSString *)format, ...;

/*!
 Sets the log level based on the user preferences.
 */
+ (void)applyLogLevelFromPreferences;

/**
 Use this method to enable the recording of the assertion instead of aborting the
 program when an assertion is triggered. This is usually used by the
 unit tests.
 @param enabled Whether or not to enable assertion recording.
 */
+ (void)setRecordAssertionEnabled:(BOOL)enabled;

/**
 Returns YES if an assertion was recorded and clear the flag.
 @return YES if an assertion was recorded, NO otherwise.
 */
+ (BOOL)assertionRecordedAndClear;

- (NSInteger)registerIdentifier:(NSString*)identifier;

@end

@interface SFLogger (MacroHelper)

+ (void)logAsync:(BOOL)asynchronous
           level:(SFLogLevel)level
            flag:(SFLogFlag)flag
         context:(NSInteger)context
            file:(nullable const char *)file
        function:(nullable const char *)function
            line:(NSUInteger)line
             tag:(nullable id)tag
          format:(nullable NSString *)format, ...;

@end

@interface SFLogger (Deprecated)

+ (void)log:(Class)cls level:(SFLogLevel)level context:(SFLogContext)logContext msg:(NSString *)msg __attribute__((deprecated("Use log:level:identifier:msg: instead")));
+ (void)log:(Class)cls level:(SFLogLevel)level context:(SFLogContext)logContext format:(NSString *)msg, ... __attribute__((deprecated("Use log:level:identifier:msg: instead")));

/**
 * The current log level of the app.
 */
+ (SFLogLevel)logLevel __attribute__((deprecated("Use [SFLogger sharedLogger].logLevel")));

/**
 * Sets the log level of the app.
 * @param newLevel The new log level to configure.
 */
+ (void)setLogLevel:(SFLogLevel)newLevel __attribute__((deprecated("Use [SFLogger sharedLogger].logLevel")));

+ (void)logToFile:(BOOL)logToFile __attribute__((deprecated("Use [SFLogger sharedLogger].logToFile")));

/**
 *  Return SFLogLevel for corresponding user readable string. Does
 *  a case insensitive comparison against "Verbose", "Debug", "Info", "Warning", "Error"
 *
 *  @param value One of the above strings
 *
 *  @return Corresponding SFLogLevel value
 */
+ (SFLogLevel)logLevelForString:(NSString *)value __attribute__((deprecated));

+ (nullable NSString *)logFileContents  __attribute__((deprecated("Use [SFLogger sharedLogger].logFileContents")));

//Context Based Filtering
//Two filters: blacklist, whitelist.

/** Sets the log formatter to use the black list filter.
 */
+ (void)setBlackListFilter;

/** Sets the log formatter to use the white list filter.
 */
+ (void)setWhiteListFilter;

// black list formatter (logs with contexts on the black list will not be displayed )
+ (void)blackListFilterAddContext:(SFLogContext)logContext __attribute__((deprecated("Use logging identifiers instead")));
+ (void)blackListFilterRemoveContext:(SFLogContext)logContext __attribute__((deprecated("Use logging identifiers instead")));

// white list formatter (ONLY logs with contexts on the white list will be displayed)
+ (void)whiteListFilterAddContext:(SFLogContext)logContext __attribute__((deprecated("Use logging identifiers instead")));
+ (void)whiteListFilterRemoveContext:(SFLogContext)logContext __attribute__((deprecated("Use logging identifiers instead")));
+ (void)filterByContext:(SFLogContext)logContext __attribute__((deprecated("Use logging identifiers instead"))); //if you want to RESET the whitelist and filter only ONE context

//contexts on respective filter
+ (nullable NSArray *)contextsOnBlackList __attribute__((deprecated("Use logging identifiers instead")));
+ (nullable NSArray *)contextsOnWhiteList __attribute__((deprecated("Use logging identifiers instead")));

+ (BOOL)isOnContextBlackList:(SFLogContext)logContext __attribute__((deprecated("Use logging identifiers instead")));
+ (BOOL)isOnContextWhiteList:(SFLogContext)logContext __attribute__((deprecated("Use logging identifiers instead")));

@end

NS_ASSUME_NONNULL_END
