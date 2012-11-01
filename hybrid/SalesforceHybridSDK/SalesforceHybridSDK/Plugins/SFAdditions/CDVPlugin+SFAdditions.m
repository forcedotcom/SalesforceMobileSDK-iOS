/*
 Copyright (c) 2012, salesforce.com, inc. All rights reserved.
 
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

#import "CDVPlugin+SFAdditions.h"

NSString * const kCallbackIdPrefix = @"com.salesforce.";
NSString * const kPluginSDKVersion = @"pluginSDKVersion";

@implementation CDVPlugin (SFAdditions)

#pragma mark - Cordova plugin support

- (void)writeSuccessResultToJsRealm:(CDVPluginResult*)result callbackId:(NSString*)callbackId
{
    NSString *jsString = [result toSuccessCallbackString:callbackId];
    
	if (jsString){
		[self writeJavascript:jsString];
    }
}

- (void)writeErrorResultToJsRealm:(CDVPluginResult*)result callbackId:(NSString*)callbackId
{
    NSString *jsString = [result toErrorCallbackString:callbackId];
	if (jsString){
		[self writeJavascript:jsString];
    }
}

- (void)writeCommandOKResultToJsRealm:(NSString*)callbackId
{
    [self writeSuccessResultToJsRealm:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK] callbackId:callbackId];
}

- (void)writeSuccessArrayToJsRealm:(NSArray*)array callbackId:(NSString*)callbackId
{
    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:array];
    [self writeSuccessResultToJsRealm:result callbackId:callbackId];
}


- (void)writeSuccessDictToJsRealm:(NSDictionary*)dict callbackId:(NSString*)callbackId
{
    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dict];
    [self writeSuccessResultToJsRealm:result callbackId:callbackId];
}

#pragma mark - Callback id extraction

- (NSString*)getCallbackId:(NSString*)action withArguments:(NSArray*)arguments
{
    NSString* callbackId = nil;
    if ([arguments count] >= 1) {
        NSObject* elt = [arguments objectAtIndex:0];
        if ([elt isKindOfClass:[NSString class]] && [(NSString*) elt hasPrefix:kCallbackIdPrefix]) {
            callbackId = (NSString*) elt;
        }
    }
    
    NSLog(@"%@ callbackId:%@ ", action, callbackId);
    return callbackId;
}

#pragma mark - Versioning support

-(NSString*)getVersion:(NSString*)action withArguments:(NSMutableArray *)arguments
{
    NSString* jsVersionStr = nil;
    if ([arguments count] >= 2) {
        NSObject* elt = [arguments objectAtIndex:1];
        if ([elt isKindOfClass:[NSString class]] && [(NSString*) elt hasPrefix:kPluginSDKVersion]) {
            jsVersionStr = [(NSString*) elt substringFromIndex:1 + [kPluginSDKVersion length]];
        }
    }
    
    NSLog(@"%@ jsVersion:%@ ", action, (jsVersionStr ? jsVersionStr : @""));
    return jsVersionStr;
}


@end
