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
static NSString * const kReturnBinary    = @"returnBinary";
static NSString * const kEncodedBody     = @"encodedBody";
static NSString * const kContentType     = @"contentType";
static NSString * const kHttpContentType = @"content-type";

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
    NSMutableDictionary<NSString*, NSString*>* headerParams = [argsDict nonNullObjectForKey:kHeaderParams];
    NSDictionary<NSString*, NSDictionary*>* fileParams = [argsDict nonNullObjectForKey:kfileParams];
    BOOL returnBinary = [argsDict nonNullObjectForKey:kReturnBinary] != nil && [[argsDict nonNullObjectForKey:kReturnBinary] boolValue];
    SFRestRequest* request = nil;

    // Sets HTTP body explicitly for a POST, PATCH or PUT request.
    if (method == SFRestMethodPOST || method == SFRestMethodPATCH || method == SFRestMethodPUT) {
        request = [SFRestRequest requestWithMethod:method path:path queryParams:nil];
        [request setCustomRequestBodyDictionary:queryParams contentType:@"application/json"];
    } else {
        request = [SFRestRequest requestWithMethod:method path:path queryParams:queryParams];
    }

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
            [request addPostFileData:fileData paramName:fileParamName description:nil fileName:fileName mimeType:fileMimeType];
        }
    }
    
    // Disable parsing for binary request
    if (returnBinary) {
        request.parseResponse = NO;
    }
    
    __weak typeof(self) weakSelf = self;
    [[SFRestAPI sharedInstance] sendRESTRequest:request
                                      failBlock:^(NSError *e, NSURLResponse *rawResponse) {
                                          __strong typeof(self) strongSelf = weakSelf;
                                          CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:e.localizedDescription];
                                          [strongSelf.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                                      }
                                  completeBlock:^(id response, NSURLResponse *rawResponse) {
                                      __strong typeof(self) strongSelf = weakSelf;
                                      CDVPluginResult *pluginResult = nil;
                                      // Binary response
                                      if (returnBinary) {
                                          NSDictionary* result = @{
                                                                   kEncodedBody:[((NSData*) response) base64EncodedStringWithOptions:0],
                                                                   kContentType:((NSHTTPURLResponse*) rawResponse).allHeaderFields[kHttpContentType]
                                                                   };
                                          pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:result];
                                        
                                      }
                                      // Some response
                                      else if (response) {
                                          if ([response isKindOfClass:[NSDictionary class]]) {
                                              pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:response];
                                          } else if ([response isKindOfClass:[NSArray class]]) {
                                              pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:response];
                                          } else {
                                              NSData* responseAsData = response;
                                              NSStringEncoding encodingType = rawResponse.textEncodingName == nil ? NSUTF8StringEncoding :  CFStringConvertEncodingToNSStringEncoding(CFStringConvertIANACharSetNameToEncoding((CFStringRef)rawResponse.textEncodingName));
                                              NSString* responseAsString = [[NSString alloc] initWithData:responseAsData encoding:encodingType];
                                              pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:responseAsString];
                                          }
                                      }
                                      // No response
                                      else {
                                          pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
                                      }
                                      
                                      [strongSelf.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                                  }
     ];
}

@end
