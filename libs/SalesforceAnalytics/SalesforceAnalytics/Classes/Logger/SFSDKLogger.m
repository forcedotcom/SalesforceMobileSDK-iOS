/*
 SFSDKLogger.m
 SalesforceAnalytics
 
 Created by Bharath Hariharan on 6/8/17.
 
 Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.
 
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

#import "SFSDKLogger.h"
#import <CocoaLumberjack/DDTTYLogger.h>

static NSString * const kFileLoggerOnOffKey = @"file_logger_enabled";
static NSString * const kLogLevelKey = @"log_level";
static NSMutableDictionary<NSString *, SFSDKLogger *> *loggerList = nil;

@interface SFSDKLogger ()

@property (nonatomic, readwrite, strong) NSString *componentName;
@property (nonatomic, readwrite, strong) DDLog *logger;
@property (nonatomic, readwrite, strong) SFSDKFileLogger *fileLogger;

@end

@implementation SFSDKLogger

+ (instancetype)sharedInstanceWithComponent:(NSString *)componentName {
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{
        loggerList = [[NSMutableDictionary alloc] init];
    });
    @synchronized ([SFSDKLogger class]) {
        if (!componentName) {
            return nil;
        }
        id logger = loggerList[componentName];
        if (!logger) {
            logger = [[SFSDKLogger alloc] initWithComponent:componentName];
            loggerList[componentName] = logger;
        }
        return logger;
    }
}

+ (void)flushAllComponents {
    @synchronized ([SFSDKLogger class]) {
        for (NSString *loggerKey in loggerList.allKeys) {
            [loggerList[loggerKey].fileLogger flushLogWithCompletionBlock:nil];
        }
        [loggerList removeAllObjects];
    }
}

+ (NSArray<NSString *> *)allComponents {
    @synchronized ([SFSDKLogger class]) {
        return loggerList.allKeys;
    }
}

- (instancetype)initWithComponent:(NSString *)componentName {
    self = [super init];
    if (self) {
        self.componentName = componentName;
        self.logger = [[DDLog alloc] init];
        self.fileLogger = [[SFSDKFileLogger alloc] initWithComponent:componentName];
        DDTTYLogger *consoleLogger = [DDTTYLogger sharedInstance];
        consoleLogger.colorsEnabled = YES;
        [self.logger addLogger:consoleLogger withLevel:self.logLevel];
        if (self.fileLoggingEnabled) {
            [self.logger addLogger:self.fileLogger withLevel:self.logLevel];
        }
    }
    return self;
}

- (void)setFileLoggingEnabled:(BOOL)loggingEnabled {
    BOOL curPolicy = [self readFileLoggingPolicy];
    [self storeFileLoggingPolicy:loggingEnabled];
    BOOL newPolicy = [self readFileLoggingPolicy];

    // Adds or removes the file logger depending on the change in policy.
    if (curPolicy != newPolicy) {
        if (newPolicy) {
            [self.logger addLogger:self.fileLogger withLevel:self.logLevel]; // Disabled to enabled.
        } else {
            [self.logger removeLogger:self.fileLogger]; // Enabled to disabled.
        }
    }
}

- (BOOL)isFileLoggingEnabled {
    return [self readFileLoggingPolicy];
}

- (DDLogLevel)getLogLevel {
    return [self readLogLevel];
}

- (void)setLogLevel:(DDLogLevel)logLevel {
    [self storeLogLevel:logLevel];
    [self.logger removeAllLoggers];
    DDTTYLogger *consoleLogger = [DDTTYLogger sharedInstance];
    consoleLogger.colorsEnabled = YES;
    [self.logger addLogger:consoleLogger withLevel:logLevel];
    [self.logger addLogger:self.fileLogger withLevel:logLevel];
}

- (void)storeFileLoggingPolicy:(BOOL)enabled {
    @synchronized (self) {
        NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
        [defs setBool:enabled forKey:kFileLoggerOnOffKey];
        [defs synchronize];
    }
}

- (BOOL)readFileLoggingPolicy {
    BOOL fileLoggingEnabled;
    NSNumber *fileLoggingEnabledNum = [[NSUserDefaults standardUserDefaults] objectForKey:kFileLoggerOnOffKey];
    if (fileLoggingEnabledNum == nil) {

        // Default is enabled.
        fileLoggingEnabled = YES;
        [self storeFileLoggingPolicy:fileLoggingEnabled];
    } else {
        fileLoggingEnabled = [fileLoggingEnabledNum boolValue];
    }
    return fileLoggingEnabled;
}

- (void)storeLogLevel:(DDLogLevel)logLevel {
    @synchronized (self) {
        NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
        [defs setInteger:logLevel forKey:kLogLevelKey];
        [defs synchronize];
    }
}

- (DDLogLevel)readLogLevel {
    DDLogLevel logLevel;
    if ([[[[NSUserDefaults standardUserDefaults] dictionaryRepresentation] allKeys] containsObject:kLogLevelKey]) {
        logLevel = [[NSUserDefaults standardUserDefaults] integerForKey:kLogLevelKey];
    } else {
        logLevel = DDLogLevelError;
#ifdef DEBUG
        logLevel = DDLogLevelDebug;
#endif
        [self storeLogLevel:logLevel];
    }
    return logLevel;
}

@end
