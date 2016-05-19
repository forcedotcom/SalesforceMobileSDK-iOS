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

/** Preferences class that handles scoped preferences.
 A scope binds the preferences to a specific user,
 org or community.
 */
@interface SFPreferences : NSObject

/** Returns the path in which the preferences file exists
 */
@property (nonatomic, strong, readonly) NSString *path;

/** Returns the underlying dictionary representation
 */
@property (nonatomic, copy, readonly) NSDictionary *dictionaryRepresentation;

/** Returns the global instance of the preferences (one per application)
 */
+ (instancetype)globalPreferences;

/** Returns the preferences instance related to the specified user's organization
 or nil if there is no specified user or scope.
 @param scope The scope to which the preferences apply: global, user's org, user's community, or user's account.
 @param user The account to which the preferences apply. Not used if scope is global.
 */
+ (instancetype)sharedPreferencesForScope:(SFUserAccountScope)scope user:(SFUserAccount*)user;

/** Returns the preferences instance related to the current user's organization
 or nil if there is no current user.
 */
+ (instancetype)currentOrgLevelPreferences;

/** Returns the preferences instance related to the currrent user
 or nil if there is no current user.
 */
+ (instancetype)currentUserLevelPreferences;

/** Returns the preferences instance related to the currrent user's community
 or nil if there is no current user.
 */
+ (instancetype)currentCommunityLevelPreferences;

/** Returns the preferences object for the given key.
 @param key The key of the requested object.
 */
- (id)objectForKey:(NSString*)key;

/** Sets the preference object for the given attribute key. Logs an SFLogLevelError if the key is not found.
 @param object Object to be set.
 @param key Key of object to be set.
 */

- (void)setObject:(id)object forKey:(NSString*)key;

/** Removes the preference object for the given attribute key.
 @param key Key of object to be removed.
 */
- (void)removeObjectForKey:(NSString*)key;

/** Returns the Boolean preference value for the given key.
 @param key The key of the requested preference value.
 */
- (BOOL)boolForKey:(NSString*)key;

/** Assigns the given Boolean preference value to the given key.
 @param value The Boolean value.
 @param key The key of the preference value to be edited.
 */
- (void)setBool:(BOOL)value forKey:(NSString*)key;

/** Returns the integer preference value for the given key.
 @param key The key of the requested preference value.
 */
- (NSInteger)integerForKey:(NSString *)key;

/** Assigns the given integer preference value to the given key.
 @param value The integer value.
 @param key The key of the preference value to be edited.
 */
- (void)setInteger:(NSInteger)value forKey:(NSString *)key;

/** Returns the string preference value for the given key.
 @param key The key of the requested preference value.
 */
- (NSString*)stringForKey:(NSString*)key;

/** Saves the preferences to the disk
 */
- (void)synchronize;

/** Remove all saved objects 
 */
- (void)removeAllObjects;

@end
