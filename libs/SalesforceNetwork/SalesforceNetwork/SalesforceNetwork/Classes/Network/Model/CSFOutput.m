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

#import "CSFOutput_Internal.h"

#import "CSFDefines.h"
#import "CSFInternalDefines.h"

static NSString * const kCSFInputCustomDictionaryAttributes = @"__CSFOutput_Dictionary_Storage";
static NSString * const kCSFInputCustomArrayAttributes = @"__CSFOutput_Array_Storage";

@implementation CSFOutput

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype)init {
    self = [super init];
    return self;
}

- (instancetype)initWithJSON:(id)json context:(NSDictionary *)context {
    self = [super init];
    if (self) {
        __context = context;
        __remainingProperties = [CSFClassProperties(self.class) mutableCopy];
        
        if ([json isKindOfClass:[NSDictionary class]]) {
            __dictionaryStorage = [CSFNotNullDictionary(json) mutableCopy];
            [self importSynthesizedProperties];
        } else if ([json isKindOfClass:[NSArray class]]) {
            __arrayStorage = [CSFNotNullArray(json) mutableCopy];
            [self importSynthesizedPropertyForArray];
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder*)encoder {
    [self importAllProperties];
    
    [encoder encodeObject:__dictionaryStorage forKey:kCSFInputCustomDictionaryAttributes];
    [encoder encodeObject:__arrayStorage forKey:kCSFInputCustomArrayAttributes];
    
    NSDictionary *ivars = CSFClassIvars(self.class);
    [ivars enumerateKeysAndObjectsUsingBlock:^(NSString *ivarName, NSDictionary *ivarInfo, BOOL *stop) {
        NSString *propertyName = ([ivarName rangeOfString:@"_"].location == 0) ? [ivarName substringFromIndex:1] : ivarName;

        Ivar ivar = class_getInstanceVariable(ivarInfo[@"class"], [ivarName UTF8String]);
        Class ivarClass = CSFClassFromEncoding(ivarInfo[@"encoding"]);
        if (ivarClass) {
            id value = object_getIvar(self, ivar);
            [encoder encodeObject:value forKey:propertyName];
        } else if (ivarInfo[@"encoding"]) {
            const void * ivarPtr = (__bridge void*)(self) + ivar_getOffset(ivar);
            [encoder encodeValueOfObjCType:[ivarInfo[@"encoding"] UTF8String] at:ivarPtr];
        }
    }];
}

- (id)initWithCoder:(NSCoder*)decoder {
    self = [self init];
    if (self) {
        __dictionaryStorage = [[decoder decodeObjectOfClass:[NSDictionary class] forKey:kCSFInputCustomDictionaryAttributes] mutableCopy];
        __arrayStorage = [[decoder decodeObjectOfClass:[NSArray class] forKey:kCSFInputCustomArrayAttributes] mutableCopy];
        
        NSDictionary *ivars = CSFClassIvars(self.class);
        [ivars enumerateKeysAndObjectsUsingBlock:^(NSString *ivarName, NSDictionary *ivarInfo, BOOL *stop) {
            NSString *propertyName = CSFPropertyNameFromIvarName(ivarName);
            
            Ivar ivar = class_getInstanceVariable(ivarInfo[@"class"], [ivarName UTF8String]);
            Class ivarClass = CSFClassFromEncoding(ivarInfo[@"encoding"]);
            if (ivarClass) {
                id result = [decoder decodeObjectOfClass:ivarClass forKey:propertyName];
                if ([result isKindOfClass:[CSFOutput class]]) {
                    CSFOutput *resultOutput = (CSFOutput*)result;
                    resultOutput.parentObject = self;
                }
                object_setIvar(self, ivar, result);
            } else if (ivarInfo[@"encoding"]) {
                const void * ivarPtr = (__bridge void*)(self) + ivar_getOffset(ivar);
                [decoder decodeValueOfObjCType:[ivarInfo[@"encoding"] UTF8String] at:(void *)ivarPtr];
            }
        }];
    }
    return self;
}

- (NSString*)description {
    NSMutableArray *components = [NSMutableArray arrayWithObject:[NSString stringWithFormat:@"%p", self]];
    for (NSString *ivar in CSFClassIvars(self.class)) {
        if ([ivar hasPrefix:@"__"]) continue;
        
        NSString *property = CSFPropertyNameFromIvarName(ivar);
        
        id value = [self valueForKey:property];
        
        NSString *result = nil;
        if ([value isKindOfClass:[NSString class]] || [value isKindOfClass:[NSNumber class]]) {
            result = [NSString stringWithFormat:@"%@=%@", property, value];
        } else if ([value conformsToProtocol:@protocol(NSFastEnumeration)]) {
            result = [NSString stringWithFormat:@"%@=%@", property, value];
        } else if (value) {
            result = [NSString stringWithFormat:@"%@=%p", property, value];
        } else {
            result = [NSString stringWithFormat:@"%@=(null)", property];
        }

        [components addObject:result];
    }
    
    return [NSString stringWithFormat:@"<%@: %@>",
            NSStringFromClass(self.class), [components componentsJoinedByString:@", "]];
}

- (void)importAllProperties {
    if (__allPropertiesImported) return;
    
    // Expand properties to their target values
    NSArray *properties = [__remainingProperties copy];
    for (NSString *propertyName in properties) {
        [self importProperty:propertyName];
    }
}

- (void)importSynthesizedPropertyForArray {
    if (__allPropertiesImported) return;
    
    NSDictionary *context = __context;
    NSDictionary *ivars = CSFClassIvars(self.class);
    
    // Expand properties to their target values
    NSArray *properties = [__remainingProperties copy];
    
    for (NSString *propertyName in properties) {
        
        NSDictionary *info = CSFPropertyAttributes(self.class, propertyName);
        Class propertyClass = info[CSFPropertyClassKey];
        
        if ([propertyClass isSubclassOfClass:[NSArray class]]) {
            if ([[self class] isDefaultPropertyForArray:propertyName]) {
                
                NSDictionary *info = CSFPropertyAttributes(self.class, propertyName);
                Method getterMethod = class_getInstanceMethod(self.class, NSSelectorFromString(info[CSFPropertyGetterNameKey]));
                if (getterMethod) {
                    
                    NSArray *sourceArray = __arrayStorage;
                    NSMutableArray *array = [NSMutableArray arrayWithCapacity:sourceArray.count];
                    [sourceArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                        Class itemClass = [self.class actionModelForPropertyName:propertyName propertyClass:propertyClass contents:obj];
                        if ([itemClass conformsToProtocol:@protocol(CSFActionModel)]) {
                            NSObject<CSFActionModel> *resultItem = [[itemClass alloc] initWithJSON:obj context:context];
                            if (resultItem) {
                                if ([resultItem isKindOfClass:[CSFOutput class]]) {
                                    CSFOutput *resultItemOutput = (CSFOutput*)resultItem;
                                    resultItemOutput.parentObject = self;
                                }
                            } else {
                                resultItem = (NSObject<CSFActionModel>*)[NSNull null];
                            }
                            
                            [array addObject:resultItem];
                        } else {
                            [array addObject:obj];
                        }
                    }];
                    
                    NSArray *storeValue = [NSArray arrayWithArray:array];
                    
                    // Check to see if an ivar exists for this property
                    NSString *ivarName = [NSString stringWithFormat:@"_%@", propertyName];
                    NSDictionary *ivarInfo = ivars[ivarName];
                    if (ivarInfo) {
                        Ivar ivar = class_getInstanceVariable(ivarInfo[@"class"], [ivarName UTF8String]);
                        
                        Class ivarClass = CSFClassFromEncoding(ivarInfo[@"encoding"]);
                        if (ivarClass) {
                            if ([propertyClass isSubclassOfClass:ivarClass]) {
                                object_setIvar(self, ivar, storeValue);
                            }
                        }
                    } else if (storeValue) {
                        [__arrayStorage removeAllObjects];
                        [__arrayStorage addObjectsFromArray:storeValue];
                    }
                }
            }
        }
        
        [self markPropertyCompleted:propertyName];
    }
}

- (void)importSynthesizedProperties {
    if (__allPropertiesImported) return;
    
    // Expand properties to their target values
    NSArray *properties = [__remainingProperties copy];
    for (NSString *propertyName in properties) {
        NSDictionary *info = CSFPropertyAttributes(self.class, propertyName);
        Method getterMethod = class_getInstanceMethod(self.class, NSSelectorFromString(info[CSFPropertyGetterNameKey]));
        if (getterMethod) {
            [self importProperty:propertyName];
        }
    }
}


- (void)markPropertyCompleted:(NSString*)propertyName {
    @synchronized (__remainingProperties) {
        [__remainingProperties removeObject:propertyName];
        if (__remainingProperties.count == 0) {
            __allPropertiesImported = YES;
            __remainingProperties = nil;
        }
    }
}

- (void)importProperty:(NSString*)propertyName {
    if (__allPropertiesImported || ![__remainingProperties containsObject:propertyName]) return;
    
    NSDictionary *ivars = CSFClassIvars(self.class);
    
    NSString *storageKey = [self.class storageKeyPathForPropertyName:propertyName];
    if (!storageKey) {
        [self markPropertyCompleted:propertyName];
        return;
    }
    
    id storeValue = nil;
    id sourceJson = [__dictionaryStorage valueForKeyPath:storageKey];
    if ([sourceJson isEqual:[NSNull null]]) {
        sourceJson = nil;
    }
    
    if (!sourceJson)  {
        [self markPropertyCompleted:propertyName];
        return;
    }
    
    NSDictionary *info = CSFPropertyAttributes(self.class, propertyName);
    Class propertyClass = info[CSFPropertyClassKey];
    
    // For id-type objects, ensure that relationships to other CSFActionModel instances are propertly mapped
    if (propertyClass) {
        NSDictionary *context = __context;

        BOOL isArray = [propertyClass isSubclassOfClass:[NSArray class]];
        BOOL isDictionary = [propertyClass isSubclassOfClass:[NSDictionary class]];
        if (isArray || isDictionary || [propertyClass conformsToProtocol:@protocol(CSFActionModel)]) {
            Class modelClass = [self.class actionModelForPropertyName:propertyName propertyClass:propertyClass contents:sourceJson];
            if ([modelClass conformsToProtocol:@protocol(CSFActionModel)]) {
                
                // If the object is an array, then the model class should apply to each instance within it
                if (isArray && [sourceJson isKindOfClass:[NSArray class]]) {
                    NSArray *sourceArray = (NSArray*)sourceJson;
                    NSMutableArray *array = [NSMutableArray arrayWithCapacity:sourceArray.count];
                    [sourceArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                        Class itemClass = [self.class actionModelForPropertyName:propertyName propertyClass:propertyClass contents:obj];
                        if ([itemClass conformsToProtocol:@protocol(CSFActionModel)]) {
                            NSObject<CSFActionModel> *resultItem = [[itemClass alloc] initWithJSON:obj context:context];
                            if (resultItem) {
                                if ([resultItem isKindOfClass:[CSFOutput class]]) {
                                    CSFOutput *resultItemOutput = (CSFOutput*)resultItem;
                                    resultItemOutput.parentObject = self;
                                }
                            } else {
                                resultItem = (NSObject<CSFActionModel>*)[NSNull null];
                            }
                            
                            [array addObject:resultItem];
                        } else {
                            [array addObject:obj];
                        }
                    }];
                    
                    storeValue = [NSArray arrayWithArray:array];
                }
                
                // If the object is a dictionary, then the model class should apply to each instance within it
                else if (isDictionary && [sourceJson isKindOfClass:[NSDictionary class]]) {
                    NSDictionary *sourceDict = (NSDictionary*)sourceJson;
                    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:sourceDict.count];
                    [sourceDict enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                        Class itemClass = [self.class actionModelForPropertyName:propertyName propertyClass:propertyClass contents:obj];
                        if ([itemClass conformsToProtocol:@protocol(CSFActionModel)]) {
                            NSObject<CSFActionModel> *resultItem = [[itemClass alloc] initWithJSON:obj context:context];
                            if (resultItem) {
                                if ([resultItem isKindOfClass:[CSFOutput class]]) {
                                    CSFOutput *resultItemOutput = (CSFOutput*)resultItem;
                                    resultItemOutput.parentObject = self;
                                }
                            } else {
                                resultItem = (NSObject<CSFActionModel>*)[NSNull null];
                            }
                            
                            dict[key] = resultItem;
                        } else {
                            dict[key] = obj;
                        }
                    }];
                    
                    storeValue = [NSDictionary dictionaryWithDictionary:dict];
                }
                
                // If it's just a plain object...
                else {
                    Class itemClass = [self.class actionModelForPropertyName:propertyName propertyClass:propertyClass contents:sourceJson];
                    if ([itemClass conformsToProtocol:@protocol(CSFActionModel)]) {
                        NSObject<CSFActionModel> *resultItem = [[itemClass alloc] initWithJSON:sourceJson context:context];
                        if (resultItem) {
                            if ([resultItem isKindOfClass:[CSFOutput class]]) {
                                CSFOutput *resultItemOutput = (CSFOutput*)resultItem;
                                resultItemOutput.parentObject = self;
                            }
                        } else {
                            resultItem = (NSObject<CSFActionModel>*)[NSNull null];
                        }
                        storeValue = resultItem;
                    }
                }
            }
        } else {
            SEL transformSelector = NSSelectorFromString([NSString stringWithFormat:@"transform%@%@Value:",
                                                          [[propertyName substringToIndex:1] uppercaseString],
                                                          [propertyName substringFromIndex:1]]);
            if ([self respondsToSelector:transformSelector]) {
                IMP method = [self methodForSelector:transformSelector];
                id (*func)(id, SEL, id) = (void *)method;
                storeValue = func(self, transformSelector, sourceJson);
            } else {
                storeValue = [self transformedValueForProperty:propertyName propertyClass:propertyClass value:sourceJson];
            }
        }
    }
    
    // Check to see if an ivar exists for this property
    NSString *ivarName = [NSString stringWithFormat:@"_%@", propertyName];
    NSDictionary *ivarInfo = ivars[ivarName];
    if (ivarInfo) {
        Ivar ivar = class_getInstanceVariable(ivarInfo[@"class"], [ivarName UTF8String]);
        
        Class ivarClass = CSFClassFromEncoding(ivarInfo[@"encoding"]);
        if (ivarClass) {
            if ([propertyClass isSubclassOfClass:ivarClass]) {
                object_setIvar(self, ivar, storeValue ?: sourceJson);
                
                // Only remove the JSON from local storage if it's not a keypath
                if ([storageKey rangeOfString:@"."].location == NSNotFound) {
                    [__dictionaryStorage removeObjectForKey:storageKey];
                }
            }
        } else if (ivarInfo[@"encoding"]) {
            const char * encodingType = [ivarInfo[@"encoding"] UTF8String];
            CSFPrimitiveFormatterPtr formatterFunc = [self.class actionModelFormatterForPrimitiveProperty:propertyName
                                                                                             encodingType:encodingType];
            if (formatterFunc != NULL) {
                CSFPrimitivePointer outputPtr = {0};
                
                if (strcmp(encodingType, @encode(int)) == 0) {
                    outputPtr.intPtr = (int *)((__bridge void*)(self) + ivar_getOffset(ivar));
                } else if (strcmp(encodingType, @encode(unsigned int)) == 0) {
                    outputPtr.unsignedIntPtr = (unsigned int *)((__bridge void*)(self) + ivar_getOffset(ivar));
                } else if (strcmp(encodingType, @encode(BOOL)) == 0) {
                    outputPtr.boolPtr = (BOOL *)((__bridge void*)(self) + ivar_getOffset(ivar));
                } else if (strcmp(encodingType, @encode(NSInteger)) == 0) {
                    outputPtr.integerPtr = (NSInteger *)((__bridge void*)(self) + ivar_getOffset(ivar));
                } else if (strcmp(encodingType, @encode(NSUInteger)) == 0) {
                    outputPtr.unsignedIntegerPtr = (NSUInteger *)((__bridge void*)(self) + ivar_getOffset(ivar));
                } else if (strcmp(encodingType, @encode(float)) == 0) {
                    outputPtr.floatPtr = (float *)((__bridge void*)(self) + ivar_getOffset(ivar));
                } else if (strcmp(encodingType, @encode(double)) == 0) {
                    outputPtr.doublePtr = (double *)((__bridge void*)(self) + ivar_getOffset(ivar));
                } else if (strcmp(encodingType, @encode(char)) == 0) {
                    outputPtr.charPtr = (char *)((__bridge void*)(self) + ivar_getOffset(ivar));
                } else if (strcmp(encodingType, @encode(unsigned char)) == 0) {
                    outputPtr.unsignedCharPtr = (unsigned char *)((__bridge void*)(self) + ivar_getOffset(ivar));
                } else if (strcmp(encodingType, @encode(short)) == 0) {
                    outputPtr.shortPtr = (short *)((__bridge void*)(self) + ivar_getOffset(ivar));
                } else if (strcmp(encodingType, @encode(unsigned short)) == 0) {
                    outputPtr.unsignedShortPtr = (unsigned short *)((__bridge void*)(self) + ivar_getOffset(ivar));
                } else if (strcmp(encodingType, @encode(long)) == 0) {
                    outputPtr.longPtr = (long *)((__bridge void*)(self) + ivar_getOffset(ivar));
                } else if (strcmp(encodingType, @encode(unsigned long)) == 0) {
                    outputPtr.unsignedLongPtr = (unsigned long *)((__bridge void*)(self) + ivar_getOffset(ivar));
                } else if (strcmp(encodingType, @encode(long long)) == 0) {
                    outputPtr.longLongPtr = (long long *)((__bridge void*)(self) + ivar_getOffset(ivar));
                } else if (strcmp(encodingType, @encode(unsigned long long)) == 0) {
                    outputPtr.unsignedLongLongPtr = (unsigned long long *)((__bridge void*)(self) + ivar_getOffset(ivar));
                }
                
                formatterFunc(storeValue ?: sourceJson, outputPtr);
            }
        }
    } else if (storeValue) {
        [__dictionaryStorage setValue:storeValue forKeyPath:storageKey];
    }
    
    [self markPropertyCompleted:propertyName];
}

