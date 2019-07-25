//
//  SFSDKOAuth2+Internal.h
//  SalesforceSDKCore
//
//  Created by Raj Rao on 7/18/19.
//  Copyright © 2019 salesforce.com. All rights reserved.
//

#import <SalesforceSDKCore/SalesforceSDKCore.h>
#import "SFSDKOAuth2.h"
NS_ASSUME_NONNULL_BEGIN

@interface SFSDKOAuth2()
+ (NSDictionary *)parseQueryString:(NSString *)query;
+ (NSDictionary *)parseQueryString:(NSString *)query decodeParams:(BOOL)decodeParams;
+ (NSError *)errorWithType:(NSString *)type description:(NSString *)description;
+ (NSError *)errorWithType:(NSString *)type description:(NSString *)description underlyingError:(NSError *_Nullable)underlyingError;
+ (NSDate *)timestampStringToDate:(NSString *)timestamp;
@end

NS_ASSUME_NONNULL_END
