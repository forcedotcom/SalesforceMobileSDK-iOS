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
