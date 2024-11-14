/*
 SFLogger.m
 SFLogger
 
 Created by Raj Rao on on 10/4/18.
 
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

#import <SalesforceSDKCommon/SalesforceSDKCommon-Swift.h>

#import "SFLogger.h"
#import "SFDefaultLogger.h"
#import "SFSDKSafeMutableDictionary.h"

@protocol SFLogReceiver;
@protocol SFLogReceiverFactory;

static NSString * const kDefaultComponentName = @"SFSDK";

static Class InstanceClass;

/**
 * The factory for Salesforce log receivers.
 * - Parameters
 *   - logReceiverFactory: The factory for Salesforce log receivers
 */
static id<SFLogReceiverFactory> _Nullable _logReceiverFactory;

static SFSDKSafeMutableDictionary *loggerList = nil;

@interface SFLogger()
- (instancetype)init:(NSString *)componentName;
- (instancetype)init:(NSString *)componentName logReceiver:(id<SFLogReceiver>)logReceiver;

+ (void)clearAllComponents;

@property id<SFLogging> logger;

/** The Salesforce log receiver to receive all logs issued by this Salesforce logger */
@property id<SFLogReceiver> logReceiver;

@end

@implementation SFLogger

/**
 * Creates a new Salesforce logger.
 *
 * @param componentName The named component the logger will be associated with
 */
- (instancetype)init:(NSString *)componentName {
    return [self init:componentName logReceiver:nil];
}

/**
 * Creates a new Salesforce logger.
 *
 * @param componentName The named component the logger will be associated with
 * @param logReceiver The Salesforce log receiver to receive all logs issued by the Salesforce logger
 */
- (instancetype)init:(NSString *)componentName
         logReceiver:(id<SFLogReceiver>)logReceiver
{
    self = [super init];
    if (self) {
        //for backward compatibility with SFSDKLogger
        //invoke the shared instance instead.
        if ([InstanceClass respondsToSelector:@selector(sharedInstanceWithComponent:)]) {
            self.logger = [InstanceClass sharedInstanceWithComponent:componentName];
        } else {
            self.logger = [[InstanceClass alloc] initWithComponent:componentName];
        }
        self.logReceiver = logReceiver;
    }
    return self;
}

-(SFLogLevel)logLevel {
    return [self.logger logLevel];
}

-(void)setLogLevel:(SFLogLevel) logLevel {
    [self.logger setLogLevel:logLevel];
}

- (void)submitLogEntryWithClass:(nonnull Class)cls level:(SFLogLevel)level message:(nonnull NSString *)message {
    [self.logger log:cls level:level message:message];
    [self.logReceiver receiveWithLevel:level cls:cls component:self.logger.componentName message:message];
}

/**
 * Submits a log entry with the provided properties to the logger and log receiver.
 */
- (void)submitLogEntryWithClass:(nonnull Class)cls level:(SFLogLevel)level format:(nonnull NSString *)format args:(va_list)args {
    [self.logger log:cls level:level format:format args:args];
    NSString *formattedMessage = [[NSString alloc] initWithFormat:format arguments:args];
    [self.logReceiver receiveWithLevel:level cls:cls component:self.logger.componentName message:formattedMessage];
}

- (void)log:(nonnull Class)cls message:(nonnull NSString *)message {
    [self submitLogEntryWithClass:cls level:SFLogLevelDefault message:message];
}

- (void)log:(nonnull Class)cls format:(nonnull NSString *)format, ... {
    va_list args;
    va_start(args, format);
    [self submitLogEntryWithClass:cls level:SFLogLevelDefault format:format args:args];
    va_end(args);
}

- (void)log:(Class)cls level:(SFLogLevel)level message:(NSString *)message {
    [self submitLogEntryWithClass:cls level:level message:message];}

- (void)log:(Class)cls level:(SFLogLevel)level format:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    [self submitLogEntryWithClass:cls level:level format:format args:args];
    va_end(args);
}

- (void)log:(Class)cls level:(SFLogLevel)level format:(NSString *)format args:(va_list)args {
    va_list args_copy;
    va_copy(args_copy, args); // Note: This log convenience cannot use the common submit log entry methods since it requires this local memory copy due to the caller already having run `va_start` on `args`.
    
    [self.logger log:cls level:level format:format args:args];
    
    NSString *formattedMessage = [[NSString alloc] initWithFormat:format arguments:args_copy];
    [self.logReceiver receiveWithLevel:SFLogLevelInfo cls:cls component:self.logger.componentName message:formattedMessage];
    
    va_end(args_copy);
}

- (void)e:(nonnull Class)cls message:(nonnull NSString *)message {
    [self submitLogEntryWithClass:cls level:SFLogLevelError message:message];
}

- (void)e:(nonnull Class)cls format:(nonnull NSString *)format, ... {
    va_list args;
    va_start(args, format);
    [self submitLogEntryWithClass:cls level:SFLogLevelError format:format args:args];
    va_end(args);
}

- (void)f:(nonnull Class)cls message:(nonnull NSString *)message {
    [self submitLogEntryWithClass:cls level:SFLogLevelFault message:message];
}

- (void)f:(nonnull Class)cls format:(nonnull NSString *)format, ... {
    va_list args;
    va_start(args, format);
    [self submitLogEntryWithClass:cls level:SFLogLevelFault format:format args:args];
    va_end(args);
}

- (void)i:(nonnull Class)cls message:(nonnull NSString *)message {
    [self submitLogEntryWithClass:cls level:SFLogLevelInfo message:message];
}

