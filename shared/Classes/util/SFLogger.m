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

#import <execinfo.h> // backtrace_symbols
#import <libkern/OSAtomic.h>

#import "SFLogger+Internal.h"
#import "SFPathUtil.h"

#if defined(DEBUG)
static const NSUInteger DEFAULT_LOG_LEVEL = Debug;
#else
static const NSUInteger DEFAULT_LOG_LEVEL = Info;
#endif

static const NSUInteger MAX_LOG_FILE = 64 * 1024; // 64k

@implementation NSObject (Logging)

- (void)log:(SFLogLevel)level msg:(NSString *)msg {
	[SFLogger log:[self class] level:level msg:msg];
}

- (void)log:(SFLogLevel)level format:(NSString *)msg, ... {
	va_list list;
	va_start(list, msg);
	[SFLogger log:[self class] level:level msg:msg arguments:list];
	va_end(list);
}
@end

static SFLogger *instance;
static BOOL recordAssertion = NO;
static BOOL assertionRecorded = NO;

@implementation SFLogger

@synthesize logLevel, logFile, logHandle, dateFormatter;

+ (void)initialize {
	// by creating this here, we don't have to deal with any locking/contention issues
	// the runtime ensures this is called exactly once and before any messages to 
	// our class are dispatched.
	instance = [[SFLogger alloc] init];
}

+ (void)setRecordAssertionEnabled:(BOOL)enabled {
    recordAssertion = enabled;
}

+ (void)setAssertionRecorded:(BOOL)flag {
    @synchronized (self) {
        assertionRecorded = flag;
    }
}

+ (BOOL)assertionRecordedAndClear {
    BOOL recorded = NO;
    @synchronized (self) {
        recorded = assertionRecorded;
        assertionRecorded = NO;
    }
    return recorded;
}

+ (void)setLogLevel:(SFLogLevel)newLevel {
	[instance setLogLevel:newLevel];
}

+ (SFLogLevel) LogLevel {
	return [instance logLevel];
}

+ (NSString *)LogFile {
	return [instance logFile];
}

+ (void)applyLogLevelFromPreferences {
    NSUInteger logLevel = [[NSUserDefaults standardUserDefaults] integerForKey:@"SFPrefLogLevel"];
    switch (logLevel) {
        case 1:
            [self setLogLevel:Debug];
            break;
            
        case 2:
            [self setLogLevel:Info];
            break;
            
        case 3:
            [self setLogLevel:Warning];
            break;
            
        case 4:
            [self setLogLevel:Error];
            break;
            
        default:
            [self setLogLevel:DEFAULT_LOG_LEVEL];
            break;
    }
    NSLog(@"Changed log level to %@", [instance levelName:[self LogLevel]]);
}

- (id)init {
	self = [super init];
	dateFormatter = [[NSDateFormatter alloc] init];
	[dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
	[dateFormatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"GMT"]];
	logLevel = Info;
	fileSize = 0;
	logFile = nil;
	return self;
}

- (void)dealloc {
	[logFile release];
	[dateFormatter release];
	[logHandle release];
	[super dealloc];
}

- (NSString *)levelName:(SFLogLevel)level {
	switch (level) {
		case Debug		: return @"DEBUG";
		case Info		: return @"INFO";
		case Warning	: return @"WARN"; //per new log format
		case Error		: return @"ERROR";
	}
	return [NSString stringWithFormat:@"<unknown level %d>", level];
}

- (void)logToFile:(NSString *)file {
	NSString *absoluteFile = [[SFPathUtil absolutePathForDocumentFolder:@"logs"] stringByAppendingPathComponent:file];
	@synchronized (self) {
		NSLog(@"Switching logging to file %@", absoluteFile);
		fileSize = [[[[NSFileManager defaultManager] attributesOfItemAtPath:absoluteFile error:nil] objectForKey:NSFileSize] unsignedIntValue];
		//freopen([absoluteFile cStringUsingEncoding:NSASCIIStringEncoding], "a", stderr);
		[logHandle closeFile];
		if(![[NSFileManager defaultManager] fileExistsAtPath:absoluteFile]) {
			[[NSFileManager defaultManager] createFileAtPath:absoluteFile contents:nil attributes:nil];
		}
		[self setLogHandle:[NSFileHandle fileHandleForUpdatingAtPath:absoluteFile]];
		NSAssert(logHandle != nil, @"logger handle could not be created");
		[logHandle seekToEndOfFile];
		[self setLogFile:absoluteFile];
	}
}

