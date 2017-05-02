/*
 Copyright (c) 2015-present, salesforce.com, inc. All rights reserved.
 
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

#import "SFNetReactBridge.h"

#import <React/RCTUtils.h>

#import <SalesforceSDKCore/NSDictionary+SFAdditions.h>
#import <SalesforceSDKCore/SFRestAPI+Blocks.h>


// Private constants
NSString * const kMethodArg       = @"method";
NSString * const kPathArg         = @"path";
NSString * const kEndPointArg     = @"endPoint";
NSString * const kQueryParams     = @"queryParams";
NSString * const kHeaderParams    = @"headerParams";
NSString * const kfileParams      = @"fileParams";
NSString * const kFileMimeType    = @"fileMimeType";
NSString * const kFileUrl         = @"fileUrl";
NSString * const kFileName        = @"fileName";

@implementation SFNetReactBridge

RCT_EXPORT_MODULE();

#pragma mark - Bridged methods

RCT_EXPORT_METHOD(sendRequest:(NSDictionary *)argsDict callback:(RCTResponseSenderBlock)callback)
{
    SFRestMethod method = [SFRestRequest sfRestMethodFromHTTPMethod:[argsDict nonNullObjectForKey:kMethodArg]];
    NSString* endPoint = [argsDict nonNullObjectForKey:kEndPointArg];
    NSString* path = [argsDict nonNullObjectForKey:kPathArg];
    NSDictionary* queryParams = [argsDict nonNullObjectForKey:kQueryParams];
    NSDictionary* headerParams = [argsDict nonNullObjectForKey:kHeaderParams];
    NSDictionary* fileParams = [argsDict nonNullObjectForKey:kfileParams];
    SFRestRequest* request = nil;
    
    // Sets HTTP body explicitly for a POST, PATCH or PUT request.
    if (method == SFRestMethodPOST || method == SFRestMethodPATCH || method == SFRestMethodPUT) {
        request = [SFRestRequest requestWithMethod:method path:path queryParams:nil];
        [request setCustomRequestBodyDictionary:queryParams contentType:@"application/json"];
    } else {
        request = [SFRestRequest requestWithMethod:method path:path queryParams:queryParams];
    }

    // Custom headers
    [request setCustomHeaders:headerParams];
    if (endPoint) {
        [request setEndpoint:endPoint];
    }
    
    // Files post
    if (fileParams) {

        // File params expected to be of the form:
        // {<fileParamNameInPost>: {fileMimeType:<someMimeType>, fileUrl:<fileUrl>, fileName:<fileNameForPost>}}
        for (NSString* fileParamName in fileParams) {
            NSDictionary* fileParam = fileParams[fileParamName];
            NSString* fileMimeType = [fileParam nonNullObjectForKey:kFileMimeType];
            NSString* fileUrl = [fileParam nonNullObjectForKey:kFileUrl];
            NSString* fileName = [fileParam nonNullObjectForKey:kFileName];
            NSData* fileData = [NSData dataWithContentsOfURL:[NSURL URLWithString:fileUrl]];
            [request addPostFileData:fileData description:nil fileName:fileName mimeType:fileMimeType];
        }
    }
    [[SFRestAPI sharedInstance] sendRESTRequest:request
                                      failBlock:^(NSError *e) {
                                          callback(@[RCTMakeError(@"sendRequest failed", e, nil)]);
                                      }
                                  completeBlock:^(id response) {
                                      callback(@[[NSNull null], response == nil ? [NSNull null] : response]);
                                  }
     ];
}

@end
