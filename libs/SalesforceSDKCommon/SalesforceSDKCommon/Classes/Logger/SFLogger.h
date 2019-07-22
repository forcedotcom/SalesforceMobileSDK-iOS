/*
 SFLogger.h
 SFLogger
 
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

#import <Foundation/Foundation.h>
#import <os/log.h>

typedef NS_ENUM(NSUInteger, SFLogLevel){
    SFLogLevelDefault =  OS_LOG_TYPE_DEFAULT,
    SFLogLevelInfo    =  OS_LOG_TYPE_INFO,
    SFLogLevelDebug   =  OS_LOG_TYPE_DEBUG,
    SFLogLevelError   =  OS_LOG_TYPE_ERROR,
    SFLogLevelFault   =  OS_LOG_TYPE_FAULT
} NS_SWIFT_NAME(SalesforceLogger.Level);

NS_ASSUME_NONNULL_BEGIN
@protocol SFLogging <NSObject>

/**
 * Component name associated with this logger.
 */
@property (nonatomic, readonly, strong, nonnull) NSString *componentName;

/**
 * Instance of the underlying logger implementation being used.
 */
@property (nonatomic, readonly, strong, nonnull) id logger;

/**
 * Used to get and set the current log level associated with this logger.
 */
@property (nonatomic, readwrite, assign) SFLogLevel logLevel;

/**
 * Initialize a logger given component Name.
 *
 * @return Instance of this class.
 */
- (instancetype)initWithComponent:(NSString *)componentName;

/**
 * Logs a log line of the specified level.
 *
 * @param cls Class.
 * @param level Log level.
 * @param message Log message.
 */
- (void)log:(nonnull Class)cls level:(SFLogLevel)level message:(nonnull NSString *)message;

/**
 * Logs a log line of the specified level.
 *
 * @param cls Class.
 * @level Log level.
 * @param format The format message, and optional arguments to expand in the format.
 * @param ... The arguments to the message format string.
 */
- (void)log:(nonnull Class)cls level:(SFLogLevel)level format:(nonnull NSString *)format, ...;

/**
 * Logs a log line of the specified level.
 *
 * @param cls Class.
 * @level Log level.
 * @param format The format message, and optional arguments to expand in the format.
 * @param args The arguments to the message format string.
 */
- (void)log:(Class)cls level:(SFLogLevel)level format:(NSString *)format args:(va_list)args;

@optional
+ (nonnull instancetype)sharedInstanceWithComponent:(nonnull NSString *)componentName;
@end
NS_SWIFT_NAME(SalesforceLogger)
@interface SFLogger : NSObject

/**
 * Sets log level to be used by this logger.
 *
 */
@property (nonatomic, readwrite, assign) SFLogLevel logLevel NS_SWIFT_NAME(level);

/**
 * Logs an error log line.
 *
 * @param cls Class.
 * @param message Log message.
 */
- (void)e:(nonnull Class)cls message:(nonnull NSString *)message;

/**
 * Logs an error log line.
 *
 * @param cls Class.
 * @param format The format message, and optional arguments to expand in the format.
 * @param ... The arguments to the message format string.
 */
- (void)e:(nonnull Class)cls format:(nonnull NSString *)format, ...;


/**
 * Logs an info log line.
 *
 * @param cls Class.
 * @param message Log message.
 */
- (void)i:(nonnull Class)cls message:(nonnull NSString *)message;

/**
 * Logs an info log line.
 *
 * @param cls Class.
 * @param format The format message, and optional arguments to expand in the format.
 * @param ... The arguments to the message format string.
 */
- (void)i:(nonnull Class)cls format:(nonnull NSString *)format, ...;

/**
 * Logs a debug log line.
 *
 * @param cls Class.
 * @param message Log message.
 */
- (void)d:(nonnull Class)cls message:(nonnull NSString *)message;

/**
 * Logs a debug log line.
 *
 * @param cls Class.
 * @param format The format message, and optional arguments to expand in the format.
 * @param ... The arguments to the message format string.
 */
- (void)d:(nonnull Class)cls format:(nonnull NSString *)format, ...;

/**
 * Logs a default log line.
 *
 * @param cls Class.
 * @param format The format message, and optional arguments to expand in the format.
 * @param ... The arguments to the message format string.
 */
- (void)w:(nonnull Class)cls format:(nonnull NSString *)format, ...;

/**
 * Logs a default log line.
 *
 * @param cls Class.
 * @param message Log message.
 */
- (void)w:(nonnull Class)cls message:(nonnull NSString *)message;
/**
 * Logs a fault log line.
 *
 * @param cls Class.
 * @param message Log message.
 */
- (void)f:(nonnull Class)cls message:(nonnull NSString *)message;

/**
 * Logs a fault log line.
 *
 * @param cls Class.
 * @param format The format message, and optional arguments to expand in the format.
 * @param ... The arguments to the message format string.
 */
- (void)f:(nonnull Class)cls format:(nonnull NSString *)format, ...;

