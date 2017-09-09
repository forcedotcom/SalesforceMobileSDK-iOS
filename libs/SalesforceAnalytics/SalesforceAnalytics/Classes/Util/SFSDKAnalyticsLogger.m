/*
 SFSDKAnalyticsLogger.m
 SalesforceAnalytics
 
 Created by Bharath Hariharan on 6/28/17.
 
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

#import "SFSDKAnalyticsLogger.h"

static NSString * const kComponentName = @"SalesforceAnalytics";

@implementation SFSDKAnalyticsLogger

+ (DDLogLevel)curLogLevel {
    SFSDKLogger *logger = [SFSDKLogger sharedInstanceWithComponent:kComponentName];
    return logger.logLevel;
}

+ (void)setLogLevel:(DDLogLevel)logLevel {
    SFSDKLogger *logger = [SFSDKLogger sharedInstanceWithComponent:kComponentName];
    logger.logLevel = logLevel;
}

+ (void)e:(Class)class format:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    [SFSDKAnalyticsLogger log:DDLogLevelError class:class message:format args:args];
    va_end(args);
}

+ (void)w:(Class)class format:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    [SFSDKAnalyticsLogger log:DDLogLevelWarning class:class message:format args:args];
    va_end(args);
}

+ (void)i:(Class)class format:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    [SFSDKAnalyticsLogger log:DDLogLevelInfo class:class message:format args:args];
    va_end(args);
}

+ (void)v:(Class)class format:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    [SFSDKAnalyticsLogger log:DDLogLevelVerbose class:class message:format args:args];
    va_end(args);
}

+ (void)d:(Class)class format:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    [SFSDKAnalyticsLogger log:DDLogLevelDebug class:class message:format args:args];
    va_end(args);
}

+ (void)log:(DDLogLevel)level class:(Class)class message:(NSString *)message args:(va_list)args {
    NSString *formattedMessage = [[NSString alloc] initWithFormat:message arguments:args];
    SFSDKLogger *logger = [SFSDKLogger sharedInstanceWithComponent:kComponentName];
    [logger log:class level:level message:formattedMessage];
}

@end
