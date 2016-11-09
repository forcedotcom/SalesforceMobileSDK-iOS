/*
 SFNetworkPlugin.m
 SalesforceHybridSDK
 
 Created by Bharath Hariharan on 9/14/16.
 
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

#import "SFNetworkPlugin.h"
#import "CDVPlugin+SFAdditions.h"
#import <SalesforceSDKCore/NSDictionary+SFAdditions.h>
#import <SalesforceSDKCore/SFRestAPI+Blocks.h>
#import <SalesforceSDKCore/SFJsonUtils.h>

// NOTE: must match value in Cordova's config.xml file.
NSString * const kSFNetworkPluginIdentifier = @"com.salesforce.network";

// Private constants.
static NSString * const kMethodArg       = @"method";
static NSString * const kPathArg         = @"path";
static NSString * const kEndPointArg     = @"endPoint";
static NSString * const kQueryParams     = @"queryParams";
static NSString * const kHeaderParams    = @"headerParams";
static NSString * const kfileParams      = @"fileParams";
static NSString * const kFileMimeType    = @"fileMimeType";
static NSString * const kFileUrl         = @"fileUrl";
static NSString * const kFileName        = @"fileName";

@implementation SFNetworkPlugin

- (void) pgSendRequest:(CDVInvokedUrlCommand *) command
{
    NSDictionary *argsDict = [self getArgument:command.arguments atIndex:0];
    SFRestMethod method = [SFRestRequest sfRestMethodFromHTTPMethod:[argsDict nonNullObjectForKey:kMethodArg]];
    NSString* endPoint = [argsDict nonNullObjectForKey:kEndPointArg];
    NSString* path = [argsDict nonNullObjectForKey:kPathArg];

    NSDictionary* queryParams = [[NSDictionary alloc] init];
    id queryParamsObj = [argsDict nonNullObjectForKey:kQueryParams];

    /*
     * Query params are NSDictionary for GET and encoded JSON in NSString
     * for POST. These checks ensure that both cases are handled properly.
     */
    if ([queryParamsObj isKindOfClass:[NSString class]]) {
        queryParams = [SFJsonUtils objectFromJSONString:queryParamsObj];
    } else {
        queryParams = queryParamsObj;
    }
    NSDictionary<NSString*, NSString*>* headerParams = [argsDict nonNullObjectForKey:kHeaderParams];
    NSDictionary<NSString*, NSDictionary*>* fileParams = [argsDict nonNullObjectForKey:kfileParams];
    SFRestRequest* request = [SFRestRequest requestWithMethod:method path:path queryParams:queryParams];

    // Adds custom headers, if any.
    [request setCustomHeaders:headerParams];
    if (endPoint) {
        [request setEndpoint:endPoint];
    }

    // Sets body for a file POST request.
    if (fileParams) {

        /*
         * File params expected to be of the form:
         * {<fileParamNameInPost>: {fileMimeType:<someMimeType>, fileUrl:<fileUrl>, fileName:<fileNameForPost>}}.
         */
        NSArray<NSString*>* fileParamKeys = fileParams.allKeys;
        for (NSString* fileParamName in fileParamKeys) {
            NSDictionary* fileParam = fileParams[fileParamName];
            NSString* fileMimeType = [fileParam nonNullObjectForKey:kFileMimeType];
            NSString* fileUrl = [fileParam nonNullObjectForKey:kFileUrl];
            NSString* fileName = [fileParam nonNullObjectForKey:kFileName];
            NSData* fileData = [NSData dataWithContentsOfURL:[NSURL URLWithString:fileUrl]];
            [request addPostFileData:fileData paramName:fileParamName fileName:fileName mimeType:fileMimeType];
        }
    }
    __weak typeof(self) weakSelf = self;
    [[SFRestAPI sharedInstance] sendRESTRequest:request
                                      failBlock:^(NSError *e) {
                                          __strong typeof(self) strongSelf = weakSelf;
                                          CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:e.localizedDescription];
                                          [strongSelf.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                                      }
                                  completeBlock:^(id response) {
                                      __strong typeof(self) strongSelf = weakSelf;
                                      CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:response];
                                      [strongSelf.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                                  }
     ];
}

@end
