//
//  SFFileProtectionHelper.h
//  SalesforceCommonUtils
//
//  Created by Jean Bovet on 3/7/15.
//  Copyright (c) 2015 Salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>

/** This helper class aims at providing a centralized
 place where NSFileProtection can be configured and retrieved.
 */
@interface SFFileProtectionHelper : NSObject

/** Contains the default NSFileProtection mode to use
 if no protection is specified. By default, this property
 is NSFileProtectionComplete
 */
@property (nonatomic, strong) NSString *defaultNSFileProtectionMode;

/** A mapping of paths to custom file protection statuses
 */
@property (nonatomic, readonly) NSDictionary *pathsToFileProtection;

/** Returns the shared instance
 */
+ (instancetype)sharedInstance;

/** Helper method that will return the file protection
 for the specified file path.
 @param path The path for which to return the file protection
 @return The file protection
 */
+ (NSString*)fileProtectionForPath:(NSString*)path;


/** Add a valid file protection attribute to a path
 @param fileProtection Type of file protection to apply to the path
 @param path The path for which to return the file protection
 */
- (void)addProtection:(NSString *)fileProtection forPath:(NSString *)path;

@end
