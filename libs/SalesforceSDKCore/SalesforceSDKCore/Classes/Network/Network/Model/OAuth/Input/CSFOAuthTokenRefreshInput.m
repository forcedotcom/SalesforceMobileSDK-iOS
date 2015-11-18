/*
 Copyright (c) 2015, salesforce.com, inc. All rights reserved.
 
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

#import "CSFOAuthTokenRefreshInput.h"

@implementation CSFOAuthTokenRefreshInput

- (NSString*)description {
    return [NSString stringWithFormat:@"<CSFOAuthTokenRefreshInput: %p>", self];
}

- (NSDictionary*)JSONDictionary {
    NSMutableDictionary *info = [NSMutableDictionary dictionaryWithDictionary:@{ @"format": @"json",
                                                                                 @"grant_type": @"refresh_token" }];
    if (self.redirectUri)
        info[@"redirect_uri"] = self.redirectUri;

    if (self.clientId)
        info[@"client_id"] = self.clientId;
    
    if (self.refreshToken)
        info[@"refresh_token"] = self.refreshToken;

    return info;
}

- (void)encodeWithCoder:(NSCoder*)encoder {
    [super encodeWithCoder:encoder];
    [encoder encodeObject:_redirectUri forKey:@"redirectUri"];
    [encoder encodeObject:_instanceUrl forKey:@"instanceUrl"];
    [encoder encodeObject:_clientId forKey:@"clientId"];
    [encoder encodeObject:_refreshToken forKey:@"refreshToken"];
}

- (id)initWithCoder:(NSCoder*)decoder {
    self = [super initWithCoder:decoder];
    if (self) {
        _redirectUri = [decoder decodeObjectOfClass:[NSString class] forKey:@"redirectUri"];
        _instanceUrl = [decoder decodeObjectOfClass:[NSString class] forKey:@"instanceUrl"];
        _clientId = [decoder decodeObjectOfClass:[NSString class] forKey:@"clientId"];
        _refreshToken = [decoder decodeObjectOfClass:[NSString class] forKey:@"refreshToken"];
    }
    return self;
}

- (NSUInteger)hash {
    NSUInteger result = 17;
    result ^= [self.redirectUri hash] + result * 37;
    result ^= [self.instanceUrl hash] + result * 37;
    result ^= [self.clientId hash] + result * 37;
    result ^= [self.refreshToken hash] + result * 37;
    return result;
}

- (BOOL)isEqualToInput:(CSFInput*)model {
    if (self == model)
        return YES;
    
    if (![model isKindOfClass:[CSFOAuthTokenRefreshInput class]])
        return NO;
    
    CSFOAuthTokenRefreshInput *localModel = (CSFOAuthTokenRefreshInput*)model;
    if (self.redirectUri != localModel.redirectUri && ![self.redirectUri isEqual:localModel.redirectUri])
        return NO;
    if (self.instanceUrl != localModel.instanceUrl && ![self.instanceUrl isEqual:localModel.instanceUrl])
        return NO;
    if (self.clientId != localModel.clientId && ![self.clientId isEqualToString:localModel.clientId])
        return NO;
    if (self.refreshToken != localModel.refreshToken && ![self.refreshToken isEqualToString:localModel.refreshToken])
        return NO;
    
    return YES;
}

@end