- (NSString *)logFileContents {
	if (logFile == nil) return nil;
	NSString *oldFile = [logFile stringByAppendingPathExtension:@"old"];
	NSString *old, *cur;
	@synchronized (self) {
		old = [NSString stringWithContentsOfFile:oldFile encoding:NSUTF8StringEncoding error:nil];
		[logHandle seekToFileOffset:0];
		cur = [[[NSString alloc] initWithData:[logHandle readDataToEndOfFile] encoding:NSUTF8StringEncoding] autorelease];
		[logHandle seekToEndOfFile];
	}
	if (old == nil) return cur;
	return [NSString stringWithFormat:@"%@%@", old, cur];
}

- (void)appendToLog:(NSString *)s {
    @synchronized (self) {
        if (logFile != nil) {
            if (fileSize > MAX_LOG_FILE) {
                [[NSFileManager defaultManager] removeItemAtPath:[[self logFile] stringByAppendingPathExtension:@"old"] error:nil];
                [[NSFileManager defaultManager] moveItemAtPath:[self logFile] toPath:[[self logFile] stringByAppendingPathExtension:@"old"] error:nil];
                [self logToFile:[logFile lastPathComponent]];
            }
            fileSize += [s lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
            fileSize += 2; // plus 2 for line ending
        }
        [logHandle writeData:[s dataUsingEncoding:NSUTF8StringEncoding]];
        [logHandle synchronizeFile];
    }
}

- (NSString *)timestamp {
    @synchronized (self) {
        return [dateFormatter stringFromDate:[NSDate date]];        
    }
}

// A identifier that is incremented safely to uniquely identify each thread
static int32_t UniqueThreadIdentifier = 0;

/**
 Returns the current thread identifier. The main thread is always 0 while
 other threads will get a unique number.
 */
- (NSUInteger)threadIdentifier {
    static NSString *key = @"threadId";
    NSNumber *num = [[[NSThread currentThread] threadDictionary] objectForKey:key];
    if (nil == num) {
        NSUInteger tnum;
        if ([NSThread isMainThread]) {
            tnum = 0;
        } else {
            tnum = OSAtomicIncrement32(&UniqueThreadIdentifier);
        }
        num = [NSNumber numberWithUnsignedInteger:tnum];
        [[[NSThread currentThread] threadDictionary] setObject:num forKey:key];
    }
    return [num unsignedIntegerValue];
}

/**
 Returns the current thread information. The main thread returns always 0 while
 other threads returns <tnum>-<tname> where tnum is the identifier of the thread
 and tname the name of the thread (if present).
 */
- (NSString*)threadInfo {
    NSString *name = [[NSThread currentThread] name];
    if (0 == [name length] || [NSThread isMainThread]) {
        return [NSString stringWithFormat:@"%d", [self threadIdentifier]];
    } else {
        return [NSString stringWithFormat:@"%d-%@", [self threadIdentifier], name];
    }
}

- (void)log:(Class)cls level:(SFLogLevel)level msg:(NSString *)msg {
	if (level >= logLevel) {
		NSString *s = [NSString stringWithFormat:@"%@|%@|%@|%@|%@\n", [self levelName:level], [self timestamp], [self threadInfo], cls, msg];
		[self appendToLog:s];
        NSLog(@"%@|%@|%@|%@", [self levelName:level], [self threadInfo], cls, msg);
	}
}

- (void)log:(Class)cls level:(SFLogLevel)level msg:(NSString *)msg arguments:(va_list)args {
	if (level >= logLevel) {
		NSString *formattedMsg = [[[NSString alloc] initWithFormat:msg arguments:args] autorelease];
		[self log:cls level:level msg:formattedMsg];
	}
}

+ (void)log:(Class)cls level:(SFLogLevel)level msg:(NSString *)msg {
	[instance log:cls level:level msg:msg];
}

+ (void)log:(Class)cls level:(SFLogLevel)level msg:(NSString *)msg arguments:(va_list)args {
	[instance log:cls level:level msg:msg arguments:args];
}

+ (void)logAssertionFailureInMethod:(SEL)method object:(id)obj file:(NSString *)file lineNumber:(NSUInteger)line description:(NSString *)desc, ... {
#ifndef NS_BLOCK_ASSERTIONS
    NSString *message = [NSString stringWithFormat:@"ASSERTION FAILURE: [%@ %@] [file:%@ line:%d]: ", 
                         NSStringFromClass([obj class]), NSStringFromSelector(method), 
                         file, line];
    va_list args;
    va_start(args, desc);
    NSString *m = [[NSString alloc] initWithFormat:desc arguments:args];
    va_end(args);
    [instance appendToLog:[NSString stringWithFormat:@"%@ %@", message, m]];
    NSLog(@"%@ %@", message, m);
    [m release];
    
    /* log backtrace: */
    void *array[100];
    size_t size;
    char **strings;
    size_t i;
    
    size = backtrace (array, 100);
    strings = backtrace_symbols (array, size);
    
    NSMutableString *stackTraces = [[NSMutableString alloc] init];
    for (i = 0; i < size; i++) {
        [stackTraces appendFormat:@"%s\n", strings[i]];
    }
    
    free (strings);
    [instance appendToLog:stackTraces];
    NSLog(@"\n%@", stackTraces);
    [stackTraces release];
    if (recordAssertion) {
        [self setAssertionRecorded:YES];
    } else {
#ifdef DEBUG
        abort();
#endif /* DEBUG */
    }
#endif /* NS_BLOCK_ASSERTIONS */
    
}

+ (void)logToFile:(NSString *)file {
	[instance logToFile:file];
}

+ (NSString *)logFileContents {
	return [instance logFileContents];
}


+ (NSDate *)startDateOfLog:(NSString *)log {
	NSRange searchRange = NSMakeRange(0, [log length]-1);
	while((searchRange.location+searchRange.length) < [log length] && searchRange.length > 0 && searchRange.location != NSNotFound) {
		NSRange datePart = [log rangeOfString:@"|" options:0 range:searchRange];
		datePart.location += 1; // advance into the timestamp area
		datePart.length = 19; // the length of a timestamp given by [instance dateFormatter]
		int nextBreakPos = datePart.location + datePart.length;
		if([log length] > nextBreakPos && [log characterAtIndex:nextBreakPos] == '|') {
			NSString *d = [log substringWithRange:datePart];
			return [[instance dateFormatter] dateFromString:d];
		}
		searchRange.location = [log rangeOfString:@"\n" options:0 range:searchRange].location+1;
	}
	return nil;
}

+ (NSDate *)endDateOfLog:(NSString *)log {
	NSUInteger end = [log length]-1;
	NSRange searchRange = NSMakeRange(0, end);
	while (searchRange.location != NSNotFound && searchRange.length > 0) {
		//find the '\n' , searching backwards.
		NSRange lineRange = [log rangeOfString:@"\n" options:NSBackwardsSearch range:searchRange];
		if(lineRange.location == NSNotFound) {
			return [SFLogger startDateOfLog:log]; // there are no new-lines, so the log is empty, or has only one line.
		}
		lineRange.location += 1; //advance past the "\n"
		lineRange.length = end-lineRange.location;
		NSString *line = [log substringWithRange:lineRange]; // this is the last line inside the "searchRange" range.
		NSDate *d = [SFLogger startDateOfLog:line];
		if(d != nil)
			return d;
		searchRange.length = lineRange.location-1; // searchRange MUST get smaller each loop iteration.
	}
	return nil;
}

@end
