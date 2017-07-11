/*
 Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.

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
#import "SFDefaultUserAccountPersister.h"
#import "SFDirectoryManager.h"
#import "SFKeyStoreManager.h"
#import "SFSDKCryptoUtils.h"
#import "SFFileProtectionHelper.h"


// Name of the individual file containing the archived SFUserAccount class
static NSString * const kUserAccountPlistFileName = @"UserAccount.plist";

// Prefix of an org ID
static NSString * const kOrgPrefix = @"00D";

// Prefix of a user ID
static NSString * const kUserPrefix = @"005";

// Label for encryption key for user account persistence.
static NSString * const kUserAccountEncryptionKeyLabel = @"com.salesforce.userAccount.encryptionKey";

// Error domain and codes
static NSString * const SFUserAccountManagerErrorDomain = @"SFUserAccountManager";

static const NSUInteger SFUserAccountManagerCannotReadDecryptedArchive = 10001;
static const NSUInteger SFUserAccountManagerCannotRetrieveUserData = 10003;

static const NSUInteger SFUserAccountManagerCannotWriteUserData = 10004;

@interface SFDefaultUserAccountPersister()

@end

@implementation SFDefaultUserAccountPersister

- (BOOL)saveAccountForUser:(SFUserAccount *)userAccount error:(NSError **)error {
    BOOL success = NO;
    NSString *userAccountPlist = [SFDefaultUserAccountPersister userAccountPlistFileForUser:userAccount];
    success = [self saveUserAccount:userAccount toFile:userAccountPlist error:error];
    return success;
}

- (NSDictionary<SFUserAccountIdentity *,SFUserAccount *> *)fetchAllAccounts:(NSError **)error {
   
    NSMutableDictionary<SFUserAccountIdentity *,SFUserAccount *> *userAccountMap = [NSMutableDictionary new];
    
    // Get the root directory, usually ~/Library/<appBundleId>/
    NSString *rootDirectory = [[SFDirectoryManager sharedManager] directoryForUser:nil type:NSLibraryDirectory components:nil];
    NSFileManager *fm = [[NSFileManager alloc] init];
    if ([fm fileExistsAtPath:rootDirectory]) {
        // Now iterate over the org and then user directories to load
        // each individual user account file.
        // ~/Library/<appBundleId>/<orgId>/<userId>/UserAccount.plist
        NSArray *rootContents = [fm contentsOfDirectoryAtPath:rootDirectory error:error];
        if (nil == rootContents) {
            NSString *reason = [NSString stringWithFormat:@"Unable to enumerate the content at %@", rootDirectory];
            [SFSDKCoreLogger w:[self class] format:reason];
            if (error) {
                *error = [NSError errorWithDomain:SFUserAccountManagerErrorDomain
                                             code:SFUserAccountManagerCannotRetrieveUserData
                                         userInfo:@{ NSLocalizedDescriptionKey : reason } ];
            }
        } else {
            for (NSString *rootContent in rootContents) {
                
                // Ignore content that doesn't represent the OrgID-based folder structure of user account persistence.
                if (![rootContent hasPrefix:kOrgPrefix]) {
                    continue;
                }
                NSString *rootPath = [rootDirectory stringByAppendingPathComponent:rootContent];
                
                // Fetch the content of the org directory
                NSArray *orgContents = [fm contentsOfDirectoryAtPath:rootPath error:error];
                if (nil == orgContents) {
                    if (error) {
                        [SFSDKCoreLogger d:[self class] format:@"Unable to enumerate the content at %@: %@", rootPath, *error];
                    }
                    continue;
                }

                for (NSString *orgContent in orgContents) {
                    
                    // Ignore content that doesn't represent the UserID-based folder structure of user account persistence.
                    if (![orgContent hasPrefix:kUserPrefix]) {
                        continue;
                    }
                    NSString *orgPath = [rootPath stringByAppendingPathComponent:orgContent];

                    // Now let's try to load the user account file in there
                    NSString *userAccountPath = [orgPath stringByAppendingPathComponent:kUserAccountPlistFileName];
                    if ([fm fileExistsAtPath:userAccountPath]) {
                        SFUserAccount *userAccount = nil;
                        [self loadUserAccountFromFile:userAccountPath account:&userAccount error:nil];
                        if (userAccount) {
                            userAccountMap[userAccount.accountIdentity] = userAccount;
                        } else {
                            // Error logging will already have occurred.  Make sure account file data is removed.
                            [fm removeItemAtPath:userAccountPath error:nil];
                        }
                    } else {
                        [SFSDKCoreLogger d:[self class] format:@"There is no user account file in this user directory: %@", orgPath];
                    }
                }
            }
        }
    }
    return userAccountMap;
}

- (BOOL)deleteAccountForUser:(SFUserAccount *)user error:(NSError **)error {
    BOOL success = NO;
    if (nil != user) {
        NSFileManager *manager = [[NSFileManager alloc] init];
        NSString *userDirectory = [[SFDirectoryManager sharedManager] directoryForUser:user
                                                                                 scope:SFUserAccountScopeUser
                                                                                  type:NSLibraryDirectory
                                                                            components:nil];
        if ([manager fileExistsAtPath:userDirectory]) {
            NSError *folderRemovalError = nil;
            success= [manager removeItemAtPath:userDirectory error:&folderRemovalError];
            if (!success) {
                [SFSDKCoreLogger d:[self class]
                   format:@"Error removing the user folder for '%@': %@", user.userName, [folderRemovalError localizedDescription]];
                if (folderRemovalError && error) {
                    *error = folderRemovalError;
                }
            }
        } else {
            NSString *reason = [NSString stringWithFormat:@"User folder for user '%@' does not exist on the filesystem", user.userName];
            NSError *ferror = [NSError errorWithDomain:SFUserAccountManagerErrorDomain
                                                  code:SFUserAccountManagerCannotReadDecryptedArchive
                                              userInfo:@{NSLocalizedDescriptionKey: reason}];
            [SFSDKCoreLogger d:[self class] format:@"User folder for user '%@' does not exist on the filesystem.", user.userName];
            if(error)
                *error = ferror;
        }
    }
    return success;
}

- (BOOL)saveUserAccount:(SFUserAccount *)userAccount toFile:(NSString *)filePath error:(NSError**)error {

    if (!userAccount) {
        NSString *reason = @"Could not save an null user account.";
        [SFSDKCoreLogger w:[self class] format:reason];
        if (error)
            *error = [NSError errorWithDomain:SFUserAccountManagerErrorDomain
                                         code:SFUserAccountManagerCannotWriteUserData
                                     userInfo:@{ NSLocalizedDescriptionKey : reason } ];
        return NO;
    }

    if (filePath.length==0) {
        NSString *reason = @"File path cannot be empty. Could not save the user account to file.";
        [SFSDKCoreLogger w:[self class] format:reason];
        if (error)
            *error = [NSError errorWithDomain:SFUserAccountManagerErrorDomain
                                         code:SFUserAccountManagerCannotWriteUserData
                                     userInfo:@{ NSLocalizedDescriptionKey : reason } ];
        return NO;
    }

    // Remove any existing file.
    NSFileManager *manager = [[NSFileManager alloc] init];
    if ([manager fileExistsAtPath:filePath]) {
        NSError *removeAccountFileError = nil;
        if (![manager removeItemAtPath:filePath error:&removeAccountFileError]) {
            NSString *reason = [NSString stringWithFormat:@"Failed to remove old user account data at path '%@': %@",filePath,[removeAccountFileError localizedDescription]];
            [SFSDKCoreLogger w:[self class] format:reason];
            if (error)
                *error = [NSError errorWithDomain:SFUserAccountManagerErrorDomain
                                             code:SFUserAccountManagerCannotWriteUserData
                                         userInfo:@{ NSLocalizedDescriptionKey : reason } ];
            return NO;
        }
    }

    // Serialize the user account data.
    NSData *archiveData = [NSKeyedArchiver archivedDataWithRootObject:userAccount];
    if (!archiveData) {
        NSString *reason = [NSString stringWithFormat:@"Could not archive user account data to save it.  %@",filePath];
        [SFSDKCoreLogger w:[self class] format:reason];
        if (error)
            *error = [NSError errorWithDomain:SFUserAccountManagerErrorDomain
                                         code:SFUserAccountManagerCannotWriteUserData
                                     userInfo:@{ NSLocalizedDescriptionKey : reason } ];
        return NO;
    }

    // Encrypt it.
    SFEncryptionKey *encKey = [[SFKeyStoreManager sharedInstance] retrieveKeyWithLabel:kUserAccountEncryptionKeyLabel keyType:SFKeyStoreKeyTypeGenerated autoCreate:YES];
    NSData *encryptedArchiveData = [SFSDKCryptoUtils aes256EncryptData:archiveData withKey:encKey.key iv:encKey.initializationVector];
    if (!encryptedArchiveData) {
        NSString *reason = [NSString stringWithFormat:@"User account data could not be encrypted.  %@",filePath];
        [SFSDKCoreLogger w:[self class] format:reason];
        if (error)
            *error = [NSError errorWithDomain:SFUserAccountManagerErrorDomain
                                         code:SFUserAccountManagerCannotWriteUserData
                                     userInfo:@{ NSLocalizedDescriptionKey : reason } ];
        return NO;
    }
    // Save it.
    BOOL saveFileSuccess = [manager createFileAtPath:filePath contents:encryptedArchiveData attributes:@{ NSFileProtectionKey : [SFFileProtectionHelper fileProtectionForPath:filePath] }];
    if (!saveFileSuccess) {
        NSString *reason = [NSString stringWithFormat:@"Could not create user account data file at path.  %@",filePath];
        [SFSDKCoreLogger w:[self class] format:reason];
        if (error)
            *error = [NSError errorWithDomain:SFUserAccountManagerErrorDomain
                                         code:SFUserAccountManagerCannotWriteUserData
                                     userInfo:@{ NSLocalizedDescriptionKey : reason } ];
        return NO;
    }

    return YES;
}

/** Loads a user account from a specified file
 @param filePath The file to load the user account from
 @param account On output, contains the user account or nil if an error occurred
 @param error On output, contains the error if the method returned NO
 @return YES if the method succeeded, NO otherwise
 */
 - (BOOL)loadUserAccountFromFile:(NSString *)filePath account:(SFUserAccount**)account error:(NSError**)error {

        NSFileManager *manager = [[NSFileManager alloc] init];
        NSString *reason = @"User account data could not be decrypted. Can't load account.";
        NSData *encryptedUserAccountData = [manager contentsAtPath:filePath];
        if (!encryptedUserAccountData) {
            reason = [NSString stringWithFormat:@"Could not retrieve user account data from '%@'", filePath];
            if (error) {
                *error = [NSError errorWithDomain:SFUserAccountManagerErrorDomain
                                             code:SFUserAccountManagerCannotRetrieveUserData
                                         userInfo:@{NSLocalizedDescriptionKey: reason}];
            }
            [SFSDKCoreLogger d:[self class] format:reason];
            return NO;
        }
        SFEncryptionKey *encKey = [[SFKeyStoreManager sharedInstance] retrieveKeyWithLabel:kUserAccountEncryptionKeyLabel keyType:SFKeyStoreKeyTypeGenerated autoCreate:YES];
        NSData *decryptedArchiveData = [SFSDKCryptoUtils aes256DecryptData:encryptedUserAccountData withKey:encKey.key iv:encKey.initializationVector];
        if (!decryptedArchiveData) {
            if (error) {
                *error = [NSError errorWithDomain:SFUserAccountManagerErrorDomain
                                             code:SFUserAccountManagerCannotRetrieveUserData
                                         userInfo:@{NSLocalizedDescriptionKey: reason}];
            }
            [SFSDKCoreLogger w:[self class] format:reason];
            return NO;
        }

        SFUserAccount *decryptedAccount = [NSKeyedUnarchiver unarchiveObjectWithData:decryptedArchiveData];

            // On iOS9, it won't throw an exception, but will return nil instead.
        if (decryptedAccount) {
            if (account) {
                *account = decryptedAccount;
            }
            return YES;
        } else {
            if (error) {
                *error = [NSError errorWithDomain:SFUserAccountManagerErrorDomain
                                             code:SFUserAccountManagerCannotReadDecryptedArchive
                                         userInfo:@{NSLocalizedDescriptionKey: reason}];
            }
            return NO;
        }
}

+ (NSString*)userAccountPlistFileForUser:(SFUserAccount*)user {
    NSString *directory = [[SFDirectoryManager sharedManager] directoryForOrg:user.credentials.organizationId user:user.credentials.userId community:nil type:NSLibraryDirectory components:nil];
    [SFDirectoryManager ensureDirectoryExists:directory error:nil];
    return [directory stringByAppendingPathComponent:kUserAccountPlistFileName];
}

+ (NSString*)userAccountPlistFileForUserId:(SFUserAccountIdentity*)userAccountIdentity {
    NSString *directory = [[SFDirectoryManager sharedManager] directoryForOrg:userAccountIdentity.orgId user:userAccountIdentity.userId community:nil type:NSLibraryDirectory components:nil];
    [SFDirectoryManager ensureDirectoryExists:directory error:nil];
    return [directory stringByAppendingPathComponent:kUserAccountPlistFileName];
}

@end
