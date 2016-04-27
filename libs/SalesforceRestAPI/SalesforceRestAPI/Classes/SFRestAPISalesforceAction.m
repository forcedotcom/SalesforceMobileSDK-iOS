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

#import "SFRestAPISalesforceAction.h"
#import <SalesforceNetwork/CSFDefines.h>

@implementation SFRestAPISalesforceAction

- (instancetype)initWithResponseBlock:(CSFActionResponseBlock)responseBlock {
    self = [super initWithResponseBlock:responseBlock];
    if (self) {
        _parseResponse = YES;
    }
    return self;
}

- (id)contentFromData:(NSData *)data fromResponse:(NSHTTPURLResponse *)response error:(NSError *__autoreleasing *)error {
    
    // Parse if desired
    if (_parseResponse) {
        return [super contentFromData:data fromResponse:response error:error];
    }
    
    // Otherwise, do some basic error detection, as we don't otherwise know the content disposition.
    if (response.statusCode < 200 || response.statusCode > 299) {
        if (error) {
            *error = [NSError errorWithDomain:CSFNetworkErrorDomain
                                                code:response.statusCode
                                            userInfo:@{ NSLocalizedDescriptionKey:[NSString stringWithFormat:@"HTTP %ld for %@ %@", (long)response.statusCode, self.method, self.verb],
                                                        CSFNetworkErrorActionKey: self }];
        }
    }
    
    return data;
}

- (BOOL)isEqualToAction:(CSFAction *)action {
    
    // SFRestAPI functionality doesn't have the expectation of duplicate request handling,
    // squashing, etc., that's driven by this equality check in the new Network SDK.  We'll
    // only check for true object equality here.
    
    return (self == action);
}

@end
