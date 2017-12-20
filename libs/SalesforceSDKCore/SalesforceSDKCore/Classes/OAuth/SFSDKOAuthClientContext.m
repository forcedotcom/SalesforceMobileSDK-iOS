/*
 SFSDKOAuthClientContext.m
 SalesforceSDKCore
 
 Created by Raj Rao on 7/25/17.
 
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
#import "SFSDKOAuthClientContext.h"
#import "SFOAuthInfo.h"
#import "SFSDKAuthCommand.h"

@interface SFSDKOAuthClientContext()
@property (nonatomic, strong,readwrite) SFOAuthCredentials *credentials;
@property (nonatomic, strong,readwrite) SFOAuthInfo *authInfo;
@property (nonatomic, strong,readwrite) NSError *authError;
@property (nonatomic, strong,readwrite) NSDictionary *callingAppOptions;
@property (nonatomic,copy,readwrite) NSString *userHint;
@property (nonatomic,strong,readwrite) SFSDKAuthCommand *currentCommand;
@end

@implementation SFSDKOAuthClientContext

- (instancetype)initWithAuthType:(SFOAuthType)oauthType {
    if (self = [super init]) {
        self.authInfo = [[SFOAuthInfo alloc] initWithAuthType:oauthType];
        self.callingAppOptions = [[NSDictionary alloc] initWithDictionary:self.callingAppOptions copyItems:YES];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    return self;
}

- (id)mutableCopyWithZone:(NSZone *)zone {
    SFSDKMutableOAuthClientContext *ctx = [[[self class] allocWithZone:zone] init];
    ctx.authError = [self.authError copyWithZone:zone];
    ctx.authInfo = [[SFOAuthInfo allocWithZone:zone] initWithAuthType:self.authInfo.authType];
    ctx.credentials = [self.credentials copyWithZone:zone];
    ctx.userHint = self.userHint;
    ctx.callingAppOptions = [[NSDictionary alloc] initWithDictionary:self.callingAppOptions copyItems:YES];
    return ctx;
}

@end

@implementation SFSDKMutableOAuthClientContext
@dynamic credentials;
@dynamic authError;
@dynamic authInfo;
@dynamic callingAppOptions;
@dynamic userHint;
@end