#pragma mark Public customization overrides

+ (BOOL)isDefaultPropertyForArray:(NSString *)propertyName {
    return YES;
}

+ (NSString*)storageKeyPathForPropertyName:(NSString*)propertyName {
    return propertyName;
}

+ (Class<CSFActionModel>)actionModelForPropertyName:(NSString*)propertyName propertyClass:(Class)originalClass contents:(id)contents {
    Class<CSFActionModel> result = nil;
    if ([originalClass conformsToProtocol:@protocol(CSFActionModel)]) {
        result = (Class<CSFActionModel>)originalClass;
    }
    return result;
}

+ (CSFPrimitiveFormatterPtr)actionModelFormatterForPrimitiveProperty:(NSString*)propertyName encodingType:(const char *)encodingType {
    CSFPrimitiveFormatterPtr result = NULL;

    if (strcmp(encodingType, @encode(int)) == 0) {
        result = CSFPrimitiveIntFormatter;
    } else if (strcmp(encodingType, @encode(unsigned int)) == 0) {
        result = CSFPrimitiveUnsignedIntFormatter;
    } else if (strcmp(encodingType, @encode(BOOL)) == 0) {
        result = CSFPrimitiveBooleanFormatter;
    } else if (strcmp(encodingType, @encode(NSInteger)) == 0) {
        result = CSFPrimitiveIntegerFormatter;
    } else if (strcmp(encodingType, @encode(NSUInteger)) == 0) {
        result = CSFPrimitiveUnsignedIntegerFormatter;
    } else if (strcmp(encodingType, @encode(float)) == 0) {
        result = CSFPrimitiveFloatFormatter;
    } else if (strcmp(encodingType, @encode(double)) == 0) {
        result = CSFPrimitiveDoubleFormatter;
    } else if (strcmp(encodingType, @encode(char)) == 0) {
        result = CSFPrimitiveCharFormatter;
    } else if (strcmp(encodingType, @encode(unsigned char)) == 0) {
        result = CSFPrimitiveUnsignedCharFormatter;
    } else if (strcmp(encodingType, @encode(short)) == 0) {
        result = CSFPrimitiveShortFormatter;
    } else if (strcmp(encodingType, @encode(unsigned short)) == 0) {
        result = CSFPrimitiveUnsignedShortFormatter;
    } else if (strcmp(encodingType, @encode(long)) == 0) {
        result = CSFPrimitiveLongFormatter;
    } else if (strcmp(encodingType, @encode(unsigned long)) == 0) {
        result = CSFPrimitiveUnsignedLongFormatter;
    } else if (strcmp(encodingType, @encode(long long)) == 0) {
        result = CSFPrimitiveLongLongFormatter;
    } else if (strcmp(encodingType, @encode(unsigned long long)) == 0) {
        result = CSFPrimitiveUnsignedLongLongFormatter;
    }
    
    return result;
}

