/*
 SFNetworkPlugin.m
 SalesforceHybridSDK
 
 Created by Bharath Hariharan on 9/14/16.
 
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

#import "SFNetworkPlugin.h"
#import "CDVPlugin+SFAdditions.h"
#import <SalesforceSDKCore/NSDictionary+SFAdditions.h>
#import <SalesforceSDKCore/SFRestAPI+Blocks.h>

// NOTE: must match value in Cordova's config.xml file.
NSString * const kSFNetworkPluginIdentifier = @"com.salesforce.network";

// Private constants.
NSString * const kMethodArg       = @"method";
NSString * const kPathArg         = @"path";
NSString * const kEndPointArg     = @"endPoint";
NSString * const kQueryParams     = @"queryParams";
NSString * const kHeaderParams    = @"headerParams";
NSString * const kfileParams      = @"fileParams";
NSString * const kFileMimeType    = @"fileMimeType";
NSString * const kFileUrl         = @"fileUrl";
NSString * const kFileName        = @"fileName";
NSString * const kPatchMethod     = @"PATCH";

@implementation SFNetworkPlugin

- (void) pgSendRequest:(CDVInvokedUrlCommand *) command
{
    NSDictionary *argsDict = [self getArgument:command.arguments atIndex:0];
    SFRestMethod method = [SFRestRequest sfRestMethodFromHTTPMethod:[argsDict nonNullObjectForKey:kMethodArg]];
    NSString* endPoint = [argsDict nonNullObjectForKey:kEndPointArg];
    NSString* path = [argsDict nonNullObjectForKey:kPathArg];

    /*
     * Android's network library has a limitation that it does not support
     * PATCH requests. However, Salesforce REST API does not allow POST for
     * updates, it only allows PATCH. Hence, we work around the issue on
     * Android by passing in method name PATCH as a URL parameter. However,
     * we don't need this on iOS, since we can directly make a PATCH request.
     */
    if ([path containsString:kPatchMethod]) {
        method = SFRestMethodPATCH;
    }
    NSDictionary* queryParams = [[NSDictionary alloc] init];
    id queryParamsObj = [argsDict nonNullObjectForKey:kQueryParams];

    /*
     * Query params are NSDictionary for GET and encoded JSON in NSString
     * for POST. These checks ensure that both cases are handled properly.
     */
    if ([queryParamsObj isKindOfClass:[NSString class]]) {
        NSData* queryParamsData = [queryParamsObj dataUsingEncoding:NSUTF8StringEncoding];
        queryParams = [NSJSONSerialization JSONObjectWithData:queryParamsData options:0 error:nil];
    } else {
        queryParams = queryParamsObj;
    }
    NSDictionary* headerParams = [argsDict nonNullObjectForKey:kHeaderParams];
    NSDictionary* fileParams = [argsDict nonNullObjectForKey:kfileParams];
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
        for (NSString* fileParamName in fileParams) {
            NSDictionary* fileParam = fileParams[fileParamName];
            NSString* fileMimeType = [fileParam nonNullObjectForKey:kFileMimeType];
            NSString* fileUrl = [fileParam nonNullObjectForKey:kFileUrl];
            NSString* fileName = [fileParam nonNullObjectForKey:kFileName];
            NSData* fileData = [NSData dataWithContentsOfURL:[NSURL URLWithString:fileUrl]];
            [request addPostFileData:fileData paramName:fileParamName fileName:fileName mimeType:fileMimeType];
        }
    }
    [[SFRestAPI sharedInstance] sendRESTRequest:request
                                      failBlock:^(NSError *e) {
                                          CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:e.localizedDescription];
                                          [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                                      }
                                  completeBlock:^(id response) {
                                      CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:response];
                                      [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                                  }
     ];
}

@end