/**
 * Logs a log line of the default level.
 *
 * @param cls Class.
 * @param message Log message.
 */
- (void)log:(nonnull Class)cls message:(nonnull NSString *)message;

/**
 * Logs a log line of the default level.
 *
 * @param cls Class.
 * @param format The format message, and optional arguments to expand in the format.
 * @param ... The arguments to the message format string.
 */
- (void)log:(nonnull Class)cls format:(nonnull NSString *)format, ...;

/**
 * Logs an error log line.
 *
 * @param cls Class.
 * @param format The format message, and optional arguments to expand in the format.
 * @param ... The arguments to the message format string.
 */
+ (void)e:(nonnull Class)cls format:(nonnull NSString *)format, ...;

/**
 * Logs an error log line.
 *
 * @param cls Class.
 * @param message Log message.
 */
+ (void)e:(nonnull Class)cls message:(nonnull NSString *)message;


/**
 * Logs an info log line.
 *
 * @param cls Class.
 * @param format The format message, and optional arguments to expand in the format.
 * @param ... The arguments to the message format string.
 */
+ (void)i:(nonnull Class)cls format:(nonnull NSString *)format, ...;

/**
 * Logs an info log line.
 *
 * @param cls Class.
 * @param message Log message.
 */
+ (void)i:(nonnull Class)cls message:(nonnull NSString *)message;

/**
 * Logs a debug log line.
 *
 * @param cls Class.
 * @param format The format message, and optional arguments to expand in the format.
 * @param ... The arguments to the message format string.
 */
+ (void)d:(nonnull Class)cls format:(nonnull NSString *)format, ...;

/**
 * Logs a debug log line.
 *
 * @param cls Class.
 * @param message Log message.
 */
+ (void)d:(nonnull Class)cls message:(nonnull NSString *)message;


/**
 * Logs a default log line.
 *
 * @param cls Class.
 * @param format The format message, and optional arguments to expand in the format.
 * @param ... The arguments to the message format string.
 */
+ (void)w:(nonnull Class)cls format:(nonnull NSString *)format, ...;

/**
 * Logs a default log line.
 *
 * @param cls Class.
 * @param message Log message.
 */
+ (void)w:(nonnull Class)cls message:(nonnull NSString *)message;

/**
 * Logs a fault log line.
 *
 * @param cls Class.
 * @param message Log message.
 */
+ (void)f:(nonnull Class)cls message:(nonnull NSString *)message;

/**
 * Logs a fault log line.
 *
 * @param cls Class.
 * @param format The format message, and optional arguments to expand in the format.
 * @param ... The arguments to the message format string.
 */
+ (void)f:(nonnull Class)cls format:(nonnull NSString *)format, ...;

/**
 * Logs a default/verbose log line.
 *
 * @param cls Class.
 * @param message Log message.
 */
+ (void)v:(nonnull Class)cls message:(nonnull NSString *)message;

/**
 * Logs a default/verbose log line.
 *
 * @param cls Class.
 * @param format The format message, and optional arguments to expand in the format.
 * @param ... The arguments to the message format string.
 */
+ (void)v:(nonnull Class)cls format:(nonnull NSString *)format, ...;

/**
 * Logs a log line of the default level.
 *
 * @param cls Class.
 * @param message Log message.
 */
+ (void)log:(nonnull Class)cls message:(nonnull NSString *)message;

/**
 * Logs a log line of the default level.
 *
 * @param cls Class.
 * @param format The format message, and optional arguments to expand in the format.
 * @param ... The arguments to the message format string.
 */
+ (void)log:(nonnull Class)cls format:(nonnull NSString *)format, ...;

/**
 * Logs a log line of the specified level.
 *
 * @param cls Class.
 * @param level Log level.
 * @param message Log message.
 */
+ (void)log:(nonnull Class)cls level:(SFLogLevel)level message:(nonnull NSString *)message;

/**
 * Logs a log line of the specified level.
 *
 * @param cls Class.
 * @level Log level.
 * @param format The format message, and optional arguments to expand in the format.
 * @param ... The arguments to the message format string.
 */
+ (void)log:(nonnull Class)cls level:(SFLogLevel)level format:(nonnull NSString *)format, ...;

/**
 * Returns current log level used by this logger.
 *
 * @return Current log level.
 */
+ (SFLogLevel)logLevel;

/**
 * Sets log level to be used by this logger.
 *
 * @param logLevel Log level.
 */
+ (void)setLogLevel:(SFLogLevel)logLevel;

/**
 * Set an instance of underlying logger class that complies with SFLogging.
 *
 * @param logger Class.
 */
+ (void)setInstanceClass:(Class<SFLogging>)logger;

/**
 * Get the default Logger.
 */
@property (class,nonatomic,readonly) SFLogger *defaultLogger;

/**
 * Get an instance of a component Logger.
 */
+ (nonnull instancetype)loggerForComponent:(nonnull NSString *)component  NS_SWIFT_NAME(logger(forComponent:));

@end

NS_ASSUME_NONNULL_END
