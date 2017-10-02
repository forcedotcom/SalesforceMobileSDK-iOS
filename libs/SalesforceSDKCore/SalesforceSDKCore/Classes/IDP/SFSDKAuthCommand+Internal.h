//
//  SFSDKAuthCommand+Internal.h
//  SalesforceSDKCore
//
//  Created by Raj Rao on 10/1/17.
//  Copyright © 2017 salesforce.com. All rights reserved.
//

#import "SFSDKAuthCommand.h"

NS_ASSUME_NONNULL_BEGIN

@interface SFSDKAuthCommand (Internal)


@property (nonatomic,nonnull) NSString *command;
@property (nonatomic,nonnull) NSString *version;
@property (nonatomic,nonnull) NSString *scheme;
@property (nonatomic,nonnull) NSString *path;

- (void)setParamForKey:(NSString *)value key:(NSString *)key;
- (NSString *)paramForKey:(NSString *)key;
- (void)removeParam:(NSString *)key;

@end

NS_ASSUME_NONNULL_END
