/*
 Copyright (c) 2012-present, salesforce.com, inc. All rights reserved.
 Author: Kevin Hawkins
 
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

/**
 * The value that will be used to replace the redacted querystring value.
 */
extern NSString * const kSFRedactedQuerystringValue;

/**
 * Utilities for interacting with NSURL objects.
 */
@interface NSURL (SFStringUtils)

/**
 * Will return the absolute string of a URL, with potentially sensitive querystring
 * parameter values redacted.  Useful for logging URL values without sensitive data
 * included.
 * @param queryStringParamsToRedact An array of querystring parameter names whose values
 *                                  should be redacted.
 * @return The redacted version of the absolute string value.
 */
- (NSString *)redactedAbsoluteString:(NSArray *)queryStringParamsToRedact;

/**
 Helper method that constructs an absolute URL string given the specified components.
 @param baseUrl The base URL
 @param pathComponents The components of the path
 @return an absolute string URL representation
 */
+ (NSString*)stringUrlWithBaseUrl:(NSURL*)baseUrl pathComponents:(NSArray*)pathComponents;

/**
 Helper method that constructs an absolute URL string given the specified components.
 @param scheme The scheme of the URL
 @param host The host of the URL
 @param port The port of the URL
 @param pathComponents The components of the path
 @return an absolute string URL representation
 */
+ (NSString*)stringUrlWithScheme:(NSString*)scheme host:(NSString*)host port:(NSNumber*)port pathComponents:(NSArray*)pathComponents;

@end
