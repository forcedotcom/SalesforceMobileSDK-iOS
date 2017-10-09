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

#import "SFDirectoryManager.h"
#import "SFUserAccountManager.h"
#import "SFUserAccount.h"
#import "SFFileProtectionHelper.h"
#import <SalesforceAnalytics/SFSDKDatasharingHelper.h>

static NSString * const kDefaultOrgName = @"org";
static NSString * const kDefaultCommunityName = @"internal";
static NSString * const kSharedLibraryLocation = @"Library";
static NSString * const kFilesSharedKey = @"filesShared";

@implementation SFDirectoryManager

+ (instancetype)sharedManager {
    static dispatch_once_t pred;
    static SFDirectoryManager *manager = nil;
    dispatch_once(&pred, ^{
		manager = [[self alloc] init];
	});
    return manager;
}

- (id)init {
    self = [super init];
    if (self) {
        [self migrateFiles];
    }
    return self;
}

+ (BOOL)ensureDirectoryExists:(NSString*)directory error:(NSError**)error {
    NSFileManager *manager = [[NSFileManager alloc] init];
    if (directory && ![manager fileExistsAtPath:directory]) {
        return [manager createDirectoryAtPath:directory
                  withIntermediateDirectories:YES
                                   attributes:@{NSFileProtectionKey: [SFFileProtectionHelper fileProtectionForPath:directory]}
                                        error:error];
    } else {
        return YES;
    }
}

+ (NSString*)safeStringForDiskRepresentation:(NSString*)candidate {
    NSCharacterSet *invalidCharacters = [NSCharacterSet characterSetWithCharactersInString:@"/\\?%*|\"<>:@"];
    return [[candidate componentsSeparatedByCharactersInSet:invalidCharacters] componentsJoinedByString:@"_"];
}

- (NSString*)directoryForOrg:(NSString*)orgId user:(NSString*)userId community:(NSString*)communityId type:(NSSearchPathDirectory)type components:(NSArray*)components {
    NSString *directory;
    
    if ([SFSDKDatasharingHelper sharedInstance].appGroupEnabled){
        NSURL *sharedURL = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:[SFSDKDatasharingHelper sharedInstance].appGroupName];
        directory = [sharedURL path];
        directory = [directory stringByAppendingPathComponent:[SFSDKDatasharingHelper sharedInstance].appGroupName];
        if(type == NSLibraryDirectory)
            directory = [directory stringByAppendingPathComponent:kSharedLibraryLocation];
    } else {
        NSArray *directories = NSSearchPathForDirectoriesInDomains(type, NSUserDomainMask, YES);
        if (directories.count > 0) {
            directory = [directories[0] stringByAppendingPathComponent:[NSBundle mainBundle].bundleIdentifier];
        }
    }
    
    if (directory) {
        if (orgId) {
            directory = [directory stringByAppendingPathComponent:[[self class] safeStringForDiskRepresentation:orgId]];
            if (userId) {
                directory = [directory stringByAppendingPathComponent:[[self class] safeStringForDiskRepresentation:userId]];
                if (communityId) {
                    directory = [directory stringByAppendingPathComponent:[[self class] safeStringForDiskRepresentation:communityId]];
                }
            }
        }
        
        for (NSString *component in components) {
            directory = [directory stringByAppendingPathComponent:component];
        }
        
        return directory;
    } else {
        return nil;
    }
}

- (NSString*)directoryForUser:(SFUserAccount *)user scope:(SFUserAccountScope)scope type:(NSSearchPathDirectory)type components:(NSArray *)components {
    if (nil == user.credentials.organizationId && scope != SFUserAccountScopeGlobal) {
        // do nothing
        return nil;
    }
    switch (scope) {
        case SFUserAccountScopeGlobal:
            return [self directoryForOrg:nil user:nil community:nil type:type components:components];
            
        case SFUserAccountScopeOrg:
            if (!user.credentials.organizationId) {
                [SFSDKCoreLogger w:[self class] format:@"Credentials missing for user"];
                return nil;
            }
            return [self directoryForOrg:user.credentials.organizationId user:nil community:nil type:type components:components];
            
        case SFUserAccountScopeUser:
            if (!user.credentials.organizationId || !user.credentials.userId) {
                [SFSDKCoreLogger w:[self class] format:@"Credentials missing for user"];
                return nil;
            }
            return [self directoryForOrg:user.credentials.organizationId user:user.credentials.userId community:nil type:type components:components];
            
        case SFUserAccountScopeCommunity:
            if (!user.credentials.organizationId || !user.credentials.userId) {
                [SFSDKCoreLogger w:[self class] format:@"Credentials missing for user"];
                return nil;
            }
            // Note: if the user communityId is nil, we use the default (internal) name for it.
            return [self directoryForOrg:user.credentials.organizationId user:user.credentials.userId community:user.communityId?:kDefaultCommunityName type:type components:components];
    }
}

