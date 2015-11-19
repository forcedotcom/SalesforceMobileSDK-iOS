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

#import "SFIdentityData.h"

@interface SFIdentityData ()

@property (strong, nonatomic, readwrite) NSDictionary *dictRepresentation;
@property (strong, nonatomic, readwrite) NSDictionary *customAttributes;
@property (strong, nonatomic, readwrite) NSDictionary *customPermissions;

/**
 * Creates an NSDate object from an RFC 822-formatted date string.
 * @param dateString The date string to parse into an NSDate.
 * @return The NSDate representation of the date string.
 */
+ (NSDate *)dateFromRfc822String:(NSString *)dateString;

/**
 * Returns the URL configured in the sub-object of the parent, or nil if the parent
 * object does not exist.
 * @param parentKey The data key associated with the parent object.
 * @param childKey The data key associated with the child object where the URL is configured.
 * @return The NSURL representation configured in the child object, or nil if the parent
 *         does not exist.
 */
- (NSURL *)parentExistsOrNilForUrl:(NSString *)parentKey childKey:(NSString *)childKey;

/**
 * Returns the NSString configured in the sub-object of the parent, or nil if the parent
 * object does not exist.
 * @param parentKey The data key associated with the parent object.
 * @param childKey The data key associated with the child object where the string is configured.
 * @return The NSString representation configured in the child object, or nil if the parent
 *         does not exist.
 */
- (NSString *)parentExistsOrNilForString:(NSString *)parentKey childKey:(NSString *)childKey;

@end