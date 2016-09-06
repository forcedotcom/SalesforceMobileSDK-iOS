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

#import "CSFOAuthTokenRefreshOutput.h"
#import "CSFOutput_Internal.h"
#import "CSFDefines.h"
#import "CSFInternalDefines.h"
#import <SalesforceSDKCore/SalesforceSDKCore.h>

@implementation CSFOAuthTokenRefreshOutput

- (instancetype)initWithCoordinator:(SFOAuthCoordinator *)coordinator {
    NSDictionary *credsDict = [self dictionaryFromCoordinator:coordinator];
    return [self initWithJSON:credsDict context:nil];
}

- (id)transformIssuedAtValue:(id)value {
    NSDate *result = nil;
    
    NSNumber *issuedAt = CSFNotNullNumber(value);
    if (issuedAt) {
        result = [NSDate dateWithTimeIntervalSince1970:[issuedAt integerValue]];
    }
    return result;
}

- (id)transformScopeValue:(id)value {
    id result = nil;
    if ([value isKindOfClass:[NSString class]]) {
        return [(NSString*)value componentsSeparatedByString:@" "];
    }
    return result;
}

- (NSString*)description {
    return [NSString stringWithFormat:@"<CSFOAuthTokenRefreshOutput: %p, tokenType=%@, issuedAt=%@, scope=(%@), instanceUrl=%@>",
            self, self.tokenType, self.issuedAt, [self.scope componentsJoinedByString:@" "], self.instanceUrl];
}

- (NSString*)indexedKey {
    return @"idUrl";
}

- (id)indexedValue {
    return self.idUrl;
}

- (NSDictionary *)dictionaryFromCoordinator:(SFOAuthCoordinator *)coordinator {
    if (coordinator == nil || coordinator.credentials == nil) return nil;
    
    SFOAuthCredentials *credentials = coordinator.credentials;
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"access_token"] = credentials.accessToken;
    dict[@"id"] = [credentials.identityUrl absoluteString];
    dict[@"instance_url"] = [credentials.instanceUrl absoluteString];
    NSNumber *issuedAtTimeInterval = @( [credentials.issuedAt timeIntervalSince1970] );
    dict[@"issued_at"] = @( [issuedAtTimeInterval unsignedIntegerValue] );
    return dict;
}

@end
