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

#import <Foundation/Foundation.h>

/** This is a utility class that helps to create sub folder under either Documents directory or cache directory. Any folder or file created by SFPathUtil will be marked with NSFileProtectionComplete attribute and also excluded from iCloud backup
 */
@interface SFPathUtil : NSObject {
    
}

/** Creates the file at the specified path if it doesn't exist
 @param path The path where the file should be created
 @param skipBackup YES if the file should be marked to not be backed up with iCloud
 */
+ (void)createFileItemIfNotExist:(NSString *)path skipBackup:(BOOL)skipBackup;

/** Returns application's dcoument directory*/
+ (NSString *)applicationDocumentDirectory;


/** Returns application's cache directory*/
+ (NSString *)applicationCacheDirectory;


/** Returns the absolute path for libray folder */
+ (NSString *)applicationLibraryDirectory;

/** Returns the absolute path for a directory/folder located in the apps document directory.
 
 It also ensures this sub-directory exists, applies NSFileProtectionComplete protection attributes 
 and also mark file to be not backup by iCloud
 Folder created will be protected by NSFileProtectionComplete.
 
 @param folder Folder to create under Document directory
 */
+ (NSString *)absolutePathForDocumentFolder:(NSString *)folder;


/** Returns the absolute path for a directory/folder located in the apps document directory
 
 It also ensures this sub-directory exists, applies file protection attributes 
 and also mark file to be not backup by iCloud 
 Folder created will be protected by NSFileProtectionComplete
 
 @param folder Folder to create under Cache directory
 */
+ (NSString *)absolutePathForCacheFolder:(NSString *)folder;


/** Returns the absolute path for libray folder 
 
 It also ensures this sub-directory exists, applies file protection attributes
 and also mark file to be not backup by iCloud
 Folder created will be protected by NSFileProtectionComplete
 
 @param folder Folder to create under Library directory
 */
+ (NSString *)absolutePathForLibraryFolder:(NSString *)folder;

/** Add iOS file protection to the specified file path and also mark DO NOT back up by iCloud if notbackupFlag is true
 The file or path that is passed in must already exist
 
 @param filePath Path to file or folder
 @param notbackupFlag Set to YES if need to mark as do not back up by iCloud
 */
+ (void)secureFilePath:(NSString *)filePath markAsNotBackup:(BOOL)notbackupFlag;

/** Returns the absolute path for a directory/folder located in the apps document directory
 
 It also ensures this sub-directory exists, applies NSFileProtectionComplete protection attributes
 and also mark file to be not backup by iCloud
 
 @param folder Folder to create under Document directory
 @param fileProtection File protection string. If nil, NSFileProtectionComplete will be used
 */
+ (NSString *)absolutePathForDocumentFolder:(NSString *)folder fileProtection:(NSString *)fileProtection;


/** Returns the absolute path for a directory/folder located in the apps document directory
 
 It also ensures this sub-directory exists, applies file protection attributes
 and also mark file to be not backup by iCloud
 @param folder Folder to create under Cache directory
 @param fileProtection File protection string. If nil, NSFileProtectionComplete will be used
 */
+ (NSString *)absolutePathForCacheFolder:(NSString *)folder fileProtection:(NSString *)fileProtection;


/** Returns the absolute path for library folder
 
 It also ensures this sub-directory exists, applies file protection attributes
 and also mark file to be not backup by iCloud
 @param folder Folder to create under Library directory
 @param fileProtection File protection string. If nil, NSFileProtectionComplete will be used
 */
+ (NSString *)absolutePathForLibraryFolder:(NSString *)folder fileProtection:(NSString *)fileProtection;

/** Add iOS file protection to the specified file path and also mark DO NOT back up by iCloud if notbackupFlag is true
 The file or path that is passed in must already exist
 
 @param filePath Path to file or folder
 @param notbackupFlag Set to YES if need to mark as do not back up by iCloud
  @param fileProtection File protection string. If nil, NSFileProtectionComplete will be used
 */
+ (void)secureFilePath:(NSString *)filePath markAsNotBackup:(BOOL)notbackupFlag fileProtection:(NSString *)fileProtection;

/** Add DO NOT back up flag to the file resource specified by the file path
 
 @param filePath file path
 @param recursive If filePath points to a directlory, set to YES to recursively apply skip backup attribute to all files under the directory including sub-directory under the directory
 @param fileProtection File protection string. If nil, NSFileProtectionComplete will be used
 */
+ (void)secureFileAtPath:(NSString *)filePath recursive:(BOOL)recursive fileProtection:(NSString *)fileProtection;

@end
