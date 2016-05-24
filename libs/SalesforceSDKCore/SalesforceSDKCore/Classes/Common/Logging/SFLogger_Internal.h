//
//  SFLogger_Internal.h
//  SalesforceSDKCore
//
//  Created by Michael Nachbaur on 5/16/16.
//  Copyright © 2016 salesforce.com. All rights reserved.
//

#import <CocoaLumberjack/CocoaLumberjack.h>

#import "SFLogStorage.h"

extern NSString * SFLogNameForFlag(SFLogFlag flag);
extern NSString * SFLogNameForLogLevel(SFLogLevel level);

@interface DDLog () <SFLogStorage> @end

@interface SFLogIdentifier : NSObject

@property (nonatomic, weak) SFLogger *logger;
@property (nonatomic, copy, readonly) NSString *identifier;
@property (nonatomic, assign) SFLogLevel logLevel;
@property (nonatomic, assign, readonly) SFLogFlag logFlag;
@property (nonatomic, assign) NSInteger context;

- (instancetype)initWithIdentifier:(NSString*)identifier NS_DESIGNATED_INITIALIZER;

@end

/////////////////

@interface SFLogTag : NSObject

@property (nonatomic, strong, readonly) id sender;
@property (nonatomic, strong, readonly) Class originClass;

- (instancetype)initWithClass:(Class)originClass sender:(id)sender;

@end

/////////////////

@interface SFLogger () {
@public
    int32_t _contextCounter;
    NSMutableDictionary<NSString*,SFLogIdentifier*> *_logIdentifiers;
    NSMutableArray<SFLogIdentifier*> *_logIdentifiersByContext;
    NSObject<SFLogStorage> *_ddLog;
    DDFileLogger *_fileLogger;
    DDTTYLogger *_ttyLogger;
}

- (SFLogIdentifier*)logIdentifierForIdentifier:(NSString*)identifier;
- (SFLogIdentifier*)logIdentifierForContext:(NSInteger)context;
- (void)resetLoggers;

@end
