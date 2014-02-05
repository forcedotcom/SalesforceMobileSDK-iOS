//
//  SFDirectoryManager.h
//  SalesforceSDKCore
//
//  Created by Jean Bovet on 1/24/14.
//  Copyright (c) 2014 salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>

/** Global directory manager that returns various scoped persistent or cached directories.
 The scoping is enforced by taking into account the user and the community the user is logged in.
 The general structure is as follow:
 Documents
	<orgId+userId>
		<internal> : internal community or base org
		[<communityId>]* : zero or more community specific folder

 Library
	Caches
		<orgId+userId>
			<internal> : internal community or base org
			[<communityId>]* : zero or more community specific folder

 For example:
    Library/Caches/005R0000000HiM9/0DBR00000004CECOA2/
    Library/Caches/005R0000000HiM9/internal/    : "internal" refers to the internal (or base) community
 */

@class SFUserAccount;

@interface SFDirectoryManager : NSObject

/** Returns the singleton of this manager
 */
+ (instancetype)sharedManager;

/** Ensures the specified directory exists on the disk.
 @param directory The directory to ensure exists.
 @return YES if the directory exists or has been successfully created, NO otherwise.
 */
+ (BOOL)ensureDirectoryExists:(NSString*)directory;

/** Returns the path to the directory type for the specified org, user and community.
 @param orgId The organization ID. If nil, this method returns the global cache directory (Library/Caches)
 @param userId The user ID. If nil, this method returns the global cache directory (Library/Caches)
 @param communityId The community ID. If nil, this method returns the directory to the internal org (Library/Caches/.../internal/)
 @param type The type of directory to return (see NSSearchPathDirectory)
 @param components The additional path components to be added at the end of the directory (eg ['mybundle', 'common'])
 @return The path to the directory
 */
- (NSString*)directoryForOrg:(NSString*)orgId user:(NSString*)userId community:(NSString*)communityId type:(NSSearchPathDirectory)type components:(NSArray*)components;

/** Returns the path to the directory type for the specified user.
 @param account The user account to use
 @param type The type of directory to return (see NSSearchPathDirectory)
 @param components The additional path components to be added at the end of the directory (eg ['mybundle', 'common'])
 @return The path to the directory
 */
- (NSString*)directoryForUser:(SFUserAccount*)account type:(NSSearchPathDirectory)type components:(NSArray*)components;

/** Returns the path to the directory type for the current user and current community.
 @param type The type of directory to return (see NSSearchPathDirectory)
 @param components The additional path components to be added at the end of the directory (eg ['mybundle', 'common'])
 @return The path to the directory
 */
- (NSString*)directoryOfCurrentUserForType:(NSSearchPathDirectory)type components:(NSArray*)components;

@end
