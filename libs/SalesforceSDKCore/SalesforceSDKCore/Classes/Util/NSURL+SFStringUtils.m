/*
 Copyright (c) 2012, salesforce.com, inc. All rights reserved.
 Author: Kevin Hawkins
 
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

#import "NSURL+SFStringUtils.h"

NSString * const kSFRedactedQuerystringValue = @"[redacted]";

@implementation NSURL (SFStringUtils)

- (NSString *)redactedAbsoluteString:(NSArray *)queryStringParamsToRedact
{
    if (queryStringParamsToRedact == nil || [queryStringParamsToRedact count] == 0 || [self query] == nil || [[self query] length] == 0)
        return [self absoluteString];
    
    // Initialize the new URL.
    NSMutableString *redactedUrl = [NSMutableString stringWithFormat:@"%@://%@", [self scheme], [self host]];
    if ([self port] != nil)
        [redactedUrl appendFormat:@":%@", [self port]];
    [redactedUrl appendFormat:@"%@?", [self path]];
    
    // Loop through the querystring to evaluate the parameters.
    NSArray *queryNameValPairs = [[self query] componentsSeparatedByString:@"&"];
    for (int i = 0; i < [queryNameValPairs count]; i++) {
        NSString *nameValPairString = queryNameValPairs[i];
        NSArray *nameValPair = [nameValPairString componentsSeparatedByString:@"="];
        if (nameValPair == nil || [nameValPair count] != 2) {
            // If it's just a "hanging" parameter (e.g. &fromEmail as opposed to &fromEmail=1),
            // just take it as-is.
            [redactedUrl appendString:nameValPairString];
            continue;
        }
        
        // Got a good name/value pair.  See if any of the parameters to redact match this pair.
        NSString *name = nameValPair[0];
        NSString *redactedNameValuePairString = nil;
        for (int qspIndex = 0; qspIndex < [queryStringParamsToRedact count]; qspIndex++) {
            NSString *paramToRedact = queryStringParamsToRedact[qspIndex];
            if ([[paramToRedact lowercaseString] isEqualToString:[name lowercaseString]]) {
                // Got one!  Redact it.
                redactedNameValuePairString = [NSString stringWithFormat:@"%@=%@", name, kSFRedactedQuerystringValue];
                break;
            }
        }
        
        // Did we get one?  If so, add it.  If not, add back the original.
        if (i > 0)
            [redactedUrl appendString:@"&"];
        if (redactedNameValuePairString == nil) {
            [redactedUrl appendString:nameValPairString];
        } else {
            [redactedUrl appendString:redactedNameValuePairString];
        }
    }
    
    return redactedUrl;
}

+ (NSString*)stringUrlWithBaseUrl:(NSURL*)baseUrl pathComponents:(NSArray*)pathComponents {
    NSMutableString *absoluteUrl = [[NSMutableString alloc] initWithString:[baseUrl absoluteString]?:@""];
    [self appendPathComponents:pathComponents toMutableUrlString:absoluteUrl];
    return absoluteUrl;
}

+ (NSString*)stringUrlWithScheme:(NSString*)scheme host:(NSString*)host port:(NSNumber*)port pathComponents:(NSArray*)pathComponents {
    if (!host || !scheme) {
        return nil;
    }
    NSMutableString *absoluteUrl = [[NSMutableString alloc] init];
    [absoluteUrl appendFormat:@"%@://", scheme];
    [absoluteUrl appendString:host];
    if (port) {
        [absoluteUrl appendFormat:@":%@", port];
    }
    
    [self appendPathComponents:pathComponents toMutableUrlString:absoluteUrl];

    return absoluteUrl;
}

+ (void)appendPathComponents:(NSArray*)pathComponents toMutableUrlString:(NSMutableString*)urlString {
    for (NSString *c in pathComponents) {
        if ([c isEqualToString:@"/"]) {
            continue;
        }
        
        if (![c hasPrefix:@"/"] && ![urlString hasSuffix:@"/"]) {
            [urlString appendString:@"/"];
            [urlString appendString:c];
        } else if ([c hasPrefix:@"/"] && [urlString hasSuffix:@"/"]) {
            [urlString appendString:[c substringFromIndex:1]];
        } else {
            [urlString appendString:c];
        }
    }
}

@end
