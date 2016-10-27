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

#import "CSFNetwork+Salesforce.h"

@implementation CSFNetwork (Salesforce)

- (NSString*)defaultConnectCommunityId {
    return _defaultConnectCommunityId;
}

- (void)setDefaultConnectCommunityId:(NSString *)defaultConnectCommunityId {
    if (_defaultConnectCommunityId != defaultConnectCommunityId) {
        _defaultConnectCommunityId = [defaultConnectCommunityId copy];
    }
}

- (void)setupSalesforceObserver {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(userAccountManagerDidChangeCurrentUser:)
                                                 name:SFUserAccountManagerDidChangeCurrentUserNotification
                                               object:nil];
}

#pragma mark SFAuthenticationManagerDelegate

- (void)userAccountManagerDidChangeCurrentUser:(NSNotification*)notification {
    SFUserAccountManager *accountManager = (SFUserAccountManager*)notification.object;
    if ([accountManager isKindOfClass:[SFUserAccountManager class]]) {
        if ([accountManager.currentUserIdentity isEqual:self.account.accountIdentity] &&
            ![accountManager.currentCommunityId isEqualToString:self.defaultConnectCommunityId])
        {
            self.defaultConnectCommunityId = accountManager.currentCommunityId;
        }
    }
}

@end