- (NSString*)directoryForUser:(SFUserAccount*)user type:(NSSearchPathDirectory)type components:(NSArray*)components {
    if (user) {
        if (!user.credentials.organizationId || !user.credentials.userId) {
                [SFSDKCoreLogger w:[self class] format:@"Credentials missing for user"];
            return nil;
        }
        // Note: if the user communityId is nil, we use the default (internal) name for it.
        return [self directoryForOrg:user.credentials.organizationId user:user.credentials.userId community:user.communityId?:kDefaultCommunityName type:type components:components];
    } else {
        return [self globalDirectoryOfType:type components:components];
    }
}

- (NSString*)directoryOfCurrentUserForType:(NSSearchPathDirectory)type components:(NSArray*)components {
    return [self directoryForUser:[SFUserAccountManager sharedInstance].currentUser type:type components:components];
}

- (NSString*)globalDirectoryOfType:(NSSearchPathDirectory)type components:(NSArray*)components {
    return [self directoryForOrg:nil user:nil community:nil type:type components:components];
}

#pragma mark - File Migration Methods

- (void)moveContentsOfDirectory:(NSString *)sourceDirectory toDirectory:(NSString *)destinationDirectory {
    NSFileManager *fileManager = [[NSFileManager alloc]init];
    NSError *error = nil;
    if (sourceDirectory && [fileManager fileExistsAtPath:sourceDirectory]) {
        [SFDirectoryManager ensureDirectoryExists:destinationDirectory error:nil];
        
        NSArray *rootContents = [fileManager contentsOfDirectoryAtPath:sourceDirectory error:&error];
        if (nil == rootContents) {
            if (error) {
                [SFSDKCoreLogger d:[self class] format:@"Unable to enumerate the content at %@: %@", sourceDirectory, error];
            }
        } else {
            for (NSString *s in rootContents) {
                NSString *newFilePath = [destinationDirectory stringByAppendingPathComponent:s];
                NSString *oldFilePath = [sourceDirectory stringByAppendingPathComponent:s];
                if (![fileManager fileExistsAtPath:newFilePath]) {

                    // File does not exist, copy it.
                    if (![fileManager moveItemAtPath:oldFilePath toPath:newFilePath error:&error]) {
                        [SFSDKCoreLogger e:[self class] format:@"Could not move library directory contents to a shared location for app group access: %@", error];
                    }
                } else {
                    [fileManager removeItemAtPath:newFilePath error:&error];
                    [fileManager moveItemAtPath:oldFilePath toPath:newFilePath error:&error];
                }
            }
        }
    }
}

- (void)migrateFiles {
    //Migrate Files
    NSUserDefaults *sharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:[SFSDKDatasharingHelper sharedInstance].appGroupName];
    BOOL isGroupAccessEnabled = [SFSDKDatasharingHelper sharedInstance].appGroupEnabled;
    BOOL filesShared = [sharedDefaults boolForKey:kFilesSharedKey];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *docDirectory,*libDirectory;

    NSArray *directories = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSArray *libDirectories = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);

    if (directories.count > 0) {
        docDirectory = [directories[0] stringByAppendingPathComponent:[NSBundle mainBundle].bundleIdentifier];
    }
    
    NSURL *sharedURL = [fileManager containerURLForSecurityApplicationGroupIdentifier:[SFSDKDatasharingHelper sharedInstance].appGroupName];
    NSString *sharedDirectory = [sharedURL path];
    sharedDirectory = [sharedDirectory stringByAppendingPathComponent:[SFSDKDatasharingHelper sharedInstance].appGroupName];
    if (libDirectories.count > 0) {
        libDirectory = [libDirectories[0] stringByAppendingPathComponent:[NSBundle mainBundle].bundleIdentifier];
    }
    
    if( isGroupAccessEnabled || filesShared ) {
        NSURL *sharedURL = [fileManager containerURLForSecurityApplicationGroupIdentifier:[SFSDKDatasharingHelper sharedInstance].appGroupName];
        NSString *sharedDirectory = [sharedURL path];
        NSString *sharedLibDirectory = nil;
        sharedDirectory = [sharedDirectory stringByAppendingPathComponent:[SFSDKDatasharingHelper sharedInstance].appGroupName];
        sharedLibDirectory = [sharedDirectory stringByAppendingPathComponent:kSharedLibraryLocation];
        
        if (isGroupAccessEnabled && !filesShared) {
            //move files from Docs to the Shared & App Libs to Shared,Shared Library location
            [self moveContentsOfDirectory:libDirectory toDirectory:sharedLibDirectory];
            [self moveContentsOfDirectory:docDirectory toDirectory:sharedDirectory];
            [sharedDefaults setBool:YES forKey:kFilesSharedKey];
        } else if (!isGroupAccessEnabled && filesShared) {
            //move files back from Sahred Location to  Library and the Docs
            [self moveContentsOfDirectory:sharedLibDirectory toDirectory:libDirectory];
            [self moveContentsOfDirectory:sharedDirectory toDirectory:docDirectory];
            [sharedDefaults setBool:NO forKey:kFilesSharedKey];
        }
    }
    
    [sharedDefaults synchronize];
}

@end