- (void)i:(nonnull Class)cls format:(nonnull NSString *)format, ... {
    va_list args;
    va_start(args, format);
    [self submitLogEntryWithClass:cls level:SFLogLevelInfo format:format args:args];
    va_end(args);
}

- (void)d:(nonnull Class)cls message:(nonnull NSString *)message {
    [self submitLogEntryWithClass:cls level:SFLogLevelDebug message:message];
}

- (void)d:(nonnull Class)cls format:(nonnull NSString *)format, ... {
    va_list args;
    va_start(args, format);
    [self submitLogEntryWithClass:cls level:SFLogLevelDebug format:format args:args];
    va_end(args);
}

- (void)w:(nonnull Class)cls message:(nonnull NSString *)message {
    [self submitLogEntryWithClass:cls level:SFLogLevelDefault message:message];
}

- (void)w:(nonnull Class)cls format:(nonnull NSString *)format, ... {
    va_list args;
    va_start(args, format);
    [self submitLogEntryWithClass:cls level:SFLogLevelDefault format:format args:args];
    va_end(args);
}

+ (void)clearAllComponents {
    [loggerList removeAllObjects];
}

+ (SFLogLevel)logLevel {
    return [[self defaultLogger] logLevel];
}

+ (void)setLogLevel:(SFLogLevel)logLevel {
    [[self defaultLogger] setLogLevel:logLevel];
}

+ (void)e:(nonnull Class)cls format:(nonnull NSString *)format, ... {
    va_list args;
    va_start(args, format);
    [[self defaultLogger] log:cls level:SFLogLevelError format:format args:args];
    va_end(args);
}

+ (void)e:(nonnull Class)cls message:(nonnull NSString *)message {
    [[self defaultLogger] e:cls message:message];
}

+ (void)d:(nonnull Class)cls format:(nonnull NSString *)format, ... {
    va_list args;
    va_start(args, format);
    [[self defaultLogger] log:cls level:SFLogLevelDebug format:format args:args];
    va_end(args);
}

+ (void)d:(nonnull Class)cls message:(nonnull NSString *)message {
    [[self defaultLogger] d:cls message:message];
}

+ (void)w:(nonnull Class)cls format:(nonnull NSString *)format, ... {
    va_list args;
    va_start(args, format);
    [[self defaultLogger] log:cls level:SFLogLevelDefault format:format args:args];
    va_end(args);
}

+ (void)w:(nonnull Class)cls message:(nonnull NSString *)message {
    [[self defaultLogger] log:cls message:message];
}

+ (void)i:(nonnull Class)cls format:(nonnull NSString *)format, ... {
    va_list args;
    va_start(args, format);
    [[self defaultLogger] log:cls level:SFLogLevelInfo format:format args:args];
    va_end(args);
}

+ (void)i:(nonnull Class)cls message:(nonnull NSString *)message {
    [[self defaultLogger] i:cls message:message];
}

+ (void)f:(nonnull Class)cls format:(nonnull NSString *)format, ... {
    va_list args;
    va_start(args, format);
    [[self defaultLogger] log:cls level:SFLogLevelFault format:format args:args];
    va_end(args);
}

+ (void)f:(nonnull Class)cls message:(nonnull NSString *)message {
    [[self defaultLogger] f:cls message:message];
}

+ (void)v:(nonnull Class)cls format:(nonnull NSString *)format, ... {
    va_list args;
    va_start(args, format);
    [[self defaultLogger] log:cls level:SFLogLevelDefault format:format args:args];
    va_end(args);
}

+ (void)v:(nonnull Class)cls message:(nonnull NSString *)message {
    [[self defaultLogger] log:cls level:SFLogLevelDefault message:message];
}

+ (void)log:(nonnull Class)cls message:(nonnull NSString *)message {
    [[self defaultLogger] log:cls message:message];
}

+ (void)log:(nonnull Class)cls format:(nonnull NSString *)format, ... {
    va_list args;
    va_start(args, format);
    [[self defaultLogger] log:cls level:SFLogLevelDefault format:format args:args];
    va_end(args);
}

+ (void)log:(nonnull Class)cls level:(SFLogLevel)level message:(nonnull NSString *)message {
    [[self defaultLogger] log:cls level:level  message:message];
}

+ (void)log:(nonnull Class)cls level:(SFLogLevel)level format:(nonnull NSString *)format, ... {
    va_list args;
    va_start(args, format);
    [[self defaultLogger] log:cls level:SFLogLevelDefault format:format args:args];
    va_end(args);
}

+ (void)initialize {
    if (self == [SFLogger self]) {
        InstanceClass = [SFDefaultLogger class];
    }
}

+ (void)setInstanceClass:(Class<SFLogging>)loggerClass {
    InstanceClass = loggerClass;
}

+ (void)setLogReceiverFactory:(id<SFLogReceiverFactory>)logReceiverFactory {
    _logReceiverFactory = logReceiverFactory;
}

+ (nonnull instancetype)defaultLogger {
    return [self loggerForComponent:kDefaultComponentName];
}

+ (nonnull instancetype)loggerForComponent:(nonnull NSString *)componentName {
    
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{
        loggerList = [[SFSDKSafeMutableDictionary alloc] init];
    });
    @synchronized ([SFLogger class]) {
        if (!componentName) {
            return nil;
        }
        id logger = [loggerList objectForKey:componentName];
        if (!logger) {
            id<SFLogReceiver> logReceiver = nil;
            if (_logReceiverFactory) {
                logReceiver = [_logReceiverFactory createWithComponentName:componentName];
            }
            
            logger =  [[self alloc] init:componentName logReceiver:logReceiver];
            
            [loggerList setObject:logger forKey:componentName];
        }
        return logger;
    }
}

@end
