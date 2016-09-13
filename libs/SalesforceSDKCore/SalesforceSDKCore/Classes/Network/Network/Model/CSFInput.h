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
#import "CSFAvailability.h"
#import "CSFActionInput.h"

/**
 Instances of this class can be used as the input model for complex POST or PATCH network requests.
 
 When complex JSON data structures need to be submitted to network requests, instead of formulating
 requests manually, which can be error-prone, instances or subclasses of CSFInput may be used to 
 describe the structure of those reqests.
 
 All properties are mutable, and should conform to NSCopying.  This permits these models to be used
 to describe real-time user input, and ensures that data can be copied when a network request is
 initiated.
 */
@interface CSFInput : NSObject <NSSecureCoding, NSCopying, CSFActionInput>

/** Returns a boolean value that indicates whether a given model object is equal to the receiver.
 
 Not everything is guaranteed to be checked, but it attempts to compare as much of the properties as it can.
 Subclasses of this this class all augment this behavior to compare against their own additions to this class.
 
 @param model The model object to compare to the receiver.
 @return `YES` if `model` is equal to the receiver (if the properties of this and its child objects match), otherwise `NO`.
 */
- (BOOL)isEqualToInput:(CSFInput*)model;

@end

@interface CSFInput (KeyedSubscript)

- (id)objectForKeyedSubscript:(id)key;
- (void)setObject:(id)obj forKeyedSubscript:(id <NSCopying>)key;

@end

@interface CSFInput (DynamicProperties)

/** Method indicating whether or not to accept arbitrary key/value properties to be set on input models.
 
 @discussion
 Subclasses of CSFInput may override this method to allow custom properties to be added, above and beyond what are declared as Objective-C property declarations
 */
+ (BOOL)allowsCustomAttributes;

/** Returns the storage key used for JSON serialization for the given property name.
 
 @discussion
 This class method lets developers use a different Objective-C property name than the
 value used when serializing and submitting JSON data to a network API.  This can often
 be used to adjust capitalization or underscore encoding.
 
 @note The default implementation returns the property name unaltered.  If the method returns
 `nil`, then no properties for the given name will be serialized into JSON.
 
 @param propertyName The name of the Objective-C property.
 @return The storage key to use when serializing JSON.
 */
+ (NSString*)storageKeyForPropertyName:(NSString*)propertyName;

@end
