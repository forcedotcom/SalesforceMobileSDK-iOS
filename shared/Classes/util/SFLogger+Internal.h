//
//  Logger+Internal.h
//  ChatterSDK
//
//  Copyright 2012 Salesforce.com. All rights reserved.
//

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
