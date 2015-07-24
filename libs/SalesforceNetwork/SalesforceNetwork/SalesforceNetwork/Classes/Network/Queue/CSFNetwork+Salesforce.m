//
//  CSFNetwork+Salesforce.m
//  SalesforceNetwork
//
//  Created by Michael Nachbaur on 7/23/15.
//  Copyright (c) 2015 salesforce.com. All rights reserved.
//

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