- (id)transformedValueForProperty:(NSString*)propertyName propertyClass:(Class)propertyClass value:(id)value {
    id result = value;

    if ([propertyClass isSubclassOfClass:[NSDate class]]) {
        result = CSFNotNullDate(value);
    }

    else if ([propertyClass isSubclassOfClass:[NSURL class]]) {
        NSURL *baseUrl = __context[@"serverURL"];
        if (baseUrl) {
            result = CSFNotNullURLRelative(value, baseUrl);
        } else {
            result = CSFNotNullURL(value);
        }
    }

    else if ([propertyClass isSubclassOfClass:[NSString class]]) {
        result = CSFNotNullString(value);
    }

    else if ([propertyClass isSubclassOfClass:[NSNumber class]]) {
        result = CSFNotNullNumber(value);
    }
    return result;
}

#pragma mark NSObject accessors

- (BOOL)isEqual:(id)object {
    if ([object isKindOfClass:[CSFOutput class]]) {
        return [self isEqualToOutput:(CSFOutput *)object];
    } else {
        return NO;
    }
}

- (id)copyWithZone:(NSZone *)zone {
    id theCopy = nil;
    
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self];
    
    if (data)
        theCopy = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    
    return theCopy;
}

- (NSUInteger)hash {
    [self importAllProperties];
    
    __block NSUInteger result = 17;

    NSDictionary *ivars = CSFClassIvars(self.class);
    NSArray *properties = CSFClassProperties(self.class);
    const void * selfPtr = (__bridge void*)(self);
    
    [properties enumerateObjectsUsingBlock:^(NSString *propertyName, NSUInteger idx, BOOL *stop) {
        NSString *ivarName = [NSString stringWithFormat:@"_%@", propertyName];
        NSDictionary *ivarInfo = ivars[ivarName];

        if (ivarInfo) {
            Ivar ivar = class_getInstanceVariable(ivarInfo[@"class"], [ivarName UTF8String]);
            Class ivarClass = CSFClassFromEncoding(ivarInfo[@"encoding"]);
            
            NSObject *object = nil;
            if (ivarClass) {
                object = object_getIvar(self, ivar);
            } else if (ivarInfo[@"encoding"]) {
                const void * ivarPtr = selfPtr + ivar_getOffset(ivar);
                const char * encoding = [ivarInfo[@"encoding"] UTF8String];
                object = [NSValue value:ivarPtr withObjCType:encoding];
            }
            
            if ([object isKindOfClass:[NSObject class]]) {
                result ^= object.hash + result * 37;
            }
        } else {
            NSDictionary *propertyInfo = CSFPropertyAttributes(self.class, propertyName);
            NSObject *object = nil;
            if (propertyInfo[CSFPropertyClassKey]) {
                object = [self valueForKey:propertyName];
            }
            result ^= object.hash + result * 37;
        }
    }];
    
    return result;
}

