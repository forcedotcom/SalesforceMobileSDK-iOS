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

/**
 Object that represents an individual element within a multipart stream, used for the request body of a network action.
 
 @discussion
 This object is intended to remain private, and is not meant for public consumption.  This is internally referenced by the
 CSFMultipartInputStream class as a way to break up individual elements of a request body into discrete components, and to
 abstract out the serialization of large requests into streamable segments.
 
 This class attempts to autodetect the object type, and will transform it into the desired output format.  All input elements
 must be decomposable into NSData objects, and any object that's unable to do so will be rejected.  Currently the list of
 object types that can be transformed are:
 
   - NSData (no change)
   - NSString (transformed to UTF8)
   - NSDate (transformed to an ISO8601 date, encoded as UTF8)
   - NSURL (transformed to an UTF8 absolute URL)
 */
@interface CSFInputStreamElement : NSObject

@property (nonatomic, strong, readonly) id object;
@property (nonatomic, strong, readonly) NSString *boundary;
@property (nonatomic, copy, readonly) NSString *key;
@property (nonatomic, copy, readonly) NSString *mimeType;
@property (nonatomic, copy, readonly) NSString *filename;
@property (nonatomic, assign, readonly) NSUInteger headerLength;
@property (nonatomic, assign, readonly) NSUInteger bodyLength;
@property (nonatomic, assign, readonly) NSUInteger length;
@property (nonatomic, assign, readonly) NSUInteger delivered;

- (instancetype)init NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithObject:(id)object boundary:(NSString*)boundary key:(NSString*)key NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithObject:(id)object boundary:(NSString*)boundary key:(NSString*)key transformer:(NSValueTransformer*)transformer NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithObject:(id)object boundary:(NSString*)boundary key:(NSString*)key mimeType:(NSString*)mimeType filename:(NSString*)filename NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithObject:(id)object boundary:(NSString*)boundary key:(NSString*)key transformer:(NSValueTransformer*)transformer mimeType:(NSString*)mimeType filename:(NSString*)filename NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithStream:(NSInputStream*)stream boundary:(NSString*)boundary key:(NSString*)key mimeType:(NSString*)mimeType filename:(NSString*)filename streamLength:(NSUInteger)streamLength NS_DESIGNATED_INITIALIZER;

/**
 Internal method used by CSFMultipartInputStream to handle reading data from individual elements.

 @param buffer Buffer to read data into.
 @param len    The maximum amount of data to read.

 @return A number indicating the outcome of the operation
   * A positive number indicates the number of bytes read;
   * 0 indicates that the end of the buffer was reached;
   * A negative number means that the operation failed.
 */
- (NSUInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)len;

@end
