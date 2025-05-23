/*
 AILTNPublisher.m
 SalesforceSDKCore
 
 Created by Bharath Hariharan on 6/19/16.
 
 Copyright (c) 2016-present, salesforce.com, inc. All rights reserved.
 
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
#import "NSData+SFAdditions.h"
#import "SFRestAPI+Blocks.h"
#import "SalesforceSDKCore/SalesforceSDKCore-Swift.h"

static NSString* const kCode = @"code";
static NSString* const kAiltn = @"ailtn";
static NSString* const kData = @"data";
static NSString* const kLogLines = @"logLines";
static NSString* const kPayload = @"payload";
static NSString* const kRestApiSuffix = @"connect/proxy/app-analytics-logging";

@implementation SFSDKAILTNPublisher

- (void) publish:(NSArray *) events user:(SFUserAccount *)user publishCompleteBlock:(PublishCompleteBlock) publishCompleteBlock {
    if (!events || [events count] == 0) {
        publishCompleteBlock(NO, nil);
        return;
    }

    // Builds the POST body of the request.
    NSDictionary *bodyDictionary = [[self class] buildRequestBody:events];
    [[self class] publishLogLines:bodyDictionary user:user publishCompleteBlock:publishCompleteBlock];
}

+ (void) publishLogLines:(NSDictionary *) bodyDictionary user:(SFUserAccount *)user publishCompleteBlock:(PublishCompleteBlock) publishCompleteBlock {
    SFRestAPI *restAPI = [SFRestAPI sharedInstanceWithUser:user];
    
    NSString *path = [NSString stringWithFormat:@"/%@/%@", kSFRestDefaultAPIVersion, kRestApiSuffix];
    SFRestRequest *request = [SFRestRequest requestWithMethod:SFRestMethodPOST path:path queryParams:nil];

    // Adds GZIP compression.
    NSString *bodyString = [[self class] dictionaryAsJSONString:bodyDictionary];
    NSData *bodyData = [bodyString dataUsingEncoding:NSUTF8StringEncoding];
    NSData *postData = [bodyData sfsdk_gzipDeflate];
    [request setCustomRequestBodyData:postData contentType:@"application/json"];
    [request setHeaderValue:@"gzip" forHeaderName:@"Content-Encoding"];
    [request setHeaderValue:[NSString stringWithFormat:@"%lu", (unsigned long)[postData length]] forHeaderName:@"Content-Length"];

    [restAPI sendRequest:request failureBlock:^(id response, NSError *e, NSURLResponse *rawResponse) {
        if (e) {
            [SFSDKCoreLogger e:[self class] format:@"Upload failed %ld %@", (long)[e code], [e localizedDescription]];
        }
        publishCompleteBlock(NO, e);
    } successBlock:^(id response, NSURLResponse *rawResponse) {
        publishCompleteBlock(YES, nil);
    }];
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
        [SFSDKCoreLogger e:[self class] format:@"%@ - invalid object passed to JSONDataRepresentation", [self class]];
        return nil;
    }
}

@end
