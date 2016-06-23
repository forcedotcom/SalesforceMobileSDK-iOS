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

#import "AILTNPublisher.h"

// TODO: Add GZIP compression to the header and data.

static NSString* const kCode = @"code";
static NSString* const kAiltn = @"ailtn";
static NSString* const kJsonData = @"jsonData";
static NSString* const kData = @"data";
static NSString* const kLogLines = @"logLines";
static NSString* const kApiPath = @"/services/data/%s/connect/proxy/app-analytics-logging";

@implementation AILTNPublisher

+ (BOOL) publish:(NSArray *) events {
    if (!events || [events count] == 0) {
        return true;
    }

    // Builds the POST body of the request.
    NSMutableDictionary *body = [[NSMutableDictionary alloc] init];
    NSMutableArray *logLines = [[NSMutableArray alloc] init];
    for (int i = 0; i < logLines.count; i++) {
        NSDictionary *event = [events objectAtIndex:i];
        if (event) {
            NSMutableDictionary *trackingInfo = [[NSMutableDictionary alloc] init];
            trackingInfo[kCode] = kAiltn;
            NSMutableDictionary *eventData = [[NSMutableDictionary alloc] init];
            eventData[kJsonData] = event;
            trackingInfo[kData] = eventData;
            [logLines addObject:trackingInfo];
        }
    }
    body[kLogLines] = logLines;
    
    
    /*final String apiPath = String.format(API_PATH,
                                         ApiVersionStrings.getVersionNumber(SalesforceSDKManager.getInstance().getAppContext()));
    final RestClient restClient = SalesforceSDKManager.getInstance().getClientManager().peekRestClient();
    final RequestBody requestBody = RequestBody.create(RestRequest.MEDIA_TYPE_JSON, body.toString());
    final RestRequest restRequest = new RestRequest(RestRequest.RestMethod.POST, apiPath, requestBody);
    RestResponse restResponse = null;
    try {
        restResponse = restClient.sendSync(restRequest);
    } catch (IOException e) {
        Log.e(TAG, "Exception thrown while making network request", e);
    }
    if (restResponse != null && restResponse.isSuccess()) {
        return true;
    }
    return false;*/
    
    
    return NO;
}

@end
