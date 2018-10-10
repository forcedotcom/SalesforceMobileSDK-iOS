/*
 SFSDKFileLogger.m
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

#import "SFSDKFileLogger.h"
#import "SFSDKLogFileManager.h"

@interface SFSDKFileLogger ()

@property (nonatomic, readwrite, strong) NSString *componentName;

@end

@implementation SFSDKFileLogger {
    SFSDKLogFileManager *_logFileManager;
}

- (instancetype)initWithComponent:(NSString *)componentName {
    SFSDKLogFileManager *logManager = [[SFSDKLogFileManager alloc] initWithComponent:componentName];
    self = [self initWithLogFileManager:logManager];
    if (self) {
        self.componentName = componentName;
        _logFileManager = logManager;
        self.rollingFrequency = 0; // Disables rolling of log files based on time and does it based on size.
    }
    return self;
}

- (instancetype)initWithLogFileManager:(id <DDLogFileManager>)aLogFileManager {
    self = [super initWithLogFileManager:aLogFileManager];
    if (self) {
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setTimeZone:[NSTimeZone timeZoneWithName:@"GMT"]];
        [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"];
        self.logFormatter = [[DDLogFileFormatterDefault alloc] initWithDateFormatter:dateFormatter];
    }
    return self;
}

- (void)flushLogWithCompletionBlock:(void (^)(void))completionBlock {
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    [self rollLogFileWithCompletionBlock: ^{
        for (NSString *filename in self->_logFileManager.sortedLogFilePaths) {
            [fileManager removeItemAtPath:filename error:nil];
        }
        if (completionBlock) {
            completionBlock();
        }
    }];
}

- (NSString *)readFile {
    NSString *logFile = nil;
    NSArray *logFiles = _logFileManager.sortedLogFilePaths;
    if (logFiles.count > 0) {
        logFile = logFiles[0];
    }
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    NSError *error = nil;
    if (logFile && [fileManager fileExistsAtPath:logFile]) {
        NSString *fileContent = [NSString stringWithContentsOfFile:logFile
                                                          encoding:NSUTF8StringEncoding
                                                             error:&error];
        return fileContent;
    }
    return nil;
}

@end
