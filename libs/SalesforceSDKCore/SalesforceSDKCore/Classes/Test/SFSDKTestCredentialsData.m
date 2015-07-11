/*
 Copyright (c) 2014, salesforce.com, inc. All rights reserved.
 
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

#import "SFSDKTestCredentialsData.h"

@interface SFSDKTestCredentialsData ()
{
    NSDictionary *_credentialsDict;
}

@end

@implementation SFSDKTestCredentialsData

- (id)initWithDict:(NSDictionary *)credentialsDict
{
    self = [super init];
    if (self) {
        _credentialsDict = credentialsDict;
    }
    
    return self;
}

- (NSString *)accessToken
{
    return _credentialsDict[@"access_token"];
}

- (NSString *)refreshToken
{
    return _credentialsDict[@"refresh_token"];
}

- (NSString *)identityUrl
{
    return _credentialsDict[@"identity_url"];
}

- (NSString *)instanceUrl
{
    return _credentialsDict[@"instance_url"];
}

- (NSString *)clientId
{
    return _credentialsDict[@"test_client_id"];
}

- (NSString *)redirectUri
{
    return _credentialsDict[@"test_redirect_uri"];
}

- (NSString *)loginHost
{
    return _credentialsDict[@"test_login_domain"];
}

- (NSString *)communityUrl
{
    return _credentialsDict[@"community_url"];
}

@end
