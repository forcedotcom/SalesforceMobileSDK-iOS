/*
 Copyright (c) 2015, salesforce.com, inc. All rights reserved.
 
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

#import "NSDictionary+SFAdditions.h"
#import "NSString+SFAdditions.h"
#import "NSArray+SFAdditions.h"
#import "SFLogger.h"

@implementation NSDictionary (SFAdditions)

- (id) objectAtPath:(NSString *) path {
    if (path == nil) {
        return nil;
    }
    
    id obj = self;
    NSArray *elements = [path componentsSeparatedByString: @"/"];
    for (NSString *element in elements) {
        obj = [obj nonNullObjectForKey:element];
        if (obj == nil) {
            return nil;
        }
    }
    
    if (nil != obj) {
        if ([obj isKindOfClass:[NSString class]]) {
            obj = [NSString unescapeXMLCharacter:obj];
        }
    }
    return obj;
}

- (id)nonNullObjectForKey:(id)key {
    id result = [self objectForKey:key];
    if (result == [NSNull null]) {
        return nil;
    }
    if ([result isKindOfClass:[NSString class]] && ([result isEqualToString:@"<nil>"] || [result isEqualToString:@"<null>"])) {
        return nil;
    }
    
    return result;
}

- (NSString*)jsonString {
    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:self
                                                       options:0
                                                         error:&error];
    NSString *jsonString = nil;
    if (error) {
        [self log:SFLogLevelWarning format:@"Unable to serializing to JSON string. NSDictionary:%@. Error:%@", self, error];
        jsonString = @"{}";
    } else {
        jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
    return jsonString;
}

@end
