//
//  SFJsonUtils.m
//  SalesforceHybridSDKFake
//
//  Created by Todd Stellanova on 1/12/12.
//  Copyright (c) 2012 Salesforce.com. All rights reserved.
//

#import "SFJsonUtils.h"

@implementation SFJsonUtils


+ (id)objectFromJSONData:(NSData *)jsonData
{
    NSError *err = nil;
    id result = [NSJSONSerialization JSONObjectWithData:jsonData 
                                                options:NSJSONReadingMutableContainers 
                                                  error:&err
                 ];
    
    if (nil != err) {
        NSLog(@"WARNING error parsing json: %@",err);
    }
    
    return result;
}

+ (id)objectFromJSONString:(NSString *)jsonString {
    //    SBJsonParser *parser = [[SBJsonParser alloc] init];
    //    id obj  = [parser objectWithString:rawJson];
    //    [parser release];
    //    return obj;
    
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    id result = [self objectFromJSONData:jsonData];
    return result;
}

+ (NSString*)JSONRepresentation:(id)obj {
    NSString *result = nil;
    NSError *err = nil;
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:obj 
                                                       options:0 //NSJSONWritingPrettyPrinted 
                                                         error:&err
                        ];
    if (nil != err) {
        NSLog(@"WARNING error writing json: %@",err);
    }
    result = [[NSString alloc]initWithData:jsonData encoding:NSUTF8StringEncoding];
    return [result autorelease];
}

@end
