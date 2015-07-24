/*
 Copyright (c) 2014, salesforce.com, inc. All rights reserved.
 
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

#import "SFSmartSyncObjectUtils.h"

__strong static NSDateFormatter *utcDateFormatter;
__strong static NSDateFormatter *isoDateFormatter;

@implementation SFSmartSyncObjectUtils

+ (void) initialize {
    utcDateFormatter = [NSDateFormatter new];
    isoDateFormatter = [NSDateFormatter new];
    isoDateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSSZ";
}

+ (NSString *)formatValue:(id)value {
    if (nil == value) {
        value = nil;
    } else {
        if ([value isEqual:[NSNull null]]) {
            value = nil;
        } else if ([value isKindOfClass:[NSString class]]) {
            if ([((NSString *)value) isEqualToString:@"<null>"]) {
                value = nil;
            }
        }
    }
    NSString *returnValue;
    if (nil == value) {
        returnValue = @"";
    } else if ([value isKindOfClass:[NSNumber class]]) {
        NSNumber *number = (NSNumber *)value;
        returnValue = [number stringValue];
    } else if ([value isKindOfClass:[NSString class]]) {
        returnValue = (NSString *)value;
    } else if ([value respondsToSelector:@selector(stringValue)]) {
        returnValue = (NSString *)[value performSelector:@selector(stringValue)];
    }
    return returnValue;
}

+ (NSString *)formatLocalDateToGMTString:(NSDate *)localDate {
    if (nil == localDate) {
        return nil;
    }
    NSString *dateString = [utcDateFormatter stringFromDate:localDate];
    return dateString;
}

+ (long long) getMillisFromIsoString:(NSString*) dateStr {
    NSDate* date = [isoDateFormatter dateFromString:dateStr];
    if (nil == date) {
        return -1;
    }
    return (long long) (date.timeIntervalSince1970 * 1000.0);
}

+ (NSString*) getIsoStringFromMillis:(long long) millis {
    if (millis < 0) {
        return nil;
    }
    NSDate* date = [NSDate dateWithTimeIntervalSince1970:((double)millis)/1000.0];
    return [isoDateFormatter stringFromDate:date];
}

+ (NSDate *)getDateFromIsoDateString:(NSString *)isoDateString {
    if (isoDateString.length == 0) {
        return nil;
    }
    
    return [isoDateFormatter dateFromString:isoDateString];
}

+ (NSString *)getIsoStringFromDate:(NSDate *)date {
    if (date == nil) return nil;
    
    return [isoDateFormatter stringFromDate:date];
}

+ (BOOL)isEmpty:(NSString *)value {
    BOOL isEmpty = NO;
    if (nil == value || [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]].length == 0) {
        isEmpty = YES;
    }
    return isEmpty;
}

@end
