//
//  Logger.h
//  ChatterSDK
//
//  Copyright 2012 Salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum SFLogLevel {
	Debug,
	Info,
	Warning,
	Error,
} SFLogLevel;


#define SFLogAssert(_cond, _desc, ...) \
do { \
if (!(_cond)) { \
[Logger logAssertionFailureInMethod:_cmd object:(self) file:[NSString stringWithUTF8String:__FILE__] lineNumber:__LINE__ description:(_desc), ##__VA_ARGS__]; \
} \
} while (0) \


/*!
 Allows your class to log messages specific to that class.
 You should be able to use this 99% of the time.
 */
@interface NSObject (SFLogging) 
-(void)log:(SFLogLevel)level msg:(NSString *)msg;
-(void)log:(SFLogLevel)level format:(NSString *)msg, ...;
@end


/*!
 Generic logging utility: logs to both console and persistent file.
 */
@interface SFLogger : NSObject {
	SFLogLevel		logLevel;
	NSString		*logFile;
	NSUInteger		fileSize;
	NSFileHandle	*logHandle;
	NSDateFormatter *dateFormatter;
}

+ (SFLogLevel)LogLevel;
+ (void)setLogLevel:(SFLogLevel)newLevel;
+ (void)logToFile:(NSString *)file;

/** Get access to the content of the application log file.
 */
+ (NSString *)logFileContents;

/*!
 Should only be used if you don't have an NSObject instance to
 log from.
 */
+ (void)log:(Class)cls level:(SFLogLevel)level msg:(NSString *)msg;

+ (void)logAssertionFailureInMethod:(SEL)method object:(id)obj file:(NSString *)file lineNumber:(NSUInteger)line description:(NSString *)desc, ...;

/*!
 Sets the log level based on the user preferences.
 */
+ (void)applyLogLevelFromPreferences;

@end
