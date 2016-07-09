/*
 Copyright (c) 2011, salesforce.com, inc. All rights reserved.
 
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

#import "SFJsonUtils.h"

static NSError *sLastError = nil;

@implementation SFJsonUtils

+ (NSError *)lastError
{
    return sLastError;
}

+ (id)objectFromJSONData:(NSData *)jsonData
{
    NSError *err = nil;
    id result = nil;
    if(jsonData) {
        result = [NSJSONSerialization JSONObjectWithData:jsonData
                                                 options:NSJSONReadingMutableContainers
                                                   error:&err
                  ];

        if (nil != err) {
            [self log:SFLogLevelDebug format:@"WARNING error parsing json: %@", err];
            sLastError = err;
        }
    }
    return result;
}

+ (id)objectFromJSONString:(NSString *)jsonString {
    id result = nil;
    if ([jsonString isKindOfClass:[NSString class]]) {
        NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
        result = [self objectFromJSONData:jsonData];
    }
    return result;
}

+ (NSString*)JSONRepresentation:(id)obj {
    NSJSONWritingOptions options = 0;
#ifdef DEBUG
    options = NSJSONWritingPrettyPrinted;
#endif
    return [SFJsonUtils JSONRepresentation:obj options:options];
}

+ (NSString*)JSONRepresentation:(id)obj options:(NSJSONWritingOptions)options {
    NSString *result = nil;
    
    NSData *jsonData = [self JSONDataRepresentation:obj options:options];
    if (nil != jsonData) {
          result = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
    
    return result;
}

+(NSData*)JSONDataRepresentation:(id)obj {
    NSJSONWritingOptions options = 0;
#ifdef DEBUG
    options = NSJSONWritingPrettyPrinted;
#endif
    return [SFJsonUtils JSONDataRepresentation:obj options:options];
}

+(NSData*)JSONDataRepresentation:(id)obj options:(NSJSONWritingOptions)options {
    NSError *err = nil;
    NSData *jsonData = nil;
    
    if ([NSJSONSerialization isValidJSONObject:obj]) {
        jsonData = [NSJSONSerialization dataWithJSONObject:obj
                                        options:options 
                                          error:&err
         ];
        
        if (nil != err) {
            [self log:SFLogLevelDebug format:@"WARNING error writing json: %@", err];
            sLastError = err;
        } 
        
        if (nil == jsonData) {
            [self log:SFLogLevelDebug format:@"unexpected nil json rep for: %@",obj];
        }
        
    } else {
        [self log:SFLogLevelDebug format:@"invalid object passed to JSONDataRepresentation???"];
    }
    return  jsonData;
}

+ (id)projectIntoJson:(NSDictionary *)jsonObj path:(NSString *)path {
    if (!path || [path length] == 0) {
        return jsonObj;
    }
    
    NSArray *pathElements = [path componentsSeparatedByString:@"."];
    return [SFJsonUtils projectIntoJsonHelper:jsonObj pathElements:pathElements index:0];
}

+ (id)projectIntoJsonHelper:(id)jsonObj pathElements:(NSArray *)pathElements index:(NSUInteger)index {
    id result = nil;

    if (index == [pathElements count]) {
        return jsonObj;
    }

    if (nil != jsonObj) {
        NSString* pathElement = (NSString*) pathElements[index];
        if ([jsonObj isKindOfClass:[NSDictionary class]]) {
            NSDictionary* jsonDict = (NSDictionary*) jsonObj;
            id dictVal = jsonDict[pathElement];
            result = [SFJsonUtils projectIntoJsonHelper:dictVal pathElements:pathElements index:index+1];
        }
        else if ([jsonObj isKindOfClass:[NSArray class]]) {
            NSArray* jsonArr = (NSArray*) jsonObj;
            result = [NSMutableArray new];
            for (id arrayElt in jsonArr) {
                id resultPart = [SFJsonUtils projectIntoJsonHelper:arrayElt pathElements:pathElements index:index];
                if (resultPart != nil) {
                    [result addObject:resultPart];
                }
            }
            if ([result count] == 0) {
                result = nil;
            }
        }
    }
    
    return result;
}


@end
