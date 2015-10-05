//
//  SFPathUtil.h
//  SalesforceCommonUtils
//
//  Copyright (c) 2008-2012 salesforce.com. All rights reserved.
//

#import <UIKit/UIKit.h>

/**This is a utility class that helps to create sub folder under either Documents directory or cache directory. Any folder or file created by SFPathUtil will be marked with NSFileProtectionComplete attribute and also excluded from iCloud backup
 */
@interface SFPathUtil : NSObject {
    
}

/** Creates the file at the specified if it doesn't exist
 @param skipBackup YES if the file should be marked to not be backed up with iCloud
 */
+ (void)createFileItemIfNotExist:(NSString *)path skipBackup:(BOOL)skipBackup;

/*Returns application's dcoument directory*/
+ (NSString *)applicationDocumentDirectory;


/*Returns application's cache directory*/
+ (NSString *)applicationCacheDirectory;


/** Returns the absolute path for libray folder */
+ (NSString *)applicationLibraryDirectory;

/*Returns the absolute path for a directory/folder located in the apps document directory.
 
 It also ensures this sub-directory exists, applies NSFileProtectionComplete protection attributes 
 and also mark file to be not backup by iCloud
 Folder created will be protected by NSFileProtectionComplete.
 
 @param folder Folder to create under Document directory
 */
+ (NSString *)absolutePathForDocumentFolder:(NSString *)folder;


/*Returns the absolute path for a directory/folder located in the apps document directory
 
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

/**Add iOS file protection to the specified file path and also mark DO NOT back up by iCloud if notbackupFlag is true
 The file or path that is passed in must already exist
 
 @param filePath Path to file or folder
 @param notbackupFlag Set to YES if need to mark as do not back up by iCloud
 */
+ (void)secureFilePath:(NSString *)filePath markAsNotBackup:(BOOL)notbackupFlag;

/*Returns the absolute path for a directory/folder located in the apps document directory
 
 It also ensures this sub-directory exists, applies NSFileProtectionComplete protection attributes
 and also mark file to be not backup by iCloud
 
 @param folder Folder to create under Document directory
 @param fileProtection File protection string. If nil, NSFileProtectionComplete will be used
 */
+ (NSString *)absolutePathForDocumentFolder:(NSString *)folder fileProtection:(NSString *)fileProtection;


/*Returns the absolute path for a directory/folder located in the apps document directory
 
 It also ensures this sub-directory exists, applies file protection attributes
 and also mark file to be not backup by iCloud
 @param folder Folder to create under Cache directory
 @param fileProtection File protection string. If nil, NSFileProtectionComplete will be used
 */
+ (NSString *)absolutePathForCacheFolder:(NSString *)folder fileProtection:(NSString *)fileProtection;


/** Returns the absolute path for libray folder
 
 It also ensures this sub-directory exists, applies file protection attributes
 and also mark file to be not backup by iCloud
 @param folder Folder to create under Library directory
 @param fileProtection File protection string. If nil, NSFileProtectionComplete will be used
 */
+ (NSString *)absolutePathForLibraryFolder:(NSString *)folder fileProtection:(NSString *)fileProtection;

/**Add iOS file protection to the specified file path and also mark DO NOT back up by iCloud if notbackupFlag is true
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
