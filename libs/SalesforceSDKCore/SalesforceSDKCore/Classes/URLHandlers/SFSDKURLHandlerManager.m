/*
 SFSDKURLHandlerManager.m
 SalesforceSDKCore
 
 Created by Raj Rao on 8/28/17.
 
 Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.
 
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

#import "SFSDKURLHandler.h"
#import "SFSDKURLHandlerManager.h"
#import "SFSDKAdvancedAuthURLHandler.h"
#import "SFSDKIDPRequestHandler.h"
#import "SFSDKIDPResponseHandler.h"
#import "SFSDKIDPErrorHandler.h"
#import "SFSDKURLHandler.h"
#import "SFSDKIDPInitiatedAuthRequestHandler.h"
@interface SFSDKURLHandlerManager() {
    NSMutableArray<id <SFSDKURLHandler>> *handlerList;
}

@end

@implementation SFSDKURLHandlerManager

- (instancetype) init {
    self = [super init];
    if (self) {
        handlerList = [NSMutableArray new];
        [handlerList addObject:[[SFSDKAdvancedAuthURLHandler  alloc] init]];
        [handlerList addObject:[[SFSDKIDPRequestHandler  alloc] init]];
        [handlerList addObject:[[SFSDKIDPResponseHandler  alloc] init]];
        [handlerList addObject:[[SFSDKIDPErrorHandler  alloc] init]];
        [handlerList addObject:[[SFSDKIDPInitiatedAuthRequestHandler alloc] init]];
    }
    return self;
}

- (BOOL)canHandleRequest:(NSURL *)url options:(NSDictionary *)options {

     __block BOOL result = NO;
    [handlerList enumerateObjectsUsingBlock:^(id <SFSDKURLHandler> handler, NSUInteger idx, BOOL *stop) {
        result = [handler canHandleRequest:url options:options];
        *stop = result;
    }];

    return result;
}

- (BOOL)processRequest:(NSURL *)url options:(NSDictionary *)options {

    __block BOOL result = NO;

    [handlerList enumerateObjectsUsingBlock:^(id <SFSDKURLHandler> handler, NSUInteger idx, BOOL *stop) {
        if ([handler canHandleRequest:url options:options]) {
            result = [handler processRequest:url options:options];
        }
        *stop = result;
    }];

    return result;
}

+ (instancetype)sharedInstance {
    static dispatch_once_t pred;
    static SFSDKURLHandlerManager *handlerManager = nil;
    dispatch_once(&pred, ^{
        handlerManager = [[self alloc] init];
    });
    return handlerManager;
}

@end
