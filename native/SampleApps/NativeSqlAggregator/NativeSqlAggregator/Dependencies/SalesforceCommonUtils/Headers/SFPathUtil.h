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

/*Returns application's dcoument directory*/
+ (NSString *)applicationDocumentDirectory;


/*Returns application's cache directory*/
+ (NSString *)applicationCacheDirectory;


/** Returns the absolute path for libray folder */
+ (NSString *)applicationLibraryDirectory;

/*Returns the absolute path for a directory/folder located in the apps document directory
 
 It also ensures this sub-directory exists, applies NSFileProtectionComplete protection attributes 
 and also mark file to be not backup by iCloud 
 
 @param folder Folder to create under Document directory
 */
+ (NSString *)absolutePathForDocumentFolder:(NSString *)folder;


/*Returns the absolute path for a directory/folder located in the apps document directory
 
 It also ensures this sub-directory exists, applies file protection attributes 
 and also mark file to be not backup by iCloud 
 @param folder Folder to create under Cache directory
 */
+ (NSString *)absolutePathForCacheFolder:(NSString *)folder;


/** Returns the absolute path for libray folder 
 
 It also ensures this sub-directory exists, applies file protection attributes
 and also mark file to be not backup by iCloud
 @param folder Folder to create under Library directory
 */
+ (NSString *)absolutePathForLibraryFolder:(NSString *)folder;

/**Add iOS file protection to the specified file path and also mark DO NOT back up by iCloud if notbackupFlag is true
 The file or path that is passed in must already exist
 
 @param filePath Path to file or folder
 @param notbackupFlag Set to YES if need to mark as do not back up by iCloud
 */
+ (void)secureFilePath:(NSString *)filePath markAsNotBackup:(BOOL)notbackupFlag;
@end
