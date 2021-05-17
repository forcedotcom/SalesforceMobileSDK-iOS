/*
 Copyright (c) 2011-present, salesforce.com, inc. All rights reserved.
 
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

#import "SFOAuthCredentials.h"
#import "SFEncryptionKey.h"

typedef NS_ENUM(NSUInteger, SFOAuthCredsEncryptionType) {
    kSFOAuthCredsEncryptionTypeNotSet,
    kSFOAuthCredsEncryptionTypeMac,
    kSFOAuthCredsEncryptionTypeIdForVendor,
    kSFOAuthCredsEncryptionTypeBaseAppId,
    kSFOAuthCredsEncryptionTypeKeyStore
};

extern NSString * _Nonnull const kSFOAuthEncryptionTypeKey;
extern NSString * _Nonnull const kSFOAuthServiceAccess;
extern NSString * _Nonnull const kSFOAuthServiceRefresh;
extern NSString * _Nonnull const kSFOAuthServiceActivation;

extern NSException * _Nullable SFOAuthInvalidIdentifierException(void);

@interface SFOAuthCredentials ()
@property (nonatomic, readwrite, nullable) NSString *protocol;
@property (nonatomic, readwrite, nullable) NSString *domain;
@property (nonatomic,readwrite, nonnull) NSString *identifier;
@property (nonatomic, readwrite, nullable) NSString *clientId;
@property (nonatomic, readwrite, nullable) NSString *redirectUri;
@property (nonatomic, readwrite, nullable) NSString *jwt;
@property (nonatomic, readwrite, nullable) NSString *refreshToken;
@property (nonatomic, readwrite, nullable) NSString *accessToken;
@property (nonatomic, readwrite, nullable) NSString *organizationId;
@property (nonatomic, readwrite, nullable) NSURL *instanceUrl;
@property (nonatomic, readwrite, nullable) NSString *communityId;
@property (nonatomic, readwrite, nullable) NSURL *communityUrl;
@property (nonatomic, readwrite, nullable) NSDate *issuedAt;
@property (nonatomic, readwrite, nullable) NSURL *identityUrl;
@property (nonatomic, readwrite, nullable) NSURL *apiUrl;
@property (nonatomic, readwrite, nullable) NSString *userId;
@property (nonatomic, readwrite, strong, nullable) NSDictionary * additionalOAuthFields;
@property (nonatomic, readwrite, nullable) NSString *challengeString;
@property (nonatomic, readwrite, nullable) NSString *authCode;
@property (nonatomic, readwrite, nullable) NSMutableDictionary * credentialsChangeSet;
@property (nonatomic, readwrite, nullable) NSString *lightningDomain;
@property (nonatomic, readwrite, nullable) NSString *lightningSid;
@property (nonatomic, readwrite, nullable) NSString *vfDomain;
@property (nonatomic, readwrite, nullable) NSString *vfSid;
@property (nonatomic, readwrite, nullable) NSString *contentDomain;
@property (nonatomic, readwrite, nullable) NSString *contentSid;
@property (nonatomic, readwrite, nullable) NSString *csrfToken;

- (void)setPropertyForKey:(NSString *_Nonnull) key withValue:(id _Nullable ) newValue;

- (BOOL)hasPropertyValueChangedForKey:(NSString *_Nullable) key;

/** Reset changes to credentials, called at the end of auth flow.
 */
- (void)resetCredentialsChangeSet;
@end


