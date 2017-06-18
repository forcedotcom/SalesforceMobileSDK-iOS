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
            [loggerList[loggerKey].fileLogger flushLog];
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
        DDLogLevel logLevel = DDLogLevelError;
#ifdef DEBUG
        logLevel = DDLogLevelDebug;
#endif
        DDTTYLogger *consoleLogger = [DDTTYLogger sharedInstance];
        consoleLogger.colorsEnabled = YES;
        [self.logger addLogger:consoleLogger withLevel:logLevel];
        [self.logger addLogger:self.fileLogger withLevel:logLevel];
    }
    return self;
}

// TODO: Add setter for log level and test for it.

@end