- (BOOL)isEqualToOutput:(CSFOutput*)model {
    if (self == model)
        return YES;
    
    if (![model isKindOfClass:self.class])
        return NO;
    
    __block BOOL result = YES;
    NSDictionary *ivars = CSFClassIvars(self.class);
    NSArray *properties = CSFClassProperties(self.class);
    [properties enumerateObjectsUsingBlock:^(NSString *propertyName, NSUInteger idx, BOOL *stop) {
        NSString *ivarName = [NSString stringWithFormat:@"_%@", propertyName];
        NSDictionary *ivarInfo = ivars[ivarName];

        if (ivarInfo) {
            Ivar ivar = class_getInstanceVariable(ivarInfo[@"class"], [ivarName UTF8String]);
            Class ivarClass = CSFClassFromEncoding(ivarInfo[@"encoding"]);
            
            NSObject *leftObject = nil, *rightObject = nil;
            if (ivarClass) {
                leftObject = object_getIvar(self, ivar);
                rightObject = object_getIvar(model, ivar);
            } else if (ivarInfo[@"encoding"]) {
                const void * leftIvarPtr = (__bridge void*)(self) + ivar_getOffset(ivar);
                const void * rightIvarPtr = (__bridge void*)(model) + ivar_getOffset(ivar);
                
                const char * encoding = [ivarInfo[@"encoding"] UTF8String];
                leftObject = [NSValue value:leftIvarPtr withObjCType:encoding];
                rightObject = [NSValue value:rightIvarPtr withObjCType:encoding];
            }
            
            if (leftObject != rightObject && ![leftObject isEqual:rightObject]) {
                result = NO;
                *stop = YES;
            }
        } else {
            NSDictionary *propertyInfo = CSFPropertyAttributes(self.class, propertyName);
            if (propertyInfo[CSFPropertyClassKey]) {
                NSObject *leftObject = [self valueForKey:propertyName];
                NSObject *rightObject = [model valueForKey:propertyName];
                if ((leftObject || rightObject) && ![leftObject isEqual:rightObject]) {
                    result = NO;
                    *stop = YES;
                }
            } else {
                if ([self valueForKey:propertyName] != [model valueForKey:propertyName]) {
                    result = NO;
                    *stop = YES;
                }
            }
        }
    }];

    return result;
    
}

