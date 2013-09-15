/*
 Copyright (c) 2012, salesforce.com, inc. All rights reserved.
 
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

@class FMDatabase;

/**
 The NSError domain for SmartStore database errors.
 */
extern NSString * const kSFSmartStoreDbErrorDomain;

@interface SFSmartStoreDatabaseManager : NSObject

/**
 Gets the shared instance of the database manager.
 */
+ (SFSmartStoreDatabaseManager *)sharedManager;

/**
 Whether the store with the given name exists.
 @param storeName The name of the store to query.
 @return YES if the store exists, NO otherwise.
 */
- (BOOL)persistentStoreExists:(NSString*)storeName;

/**
 Creates or opens an existing store DB.
 @param storeName The name of the store to create or open.
 @param key The encryption key associated with the store.
 @param error Returned if there's an error with the process.
 @return The FMDatabase instance representing the DB, or nil if the create/open failed.
 */
- (FMDatabase *)openStoreDatabaseWithName:(NSString *)storeName key:(NSString *)key error:(NSError **)error;

/**
 Encrypts an existing unencrypted database.
 @param db The DB to encrypt.
 @param storeName The name of the store representing the DB.
 @param key The encryption key to be used for encrypting the database.
 @param error Returned if there's an error with encrypting the data.
 @return The newly-encrypted DB, or the original DB if the encryption fails at any point in the process.
 */
- (FMDatabase *)encryptDb:(FMDatabase *)db name:(NSString *)storeName key:(NSString *)key error:(NSError **)error;

/**
 Unencrypts an encrypted database, back to plaintext.
 @param db The database to unencrypt.
 @param storeName The name of the store associated with the DB.
 @param oldKey The original encryption key of the database.
 @param error Returned if there's an error during the process.
 @return The unencrypted database, or the original encrypted database if the process fails at any point.
 */
- (FMDatabase *)unencryptDb:(FMDatabase *)db name:(NSString *)storeName oldKey:(NSString *)oldKey error:(NSError **)error;

/**
 Creates the directory for the store, on the filesystem.
 @param storeName The name of the store to be created.
 @param error Returned if the creation process fails.
 @return YES if the call completed with no errors, NO otherwise.
 */
- (BOOL)createStoreDir:(NSString *)storeName error:(NSError **)error;

/**
 Sets filesystem protection on the store DB contents.
 @param storeName The store associated with the protection.
 @param error Returned if protection fails.
 @return YES if the call completes without errors, NO otherwise.
 */
- (BOOL)protectStoreDir:(NSString *)storeName error:(NSError **)error;

/**
 Removes the store directory and all of its contents from the filesystem.
 @param storeName The store associated with the request.
 */
- (void)removeStoreDir:(NSString *)storeName;

/**
 @return All of the store names associated with this application.
 */
- (NSArray *)allStoreNames;

/**
 The full filesystem path to the database with the given store name.
 @param storeName The name of the store (excluding paths)
 @return full filesystem path for the store db file
 */
- (NSString*)fullDbFilePathForStoreName:(NSString*)storeName;

/**
 Verifies that the database contents at the given path can be read with the given encryption key.
 @param dbPath The path to the database to read.
 @param key The encryption key used against the database.
 @param error The output NSError parameter that will be populated in the event of an error.
 @return YES if the database can be read, NO otherwise.
 */
- (BOOL)verifyDatabaseAccess:(NSString *)dbPath key:(NSString *)key error:(NSError **)error;

@end
