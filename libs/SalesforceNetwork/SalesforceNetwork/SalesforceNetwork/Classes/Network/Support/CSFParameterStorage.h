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
#import "CSFDefines.h"

/**
 Class that declares an abstract interface for working with HTTP request parameters.

 This allows for different backing implementations based on whether the requests are GET, POST, PATCH, etc.
 */
@interface CSFParameterStorage : NSObject

/**
 Exposes the underlying style this parameter storage will be represented as.
 
 This value may change based on the types of content supplied to it.  This property conforms to KVO, so it's safe
 to observe this property to be informed when the storage type will change.
 */
@property (nonatomic, assign, readonly) CSFParameterStyle parameterStyle;

/**
 If a custom request body is required for a particular action type, this property can be set to an 
 NSInputStream instance to override the data that will be submitted to the server.
 
 @discussion
 This property can be used in circumstances where URL Form-Encoded or Multipart request bodies can't be used,
 for example when posting a direct JSON payload to a server.  This property is a block that returns an
 `NSInputStream`, rather than an input stream itself, because an input stream cannot be re-used, which will
 cause problems when replaying a request after refreshing authentication credentials.
 
 Use of this feature will automatically disable the setting of HTTP Content-Type and Content-Length headers,
 so it's the responsibility of the user of this property to update those headers accordingly.
 */
@property (nonatomic, copy) NSInputStream *(^bodyStreamBlock)(void);

/**
 List of all the parameter keys that have been added to this instance.
 */
@property (nonatomic, copy, readonly) NSArray *allKeys;

/**
 Set of parameter keys that will be submitted to the URL's query string.
 */
@property (nonatomic, copy) NSSet *queryStringKeys;

/**
 Sets an arbitrary parameter value for the given key.  Only supports values that are capable of being sent over a
 network request, therefore any value other than NSString, NSNumber, NSDate, NSData, or NSFileWrapper will be rejected.

 @warning
 Throws an exception if the key is not a valid string, or if the object being supplied cannot be mutated in such a way
 as to allow it to be posted to the server.

 @param object Value to set.
 @param key    Key, or parameter name, to use for this value.
 */
- (void)setObject:(id)object forKey:(NSString*)key;

/**
 Sets an object with a filename and mime type.  This is similar to setObject:forKey:
 
 @discussion
 This can be used as a convenient way to set an object and its filename/mimetype with a single call.

 @param object   The object to set.
 @param key      The form key to set the value to.
 @param filename The optional filename.
 @param mimeType The optional mimetype.
 
 @see setObject:forKey:
 @see setFileName:forKey:
 @see setMimeType:forKey:
 */
- (void)setObject:(id)object forKey:(NSString*)key filename:(NSString*)filename mimeType:(NSString*)mimeType;

/**
 Returns the parameter object for the given key.

 @param key The key to fetch a value for.

 @return The object for that key, or `nil` if no object found.
 */
- (id)objectForKey:(NSString*)key;

/**
 Returns the mime type assigned to the object with the given key.

 @param key The key to fetch a mimetype for.

 @return The mime type assigned to this key, or `nil` if none has been assigned.
 */
- (NSString*)mimeTypeForKey:(NSString*)key;

/**
 Set the mime type for the given key.

 @param mimeType Type to set.
 @param key      The key to associate the mimetype with.
 */
- (void)setMimeType:(NSString*)mimeType forKey:(NSString*)key;

/**
 Returns the filename assigned to the object with the given key.

 @param key The key to fetch the filename for.

 @return The filename assigned to this key, or `nil` if none has been assigned.
 */
- (NSString*)fileNameForKey:(NSString*)key;

/**
 Sets the file name for the object with the given key.

 @param fileName The filename to set.
 @param key      The key to associate the filename with.
 */
- (void)setFileName:(NSString*)fileName forKey:(NSString*)key;

@end

@interface CSFParameterStorage (KeyedSubscript)

- (id)objectForKeyedSubscript:(NSString*)key;
- (void)setObject:(id)obj forKeyedSubscript:(NSString*)key;

@end

