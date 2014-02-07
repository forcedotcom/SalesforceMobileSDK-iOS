/*
 Copyright (c) 2012-2014, salesforce.com, inc. All rights reserved.
 
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

/** Ensure the specified string contains only characters that can be
 safely used to identify a path on the disk.
 */
+ (NSString*)safeStringForDiskRepresentation:(NSString*)candidate;

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
 @param account The user account to use. If nil, the current account is used or nil if no current account
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
