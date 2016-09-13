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

#import "CSFActionModel.h"
#import "CSFDefines.h"

/** The `CSFOutput` class declares the basis for all network responses.
 Each response from REST APIs is a set of structured data describing the response to
 a particular request.  Because this data is structured, the client-side representation
 of these responses needs to be structured too. This class and its subclasses provide the
 capability to encode and expose the data provided from server resources to client code.
 */
@interface CSFOutput : NSObject <NSSecureCoding, NSCopying, CSFActionModel>

- (instancetype)init NS_DESIGNATED_INITIALIZER;

/** Designated initializer to construct a model object from its JSON representation.

 @param json    Dictionary of structured data from the network.
 @param context Dictionary of relevant information about the request and the action that performed it.
 @return Initialized model object.
 */
- (instancetype)initWithJSON:(NSDictionary*)json context:(NSDictionary*)context NS_DESIGNATED_INITIALIZER;

/** Returns a boolean value that indicates whether a given model object is equal to the receiver.

 Not everything is guaranteed to be checked, but it attempts to compare as much of the properties as it can.
 Subclasses of this this class all augment this behavior to compare against their own additions to this class.

 @param model The model object to compare to the receiver.
 @return `YES` if `model` is equal to the receiver (if the properties of this and its child objects match), otherwise `NO`.
 */
- (BOOL)isEqualToOutput:(CSFOutput*)model;

@end

@interface CSFOutput (Ancestry)

/**
 This property exposes the parent object to the receiver, as a weak reference.
 
 @discussion
 This property is automatically populated as a process of either initializing the object using -[CSFActionModel initWithJSON:context:], or though NSCoding decoding methods.  This property can safely be used without causing retain cycles, and is a convenient way to traverse an object graph.
 */
@property (nonatomic, weak, readonly) NSObject *parentObject;

@end

@interface CSFOutput (KeyedSubscript)

- (id)objectForKeyedSubscript:(id)key;
- (void)setObject:(id)obj forKeyedSubscript:(id <NSCopying>)key;

@end

@interface CSFOutput (DynamicProperties)

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
+ (NSString*)storageKeyPathForPropertyName:(NSString*)propertyName;

/** Returns a BOOL value indicating if the propertyName specified will store the contents of Array.
 
 @discussion
 This class method lets developers specify the default property to be used when the object is instantiated with
 a JSON Array. You can continue to use the "actionModelForPropertyName:propertyClass:contents:" method to speciify the types of objects that will be stored in the
 array.
 
 @note in order to use this class method your object must be instantiated with an NSArray in the designater initializer "json" parameter. you must also ensure you return yes for only one of the properties of type NSArray.
 
 @param propertyName The name of the Objective-C property whose type will be NSArray.
 @return a BOOL value indicatind if the passed in property name is default.
 */

+ (BOOL)isDefaultPropertyForArray:(NSString *)propertyName;

/** Returns the underlying class type for a dynamic property, if it isn't clear from the property description.
 
 @discussion
 This method can be used by subclasses of CSFOutput to declare what type of action model should be declared for
 the indicated content.  This is only invoked for properties that are either container objects (for example
 NSArray or NSDictionary property types) or for properties that have already been described as instances of
 CSFActionModel to allow for polymorphism.
 
 @property propertyName  The name of the property.
 @property propertyClass The class that is declared on the `@property` declaration.
 @property contents      The JSON objects for the derived property contents.
 @return Class conforming to CSFActionModel, or `nil` if the contents should not be composed as a CSFActionModel instance.
 */
+ (Class<CSFActionModel>)actionModelForPropertyName:(NSString*)propertyName propertyClass:(Class)originalClass contents:(id)contents;

/** Method used to transform an existing property to some other form on an as-needed basis.
 
 @discussion
 In some circumstances, the JSON values returned from a REST API are not directly consumable, or aren't convenient, to consume
 in their original forms.  String components joined by a separator may be easier to consume as an array, or strings that are better
 represented as an NSDate instance.
 
 The default implementation of this method automatically converts strings as needed to NSDate, NSURL, or other values.  Subclasses may
 override this method to provide customized formatters for incoming properties based on the name, class, and value.
 
 As an alternative to this method, subclasses may implement a function that conforms to a selector based on the name of the property.  For example, a property named "fullName" may declare a method `- (id)transformFullName:(id)value`
 @warning
 It is important that subclasses always invoke [super transformedValueForProperty:propertyClass:value:] if the subclassed method cannot
 handle the property or value supplied.
 
 @property propertyName  Name of the property.
 @property propertyClass Declared class for the property.
 @property value         Original value from the JSON input for this property.
 @return Transformed value for the incoming property, or the original value if no transformation is needed.
 */
- (id)transformedValueForProperty:(NSString*)propertyName propertyClass:(Class)propertyClass value:(id)value;

/** Class method that returns a function pointer capable of transforming primitive values for the given encoding type.
 
 @description
 Transforming primitive values can be complicated, particularly due to performance and type encoding reasons.  For this reason,
 allows subclasses to transform incoming `id` values to primitive types by exchanging function pointers and value typedefs.  The default
 implementation handles transformation of the basic primitive types (char, short, long, float, etc).
 
 Subclasses can override this method to declare custom transformers.  Examples of transformers can be to convert number ranges to discrete values, string values to enum values, etc.

 @warning
 It is important that subclasses always invoke [super transformedValueForProperty:propertyClass:value:] if the subclassed method cannot
 handle the property or value supplied.
 
 @property propertyName Name for the primitive property
 @property encodingType The `const char *` encoding type for the primitive property.
 @return Pointer to a C function capable of transforming this property to a primitive type.
 */
+ (CSFPrimitiveFormatterPtr)actionModelFormatterForPrimitiveProperty:(NSString*)propertyName encodingType:(const char *)encodingType;

@end
