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

#import "SFUserAccountManager.h"

@interface SFUserAccountManager ()
{
    NSMutableOrderedSet *_delegates;
}

/** A map of user accounts by user ID
 */
@property (nonatomic, strong) NSMutableDictionary *userAccountMap;

@property (nonatomic, strong) NSString *lastChangedOrgId;
@property (nonatomic, strong) NSString *lastChangedUserId;
@property (nonatomic, strong) NSString *lastChangedCommunityId;

/**
 Executes the given block for each configured delegate.
 @param block The block to execute for each delegate.
 */
- (void)enumerateDelegates:(void (^)(id<SFUserAccountManagerDelegate>))block;

/**
 Updates the login host in app settings, for apps that utilize login host switching from
 the Settings app.
 @param newLoginHost The login host to update.
 */
- (void)updateAppSettingsLoginHost:(NSString *)newLoginHost;

/**
 Creates a user account staged with the given auth credentials.
 @param credentials The OAuth credentials to apply to the user account.
 @return The new user account with the given credentials.
 */
- (SFUserAccount *)createUserAccountWithCredentials:(SFOAuthCredentials *)credentials;

@end
