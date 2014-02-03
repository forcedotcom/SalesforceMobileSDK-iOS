//
//  SFDirectoryManager.m
//  SalesforceSDKCore
//
//  Created by Jean Bovet on 1/24/14.
//  Copyright (c) 2014 salesforce.com. All rights reserved.
//

#import "SFDirectoryManager.h"
#import "SFUserAccountManager.h"
#import "SFUserAccount.h"

@implementation SFDirectoryManager

+ (instancetype)sharedManager {
    static dispatch_once_t pred;
    static SFDirectoryManager *manager = nil;
    dispatch_once(&pred, ^{
		manager = [[self alloc] init];
	});
    return manager;
}

- (NSString*)directoryForOrg:(NSString*)orgId user:(NSString*)userId community:(NSString*)communityId type:(SFDirectoryType)type {
    NSString *rootDirectory;
    switch (type) {
        case SFDirectoryTypeDocuments:
            rootDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
            break;
            
        case SFDirectoryTypeCaches:
            rootDirectory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
            break;
    }

    if (nil == orgId || nil == userId) {
        return rootDirectory;
    }
    
    NSString *directory = [rootDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%@", orgId, userId]];
    if (nil == communityId) {
        return [directory stringByAppendingPathComponent:@"internal"];
    } else {
        return [directory stringByAppendingPathComponent:communityId];
    }
}

- (NSString*)directoryForUser:(SFUserAccount*)account type:(SFDirectoryType)type {
    if (account) {
        return [self directoryForOrg:account.organizationId user:account.credentials.identifier community:account.communityId type:type];
    } else {
        return [self directoryForOrg:nil user:nil community:nil type:type];
    }
}

- (NSString*)directoryOfCurrentUserForType:(SFDirectoryType)type {
    SFUserAccount *account = [SFUserAccountManager sharedInstance].currentUser;
    NSAssert(nil != account, @"Must have a current user");
    return [self directoryForUser:account type:type];
}

@end
