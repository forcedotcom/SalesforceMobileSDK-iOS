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

/**Extension to NSDictionary object
 
 Support retrieval of value use "/" separated hiearchy key
 */
@interface NSDictionary (SFAdditions)

/**Get object from NSDictionary with "/" separated path. 
 
 This method is similar to the built-in valueForKeyPath function except it handles special value like NSNULL and <nil> in the NSDictonary element value*
 
 @param path Path for the object to retrieve. Use "/" to separate between levels. For example, root/child/valueKey will retrieve value from the root NSDictionary object to its child dictionary's value with key "valueKey"  */
- (id) objectAtPath:(NSString *) path;

/**Returns an object whose ID is key, or nil.
 @param key The ID of an object, or a null value
 @return An object whose ID is key, or else nil if the key has a value of NSNull or an NSString value of "<nil>" or "<null>".
 */
- (id)nonNullObjectForKey:(id)key;

/** Returns the dictionary's contents reformatted as a JSON string.
 */

- (NSString*)jsonString;

@end
