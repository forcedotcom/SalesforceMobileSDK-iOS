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

#import "SFLogger.h"


@interface SFLogger ()

@property (retain) NSFileHandle *logHandle;
@property (readonly) NSDateFormatter *dateFormatter;
@property (assign) SFLogLevel logLevel;
@property (retain) NSString *logFile;

+ (NSDate *)startDateOfLog:(NSString *)log;
+ (NSDate *)endDateOfLog:(NSString *)log;

+ (NSString *)LogFile;

+ (void)log:(Class)cls level:(SFLogLevel)level msg:(NSString *)msg arguments:(va_list)args;

- (NSString *)levelName:(SFLogLevel)level;

/**
 Use this method to enable the recording of the assertion instead of aborting the
 program when an assertion is triggered. This is usually used by the 
 unit tests.
 */
+ (void)setRecordAssertionEnabled:(BOOL)enabled;

/**
 Returns YES if an assertion was recorded and clear the flag.
 */
+ (BOOL)assertionRecordedAndClear;

@end
