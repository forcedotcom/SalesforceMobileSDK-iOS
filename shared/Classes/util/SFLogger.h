/*
 Copyright (c) 2012, salesforce.com, inc. All rights reserved.
 
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

typedef enum SFLogLevel {
	Debug,
	Info,
	Warning,
	Error,
} SFLogLevel;


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

@end


/*!
 Generic logging utility: logs to both console and persistent file.
 */
@interface SFLogger : NSObject {
	SFLogLevel		logLevel;
	NSString		*logFile;
	NSUInteger		fileSize;
	NSFileHandle	*logHandle;
	NSDateFormatter *dateFormatter;
}

/**
 * The current log level of the app.
 */
+ (SFLogLevel)LogLevel;

/**
 * Sets the log level of the app.
 * @param newLevel The new log level to configure.
 */
+ (void)setLogLevel:(SFLogLevel)newLevel;

/**
 * Logs a message to the file at the given file path.
 * @param file The file path.
 */
+ (void)logToFile:(NSString *)file;

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
 * Logs an assertion failure to a file.
 * @param method The method where the assertion failure occurred.
 * @param obj The object where the assertion failure occurred.
 * @param file The file to log to.
 * @param line The line number of the failure.
 * @param desc The formatted description to log.
 * @param ... The format arguments of the description.
 */
+ (void)logAssertionFailureInMethod:(SEL)method object:(id)obj file:(NSString *)file lineNumber:(NSUInteger)line description:(NSString *)desc, ...;

/*!
 Sets the log level based on the user preferences.
 */
+ (void)applyLogLevelFromPreferences;

@end
