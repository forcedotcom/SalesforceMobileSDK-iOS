//
//  NSDate+ActionValue.m
//  CoreSalesforce
//
//  Created by Michael Nachbaur on 12/8/14.
//  Copyright (c) 2014 Salesforce.com. All rights reserved.
//

#import "NSDate+ActionValue.h"
#import "CSFInternalDefines.h"

@implementation NSDate (ActionValue)

- (id)actionValue {
    return [[NSValueTransformer valueTransformerForName:CSFDateValueTransformerName] transformedValue:self];
}

+ (id<CSFActionValue>)decodedObjectForActionValue:(id)actionValue {
    return [[NSValueTransformer valueTransformerForName:CSFDateValueTransformerName] reverseTransformedValue:actionValue];
}

@end
