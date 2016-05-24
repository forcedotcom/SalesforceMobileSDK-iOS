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
#import "SFUserAccountConstants.h"

@class SFUserAccount;

/** Global directory manager that returns scoped directory. The scoping is enforced
 by taking into account the organizationId, the userId and the communityId.
 
 The general structure follows this general template:
 <NSSearchPathDirectory> <-- For example, NSCachesDirectory will return Library/Caches
    <bundleIdentifier>   <-- For example, com.salesforce.chatter
        <orgId>
            <userId>
                <internal> : internal community or base org
                [<communityId>]* : zero or more community specific folder
 */
@interface SFDirectoryManager : NSObject

/** Returns the singleton of this manager
 */
+ (instancetype)sharedManager;

/** Ensures the specified directory exists on the disk.
 @param directory The directory to ensure exists.
 @param error The error on output or nil if no error is desired
 @return YES if the directory exists or has been successfully created, NO otherwise.
 */
+ (BOOL)ensureDirectoryExists:(NSString*)directory error:(NSError**)error;

/** Ensure the specified string contains only characters that can be
 safely used to identify a path on the disk.
 @param candidate The string to be checked for compatibility.
 */
+ (NSString*)safeStringForDiskRepresentation:(NSString*)candidate;

/** Returns the path to the directory type for the specified org, user and community.
 @param orgId The organization ID. If nil, this method returns the global directory type requested (eg Library/Caches)
 @param userId The user ID. If nil, this method returns the directory type requested, scoped at the org level (eg Library/Caches/<orgId>/)
 @param communityId The community ID. If nil, this method returns the directory type requested, scoped at the user level (eg Library/Caches/<orgId>/<userId>)
 @param type The type of directory to return (see NSSearchPathDirectory)
 @param components The additional path components to be added at the end of the directory (eg ['mybundle', 'common'])
 @return The path to the directory
 */
- (NSString*)directoryForOrg:(NSString*)orgId user:(NSString*)userId community:(NSString*)communityId type:(NSSearchPathDirectory)type components:(NSArray*)components;

/** Returns the path to the directory type for the specified user and scope
 @param user The user account to use. If nil, the path returned corresponds to the global path type
 @param scope The scope to use
 @param type The type of directory to return (see NSSearchPathDirectory)
 @param components The additional path components to be added at the end of the directory (eg ['mybundle', 'common'])
 @return The path to the directory
 */
- (NSString*)directoryForUser:(SFUserAccount *)user scope:(SFUserAccountScope)scope type:(NSSearchPathDirectory)type components:(NSArray *)components;

/** Returns the path to the directory type for the specified user.
 @param account The user account to use. If nil, the path returned corresponds to the global path type
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

/** Returns the path to the global directory of the specified type. For example, NSCachesDirectory will
 return "Library/Caches/<bundleIdentifier>/"
 @param type The type of directory to return (see NSSearchPathDirectory)
 @param components The additional path components to be added at the end of the directory (eg ['mybundle', 'common'])
 @return The path to the directory
 */
- (NSString*)globalDirectoryOfType:(NSSearchPathDirectory)type components:(NSArray*)components;

@end
