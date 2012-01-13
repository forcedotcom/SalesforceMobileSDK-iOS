//
//  SFJsonUtils.h
//  SalesforceHybridSDKFake
//
//  Created by Todd Stellanova on 1/12/12.
//  Copyright (c) 2012 Salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SFJsonUtils : NSObject


+ (NSString*)JSONRepresentation:(id)obj;
+ (id)objectFromJSONString:(NSString *)jsonString;
+ (id)objectFromJSONData:(NSData *)jsonData;

@end
