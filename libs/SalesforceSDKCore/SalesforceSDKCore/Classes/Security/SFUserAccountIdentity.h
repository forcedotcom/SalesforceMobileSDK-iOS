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

#import <Foundation/Foundation.h>

@class SFOAuthCredentials;

/**
 Represents the unique identity of a given user account.
 */
@interface SFUserAccountIdentity : NSObject <NSSecureCoding, NSCopying>

/**
 The user ID associated with the account.
 */
@property (nonatomic, copy) NSString *userId;

/**
 The organization ID associated with the account.
 */
@property (nonatomic, copy) NSString *orgId;

/**
 Convenience method to return a new account identity with the given User ID and Org ID.
 @param userId The user ID associated with the identity.
 @param orgId The org ID associated with the identity.
 @return An account identity representing the given User ID and Org ID.
 */
+ (SFUserAccountIdentity *)identityWithUserId:(NSString *)userId orgId:(NSString *)orgId;

/**
 Creates a new account identity object with the given user ID and org ID.
 @param userId The user ID associated with the identity.
 @param orgId The org ID associated with the identity.
 */
- (id)initWithUserId:(NSString *)userId orgId:(NSString *)orgId;

/**
 Compares this identity with another.  Useful for [NSArray sortedArrayUsingSelector:].
 @param otherIdentity The other identity to compare to this one.
 @return NSOrderedAscending if other is greater, NSOrderedDescending if other is less,
 NSOrderedSame if they're equal.
 */
- (NSComparisonResult)compare:(SFUserAccountIdentity *)otherIdentity;

/**
 Compares the user identifying information of the account identity with that in the credentials.
 @param credentials The OAuthCredentials to compare against
 @return BOOL Whether or not the user contained is the same
 */
- (BOOL)matchesCredentials:(SFOAuthCredentials *)credentials;

@end
