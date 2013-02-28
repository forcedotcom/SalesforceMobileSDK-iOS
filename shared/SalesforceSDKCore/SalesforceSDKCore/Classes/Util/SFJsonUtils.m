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
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    id result = [self objectFromJSONData:jsonData];
    return result;
}

+ (NSString*)JSONRepresentation:(id)obj {
    NSString *result = nil;
    
    NSData *jsonData = [self JSONDataRepresentation:obj];
    if (nil != jsonData) {
          result = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
    
    return result;
}

+(NSData*)JSONDataRepresentation:(id)obj {
    NSError *err = nil;
    NSData *jsonData = nil;
    
    if (nil != obj) {
        NSJSONWritingOptions options = 0;
#ifdef DEBUG
        options = NSJSONWritingPrettyPrinted;
#endif
        jsonData = [NSJSONSerialization dataWithJSONObject:obj 
                                        options:options 
                                          error:&err
         ];
        
        if (nil != err) {
            NSLog(@"WARNING error writing json: %@",err);
        } 
        
        if (nil == jsonData) {
            NSLog(@"unexpected nil json rep for: %@",obj);
        }
        
    } else {
        NSLog(@"nil object passed to JSONDataRepresentation???");
    }
    return  jsonData;
}

+ (id)projectIntoJson:(NSDictionary *)jsonObj path:(NSString *)path {
    id result = nil;
    
    if (!path || [path length] == 0) {
        return jsonObj;
    }
    
    if (nil != jsonObj) {
        id o = jsonObj;
        NSArray *pathElements = [path componentsSeparatedByString:@"."];
        for (NSString *pathElement in pathElements) {
            if ([o isKindOfClass:[NSDictionary class]]) {
                o = [(NSDictionary*)o objectForKey:pathElement];
            } else  {
                NSLog(@"unexpected object in compound path (%@): %@",pathElement, o);
                o = nil;
                break;
            }
        }
        result = o;
    }
    
    return result;
}


@end
