//
//  SFLogStorage.h
//  SalesforceSDKCore
//
//  Created by Michael Nachbaur on 5/16/16.
//  Copyright © 2016 salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol SFLogStorage <NSObject>

@property (nonatomic, strong, readonly) NSArray<id<DDLogger>> *allLoggers;

- (void)flushLog;

- (void)addLogger:(id <DDLogger>)logger;
- (void)removeLogger:(id <DDLogger>)logger;
- (void)removeAllLoggers;

- (void)log:(BOOL)asynchronous
      level:(DDLogLevel)level
       flag:(DDLogFlag)flag
    context:(NSInteger)context
       file:(const char *)file
   function:(const char *)function
       line:(NSUInteger)line
        tag:(id)tag
     format:(NSString *)format
       args:(va_list)args;

@end
