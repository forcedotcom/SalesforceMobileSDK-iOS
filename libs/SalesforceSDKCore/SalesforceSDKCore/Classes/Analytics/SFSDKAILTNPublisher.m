/*
 AILTNPublisher.m
 SalesforceSDKCore
 
 Created by Bharath Hariharan on 6/19/16.
 
 Copyright (c) 2016, salesforce.com, inc. All rights reserved.
 
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

#import "SFSDKAILTNPublisher.h"
#import "SFUserAccountManager.h"
#import "SalesforceSDKManager.h"
#import "SFLogger.h"
#import <zlib.h>

static NSString* const kCode = @"code";
static NSString* const kAiltn = @"ailtn";
static NSString* const kSchemaTypeKey = @"schemaType";
static NSString* const kData = @"data";
static NSString* const kLogLines = @"logLines";
static NSString* const kPayload = @"payload";
static NSString* const kRestApiPrefix = @"services/data";
static NSString* const kApiVersion = @"v36.0";
static NSString* const kRestApiSuffix = @"connect/proxy/app-analytics-logging";
static NSString* const kBearer = @"Bearer %@";

@implementation SFSDKAILTNPublisher

+ (BOOL) publish:(NSArray *) events {
    if (!events || [events count] == 0) {
        return true;
    }

    // Builds the POST body of the request.
    NSDictionary *bodyDictionary = [[self class] buildRequestBody:events];
    SFOAuthCredentials *credentials = [SFUserAccountManager sharedInstance].currentUser.credentials;
    NSURL *loggingEndpointUrl = [NSURL URLWithString:[NSString stringWithFormat:@"%@/%@/%@/%@", credentials.apiUrl, kRestApiPrefix, kApiVersion, kRestApiSuffix]];
    NSString *token = [NSString stringWithFormat:kBearer, credentials.accessToken];
    NSString *userAgent = [SalesforceSDKManager sharedManager].userAgentString(@"");
    __block NSError *error = nil;
    NSHTTPURLResponse* (^makeSynchronousRequest)(NSError**) = ^NSHTTPURLResponse* (NSError** error) {
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:loggingEndpointUrl
                                                               cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                           timeoutInterval:60.0];
        [request setHTTPMethod:@"POST"];
        [request setValue:userAgent forHTTPHeaderField:@"User-Agent"];
        [request setValue:@"false" forHTTPHeaderField:@"X-Chatter-Entity-Encoding"];
        [request setValue:token forHTTPHeaderField:@"Authorization"];
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

        // Adds GZIP compression.
        NSString *bodyString = [[self class] dictionaryAsJSONString:bodyDictionary];
        NSData *bodyData = [bodyString dataUsingEncoding:NSUTF8StringEncoding];
        NSData *postData = [[self class] gzipCompressedData:bodyData];
        [request setValue:@"gzip" forHTTPHeaderField:@"Content-Encoding"];
        [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)[postData length]] forHTTPHeaderField:@"Content-Length"];
        [request setHTTPBody:postData];
        NSHTTPURLResponse* response = nil;
        [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:error];
        return response;
    };
    NSHTTPURLResponse *response = makeSynchronousRequest(&error);
    NSInteger code = [response statusCode];
    if (error) {
        [SFLogger log:[self class] level:SFLogLevelError format:@"Upload failed %ld %@", (long)[error code], [error localizedDescription]];
        return NO;
    } else if (code >= 200 && code < 300) {
        return YES;
    }
    return NO;
}

+ (NSDictionary *) buildRequestBody:(NSArray *) events {
    NSMutableDictionary *body = [[NSMutableDictionary alloc] init];
    NSMutableArray *logLines = [[NSMutableArray alloc] init];
    for (int i = 0; i < events.count; i++) {
        NSMutableDictionary *event = [events objectAtIndex:i];
        if (event) {
            NSMutableDictionary *trackingInfo = [[NSMutableDictionary alloc] init];
            trackingInfo[kCode] = kAiltn;
            NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
            data[kSchemaTypeKey] = event[kSchemaTypeKey];
            [event removeObjectForKey:kSchemaTypeKey];
            data[kPayload] = [[self class] dictionaryAsJSONString:event];
            trackingInfo[kData] = data;
            [logLines addObject:trackingInfo];
        }
    }
    body[kLogLines] = logLines;
    return body;
}

+ (NSString *) dictionaryAsJSONString:(NSDictionary *) dict {
    NSError *error = nil;
    if ([NSJSONSerialization isValidJSONObject:dict]) {
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&error];
        if (error) {
            return nil;
        }
        NSString *jsonString = [[NSString alloc] initWithBytes:[jsonData bytes] length:[jsonData length] encoding:NSUTF8StringEncoding];
        jsonString = [jsonString stringByReplacingOccurrencesOfString:@"\\/" withString:@"/"];
        return jsonString;
    } else {
        [self log:SFLogLevelError format:@"%@ - invalid object passed to JSONDataRepresentation", [self class]];
        return nil;
    }
}

+ (NSData *) gzipCompressedData:(NSData *) data {
    if ([data length] == 0) {
        return data;
    }
    z_stream stream;
    stream.zalloc = Z_NULL;
    stream.zfree = Z_NULL;
    stream.opaque = Z_NULL;
    stream.total_out = 0;
    stream.next_in = (Bytef *)[data bytes];
    stream.avail_in = (uInt)[data length];
    if (deflateInit2(&stream, Z_DEFAULT_COMPRESSION, Z_DEFLATED, (15 + 16), 8, Z_DEFAULT_STRATEGY) != Z_OK) {
        return nil;
    }
    NSMutableData *compressed = [NSMutableData dataWithLength:16384];
    do {
        if (stream.total_out >= [compressed length]) {
            [compressed increaseLengthBy:16384];
        }
        stream.next_out = [compressed mutableBytes] + stream.total_out;
        stream.avail_out = (uInt)([compressed length] - stream.total_out);
        deflate(&stream, Z_FINISH);
    } while (stream.avail_out == 0);
    deflateEnd(&stream);
    [compressed setLength: stream.total_out];
    return [NSData dataWithData:compressed];
}

@end
