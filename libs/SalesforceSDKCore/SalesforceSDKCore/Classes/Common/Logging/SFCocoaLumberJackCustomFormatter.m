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

#include <pthread.h>

#import <CocoaLumberjack/CocoaLumberjack.h>
#import "SFCocoaLumberJackCustomFormatter.h"
#import "SFLogger.h"
#import "SFLogger_Internal.h"

@implementation SFCocoaLumberJackCustomFormatter {
    int loggerCount;
    NSDateFormatter *threadUnsafeDateFormatter;
    NSString *_processName;
    int _processId;
}

- (instancetype)init {
    return [self initWithLogger:[SFLogger sharedLogger]];
}

- (instancetype)initWithLogger:(SFLogger*)logger {
    self = [super init];
    if (self) {
        _logger = logger;
        
        NSProcessInfo *process = [NSProcessInfo processInfo];
        _processName = [process.processName copy];
        _processId = process.processIdentifier;
        
        threadUnsafeDateFormatter = [[NSDateFormatter alloc] init];
        [threadUnsafeDateFormatter setTimeZone:[NSTimeZone timeZoneWithName:@"GMT"]];
        [threadUnsafeDateFormatter setDateFormat:@"yyyy/MM/dd HH:mm:ss.SSS"];
    }
    return self;
}

- (NSString *)formatLogMessage:(DDLogMessage *)logMessage {
    NSString *dateAndTime = [threadUnsafeDateFormatter stringFromDate:(logMessage->_timestamp)];

    NSString *classString = nil;
    NSString *selectorString = nil;
    if ([logMessage->_tag isKindOfClass:[SFLogTag class]]) {
        SFLogTag *tag = (SFLogTag*)logMessage->_tag;
        if (tag.originClass) {
            classString = NSStringFromClass(tag.originClass);
        }

        if (tag.selector) {
            selectorString = NSStringFromSelector(tag.selector);
        }
    }
    
    SFLogIdentifier *identifier = nil;
    if (logMessage->_context < _logger->_logIdentifiersByContext.count) {
        identifier = _logger->_logIdentifiersByContext[logMessage->_context];
    }
    
    NSString *thread = [NSThread currentThread].name;
    if (thread.length == 0) {
        thread = [NSString stringWithFormat:@"%x", pthread_mach_thread_np(pthread_self())];
    }
    NSMutableString *message = [NSMutableString stringWithFormat:@"%@ %@[%d:%@] %@ %@",
                                dateAndTime,
                                _processName,
                                _processId,
                                thread,
                                SFLogNameForFlag((SFLogFlag)logMessage->_flag),
                                identifier.identifier];
    
    NSString *file = ([logMessage->_file isEqualToString:@"(null)"]) ? nil : logMessage->_file;
    NSString *function = ([logMessage->_function isEqualToString:@"(null)"]) ? selectorString : logMessage->_function;
    
    if (file && function) {
        [message appendFormat:@" <%@:%ld %@>", [file lastPathComponent], (unsigned long) logMessage->_line, function];
    } else if (classString && file) {
        [message appendFormat:@" <%@:%ld %@>", [file lastPathComponent], (unsigned long) logMessage->_line, classString];
    } else if (classString) {
        [message appendFormat:@" <%@>", classString];
    }

    [message appendFormat:@": %@", logMessage->_message];
    return message;
}

- (void)didAddToLogger:(id <DDLogger>)logger {
    loggerCount++;
    NSAssert(loggerCount <= 1, @"This logger isn't thread-safe");
}

- (void)willRemoveFromLogger:(id <DDLogger>)logger {
    loggerCount--;
}

@end