#pragma mark LLVM Subscript Handling

- (id)objectForKeyedSubscript:(id)key {
    return [self valueForKey:key];
}

#pragma mark KVC Handling

- (id)valueForUndefinedKey:(NSString *)key {
    id result = nil;
    if ([CSFClassProperties(self.class) containsObject:key]) {
        [self importProperty:key];
        result = __dictionaryStorage[key];
    } else if (__dictionaryStorage[key]) {
        result = __dictionaryStorage[key];
    } else {
        result = [super valueForUndefinedKey:key];
    }
    return result;
}

#pragma mark Dynamic property handling

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    NSString *propertyName = CSFPropertyNameFromSelector(selector);
    objc_property_t property = CSFPropertyWithName(self.class, propertyName);

    NSMethodSignature *result = nil;
    if (property) {
        NSString *methodName = NSStringFromSelector(selector);
        if ([methodName rangeOfString:@"set"].location == 0) {
            if (!CSFPropertyIsReadonly(property)) {
                result = [NSMethodSignature signatureWithObjCTypes:"v@:@"];
            }
        } else {
            result = [NSMethodSignature signatureWithObjCTypes:"@@:"];
        }
    }
    return result;
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    NSString *propertyName = CSFPropertyNameFromSelector(invocation.selector);
    objc_property_t property = CSFPropertyWithName(self.class, propertyName);

    NSString *key = NSStringFromSelector([invocation selector]);
    if ([key rangeOfString:@"set"].location == 0 && !CSFPropertyIsReadonly(property)) {
        key = [[key substringWithRange:NSMakeRange(3, [key length]-4)] lowercaseString];
        NSString *obj;
        [invocation getArgument:&obj atIndex:2];
        __dictionaryStorage[key] = obj;
    } else {
        [self importProperty:propertyName];
        
        id value = __dictionaryStorage[key];
        [invocation setReturnValue:&value];
    }
}

@end
