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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol SFUserAccountPersister;

@interface SFDefaultUserAccountPersister:NSObject<SFUserAccountPersister>

/** Loads a user account from a specified file
 @param filePath The file to load the user account from
 @param account On output, contains the user account or nil if an error occurred
 @param error On output, contains the error if the method returned NO
 @return YES if the method succeeded, NO otherwise
 */
- (BOOL)loadUserAccountFromFile:(NSString *)filePath account:(SFUserAccount*_Nullable*_Nullable)account error:(NSError**)error;

/** Updates/Saves a user account to a specified filePath
 * @param userAccount On output, contains the user account or nil if an error occurred
 * @param filePath  The file to save the user account to
 * @param error On output, contains the error if the method returned NO
 * @return YES if the method succeeded, NO otherwise
 */
- (BOOL)saveUserAccount:(SFUserAccount *)userAccount toFile:(NSString *)filePath error:(NSError**)error;

/**
 Returns the path of the user account plist file for the specified user
 @param user The user
 @return the path to the user account plist of the specified user
 */
+ (NSString*)userAccountPlistFileForUser:(SFUserAccount*)user;

@end

NS_ASSUME_NONNULL_END
