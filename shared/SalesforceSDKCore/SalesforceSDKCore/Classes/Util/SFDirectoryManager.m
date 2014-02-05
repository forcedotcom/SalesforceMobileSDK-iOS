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

+ (BOOL)ensureDirectoryExists:(NSString*)directory {
    NSFileManager *manager = [NSFileManager defaultManager];
    if (![manager fileExistsAtPath:directory]) {
        NSError *error = nil;
        [manager createDirectoryAtPath:directory
           withIntermediateDirectories:YES
                            attributes:[NSDictionary dictionaryWithObjectsAndKeys:NSFileProtectionComplete, NSFileProtectionKey, nil]
                                 error:&error];
        if (error) {
            [self log:SFLogLevelError format:@"Error creating directory path: %@", [error localizedDescription]];
            return NO;
        } else {
            return YES;
        }
    } else {
        return YES;
    }
}

- (NSString*)directoryForOrg:(NSString*)orgId user:(NSString*)userId community:(NSString*)communityId type:(NSSearchPathDirectory)type components:(NSArray*)components {
    NSString *directory = [NSSearchPathForDirectoriesInDomains(type, NSUserDomainMask, YES) firstObject];
    if (nil != orgId && nil != userId) {
        directory = [directory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%@", orgId, userId]];
        if (nil == communityId) {
            directory = [directory stringByAppendingPathComponent:@"internal"];
        } else {
            directory = [directory stringByAppendingPathComponent:communityId];
        }
    }
    
    for (NSString *component in components) {
        directory = [directory stringByAppendingPathComponent:component];
    }
    
    return directory;
}

- (NSString*)directoryForUser:(SFUserAccount*)account type:(NSSearchPathDirectory)type components:(NSArray*)components {
    if (account) {
        return [self directoryForOrg:account.organizationId user:account.credentials.identifier community:account.communityId type:type components:components];
    } else {
        return [self directoryForOrg:nil user:nil community:nil type:type components:components];
    }
}

- (NSString*)directoryOfCurrentUserForType:(NSSearchPathDirectory)type components:(NSArray*)components {
    SFUserAccount *account = [SFUserAccountManager sharedInstance].currentUser;
    NSAssert(nil != account, @"Must have a current user");
    return [self directoryForUser:account type:type components:components];
}

@end
