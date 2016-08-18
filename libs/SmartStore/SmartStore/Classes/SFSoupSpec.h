/*
 Copyright (c) 2012-2016, salesforce.com, inc. All rights reserved.
 
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

extern NSString * const kSoupSpecSoupName;
extern NSString * const kSoupSpecFeatures;

// Soup Features
/**
 *  Feature to store soup data blobs separately in the file system.
 *  Recommended for optimal memory consumption when your soup might contain large payloads.
 *  Database operations using soup payloads will not be available, since they aren't stored in the database.
 */
extern NSString * const kSoupFeatureExternalStorage;

/**
 * Object containing soup specifications, such as soup name and features.
 */
@interface SFSoupSpec : NSObject

/**
 *  The soup name.
 */
@property (nonatomic, copy, readonly) NSString *soupName;

/**
 *  The soup features.
 */
@property (nonatomic, copy, readonly) NSArray *features;

/**
 * Factory method to build a soup spec.
 * @param soupName The soup name.
 * @param features The soup features.
 * @return A soup spec object.
 */
+ (SFSoupSpec *)newSoupSpec:(NSString *)soupName withFeatures:(NSArray *)features;

/**
 * Factory method to build a soup spec from a dictionary.
 * @discussion At least "soupName" is required. Otherwise, this method returns nil.
 * @param dictionary A dictionary with soup spec info. Keys must match <code>kSoupSpec<i>xxx</i></code> constants defined in this header file.
 * @return A soup spec object.
 */
+ (SFSoupSpec *)newSoupSpecWithDictionary:(NSDictionary *)dictionary;

/**
 * A dictionary representation for this SFSoupSpec object. 
 * Use keys defined in the <code>kSoupSpec<i>xxx</i></code> constants in this header file.
 * @return An NSDictionary object representing this SFSoupSpec object.
 */
- (NSDictionary *)asDictionary;

@end
