/*
 Copyright (c) 2012-present, salesforce.com, inc. All rights reserved.
 
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

#import <Foundation/Foundation.h>

/**
 The type of authentication being attempted, in a given OAuth coordinator cycle.
 */
typedef NS_ENUM(NSUInteger, SFOAuthType) {
    SFOAuthTypeUnknown = 0,
    SFOAuthTypeUserAgent,
    SFOAuthTypeRefresh,
    SFOAuthTypeAdvancedBrowser,
    SFOAuthTypeJwtTokenExchange
};

/**
 Data class containing members denoting state information for an OAuth coordinator authentication
 cycle.
 */
@interface SFOAuthInfo : NSObject

/**
 The type of authentication being performed.
 */
@property (nonatomic, readonly, assign) SFOAuthType authType;

/**
 The string description of the auth type.
 */
@property (nonatomic, readonly) NSString *authTypeDescription;

/**
 Creates a new instance with the given auth type.
 @param authType The type of authentication being performed.
 */
- (id)initWithAuthType:(SFOAuthType)authType;

@end
