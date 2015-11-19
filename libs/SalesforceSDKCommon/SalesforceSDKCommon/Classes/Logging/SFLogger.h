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

//Prevent all NSLog commands in release versions
#ifndef DEBUG
#define NSLog(__FORMAT__, ...)
#endif

extern NSString * const kSFLogLevelVerboseString;
extern NSString * const kSFLogLevelDebugString;
extern NSString * const kSFLogLevelInfoString;
extern NSString * const kSFLogLevelWarningString;
extern NSString * const kSFLogLevelErrorString;

typedef NS_ENUM(NSUInteger, SFLogLevel) {
    SFLogLevelVerbose,
	SFLogLevelDebug,
	SFLogLevelInfo,
	SFLogLevelWarning,
	SFLogLevelError
};

typedef NS_ENUM(NSUInteger, SFLogContext) {
    MobileSDKLogContext = 1
};

typedef void (^SFLogBlock) (NSString *msg);

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
 * Logs a message with the given level.
 * @param level The minimum log level to log at.
 * @param msg The message to log.
 */
-(void)log:(SFLogLevel)level msg:(NSString *)msg;

/**
 * Logs a formatted message with the given log level and format parameters.
 * @param level The minimum log level to log at.
 * @param msg The format message, and optional arguments to expand in the format.
 * @param ... The arguments to the message format string.
 */
-(void)log:(SFLogLevel)level format:(NSString *)msg, ...;

/**
 * Analagous Log methods with the addition of context
*/
-(void)log:(SFLogLevel)level context:(SFLogContext)logContext msg:(NSString *)msg;
-(void)log:(SFLogLevel)level context:(SFLogContext)logContext format:(NSString *)msg, ...;

@end

/*!
 Generic logging utility: logs to both console and persistent file.
 */
@interface SFLogger : NSObject {
	SFLogLevel		logLevel;
}

/**
 * The current log level of the app.
 */
+ (SFLogLevel)logLevel;

/** Turn on and off for logging to a file
 @param logToFile Yes to log to file. Set to NO will turn off logging to file and also remove existing logging file
 */
+ (void)logToFile:(BOOL)logToFile;

/**
 * Sets the log level of the app.
 * @param newLevel The new log level to configure.
 */
+ (void)setLogLevel:(SFLogLevel)newLevel;


/** Get access to the content of the application log file.
 */
+ (NSString *)logFileContents;

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
 * @param logContext The context of the log
 * @param msg The message to log.
 */
+ (void)log:(Class)cls level:(SFLogLevel)level context:(SFLogContext)logContext msg:(NSString *)msg;

/**
 * Logs an assertion failure to a file.
 * @param method The method where the assertion failure occurred.
 * @param obj The object where the assertion failure occurred.
 * @param file The file to log to.
 * @param line The line number of the failure.
 * @param desc The formatted description to log.
 * @param ... The format arguments of the description.
 */
+ (void)logAssertionFailureInMethod:(SEL)method object:(id)obj file:(NSString *)file lineNumber:(NSUInteger)line description:(NSString *)desc, ...;

/**
 * Logs a formatted message with the given log level and format parameters.
 * @param cls The class associated with the log event.
 * @param level The minimum log level to log at.
 * @param msg The format message, and optional arguments to expand in the format.
 * @param ... The arguments to the message format string.
 */
+ (void)log:(Class)cls level:(SFLogLevel)level format:(NSString *)msg, ...;

/**
 * Logs a formatted message with the given log level and format parameters.
 * @param cls The class associated with the log event.
 * @param level The minimum log level to log at.
 * @param logContext The context of the log
 * @param msg The format message, and optional arguments to expand in the format.
 * @param ... The arguments to the message format string.
 */
+ (void)log:(Class)cls level:(SFLogLevel)level context:(SFLogContext)logContext format:(NSString *)msg, ...;

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

/**
 *  Return SFLogLevel for corresponding user readable string. Does
 *  a case insensitive comparison against "Verbose", "Debug", "Info", "Warning", "Error"
 *
 *  @param value One of the above strings
 *
 *  @return Corresponding SFLogLevel value
 */
+ (SFLogLevel)logLevelForString:(NSString *)value;

//Context Based Filtering
//Two filters: blacklist, whitelist.

+ (void)setBlackListFilter;
+ (void)setWhiteListFilter;

+ (void)resetLoggingFilter; //back to original settings (set to blacklist filter; empty blacklist/whitelist)


// black list formatter (logs with contexts on the black list will not be displayed )
+ (void)blackListFilterAddContext:(SFLogContext)logContext;
+ (void)blackListFilterRemoveContext:(SFLogContext)logContext;

// white list formatter (ONLY logs with contexts on the white list will be displayed)
+ (void)whiteListFilterAddContext:(SFLogContext)logContext;
+ (void)whiteListFilterRemoveContext:(SFLogContext)logContext;
+ (void)filterByContext:(SFLogContext)logContext; //if you want to RESET the whitelist and filter only ONE context

//contexts on respective filter
+ (NSArray *)contextsOnBlackList;
+ (NSArray *)contextsOnWhiteList;

+ (BOOL)isOnContextBlackList:(SFLogContext)logContext;
+ (BOOL)isOnContextWhiteList:(SFLogContext)logContext;

@end
