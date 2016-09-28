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

#import "CSFInput_Internal.h"
#import "CSFActionValue.h"

static NSString * const kCSFInputCustomAttributes = @"__CSFInput_CustomAttributes";

@implementation CSFInput

+ (BOOL)supportsSecureCoding {
    return YES;
}

+ (BOOL)allowsCustomAttributes {
    return NO;
}

+ (NSString*)storageKeyForPropertyName:(NSString*)propertyName {
    return propertyName;
}

- (void)encodeWithCoder:(NSCoder*)encoder {
    [encoder encodeObject:_storage forKey:kCSFInputCustomAttributes];
}

- (id)initWithCoder:(NSCoder*)decoder {
    self = [self init];
    if (self) {
        _storage = [[decoder decodeObjectOfClass:[NSDictionary class] forKey:kCSFInputCustomAttributes] mutableCopy];
    }
    return self;
}

- (NSString*)description {
    NSMutableArray *components = [NSMutableArray arrayWithObject:[NSString stringWithFormat:@"%p", self]];
    for (NSString *property in CSFClassProperties(self.class)) {
        if ([property isEqualToString:@"storage"]) continue;
        
        id value = [self valueForKey:property];

        NSString *result = nil;
        if ([value isKindOfClass:[NSString class]] || [value isKindOfClass:[NSNumber class]]) {
            result = [NSString stringWithFormat:@"%@=%@", property, value];
        } else if ([value conformsToProtocol:@protocol(NSFastEnumeration)]) {
            result = [NSString stringWithFormat:@"%@=%@", property, value];
        } else {
            result = [NSString stringWithFormat:@"%@=%p", property, value];
        }
        
        if (result) {
            [components addObject:result];
        }
    }
    
    return [NSString stringWithFormat:@"<%@: %@>",
            NSStringFromClass(self.class), [components componentsJoinedByString:@", "]];
}

#pragma mark Accessor Methods

- (NSDictionary*)JSONDictionary {
    NSDictionary *result = _storage;
    
    if (!result) {
        result = [NSDictionary new];
    }
    
    return result;
}

- (NSMutableDictionary*)storage {
    if (!_storage) {
        _storage = [NSMutableDictionary new];
    }
    return _storage;
}

#pragma mark Public Methods

- (NSData*)formatJSONData:(NSError **)error {
    NSJSONWritingOptions jsonOptions = 0;
#ifdef DEBUG
    jsonOptions = NSJSONWritingPrettyPrinted;
#endif
    
    NSDictionary *jsonDictionary = [[self JSONDictionary] copy];
    NSData *data = [NSJSONSerialization dataWithJSONObject:jsonDictionary
                                                   options:jsonOptions
                                                     error:error];

    return data;
}

+ (BOOL)dynamicImplementationForProperty:(NSString*)propertyName storageKey:(NSString*)storageKey attributes:(NSDictionary*)attributes getterImplementation:(IMP *)getterIMP setterImplementation:(IMP *)setterIMP {
    BOOL result = YES;

    Class propertyClass = attributes[CSFPropertyClassKey];
    if (propertyClass && class_conformsToProtocol(propertyClass, @protocol(CSFActionValue))) {
        *getterIMP = imp_implementationWithBlock(^NSObject<CSFActionValue> *(CSFInput *self) {
            return [self.storage[storageKey] actionValue];
        });
        *setterIMP = imp_implementationWithBlock(^(CSFInput *self, NSDate *value) {
            self.storage[storageKey] = [propertyClass decodedObjectForActionValue:value];
        });
    }
    
    // NSMutableArray properties
    else if (propertyClass == [NSMutableArray class]) {
        *getterIMP = imp_implementationWithBlock(^NSMutableArray *(CSFInput *self) {
            NSMutableArray *result = self.storage[storageKey];
            if (!result) {
                result = self.storage[storageKey] = [NSMutableArray new];
            }
            return result;
        });
        *setterIMP = imp_implementationWithBlock(^(CSFInput *self, NSMutableArray *value) {
            self.storage[storageKey] = value;
        });
    }
    
    // NSMutableDictionary properties
    else if (propertyClass == [NSMutableDictionary class]) {
        *getterIMP = imp_implementationWithBlock(^NSMutableDictionary *(CSFInput *self) {
            NSMutableDictionary *result = self.storage[storageKey];
            if (!result) {
                result = self.storage[storageKey] = [NSMutableDictionary new];
            }
            return result;
        });
        *setterIMP = imp_implementationWithBlock(^(CSFInput *self, NSMutableDictionary *value) {
            self.storage[storageKey] = value;
        });
    }
    
    // NSMutableString properties
    else if (propertyClass == [NSMutableString class]) {
        *getterIMP = imp_implementationWithBlock(^NSMutableString *(CSFInput *self) {
            NSMutableString *result = self.storage[storageKey];
            if (!result) {
                result = self.storage[storageKey] = [NSMutableString new];
            }
            return result;
        });
        *setterIMP = imp_implementationWithBlock(^(CSFInput *self, NSMutableString *value) {
            self.storage[storageKey] = value;
        });
    }
    
    // NSMutableAttributedString properties
    else if (propertyClass == [NSMutableAttributedString class]) {
        *getterIMP = imp_implementationWithBlock(^NSMutableAttributedString *(CSFInput *self) {
            NSMutableAttributedString *result = self.storage[storageKey];
            if (!result) {
                result = self.storage[storageKey] = [NSMutableAttributedString new];
            }
            return result;
        });
        *setterIMP = imp_implementationWithBlock(^(CSFInput *self, NSMutableAttributedString *value) {
            self.storage[storageKey] = value;
        });
    }
    
    else {
        result = NO;
    }
    
    return result;
}

#pragma mark NSObject accessors

- (NSUInteger)hash {
    NSUInteger result = 17;
    
    if (_storage)
        result ^= [_storage hash] + result * 37;
    
    return result;
}

- (BOOL)isEqual:(id)object {
    if ([object isKindOfClass:[CSFInput class]]) {
        return [self isEqualToInput:(CSFInput *)object];
    } else {
        return NO;
    }
}

- (BOOL)isEqualToInput:(CSFInput*)model {
    if (![model isKindOfClass:self.class])
        return NO;
    
    if (self == model)
        return YES;

    if (self.storage != model.storage && ![self.storage isEqualToDictionary:model.storage])
        return NO;

    return YES;
}

- (id)copyWithZone:(NSZone *)zone {
    id theCopy = nil;
    
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self];
    
    if (data)
        theCopy = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    
    return theCopy;
}

#pragma mark LLVM Subscript Handling

- (id)objectForKeyedSubscript:(id)key {
    return [self valueForKey:key];
}

- (void)setObject:(id)obj forKeyedSubscript:(id <NSCopying>)key {
    Class keyClass = object_getClass(key);
    if (keyClass == [NSString class] || [keyClass isSubclassOfClass:[NSString class]]) {
        NSString *copyingKey = (NSString*)key;
        [self setValue:obj forKey:copyingKey];
    }
}

#pragma mark KVC Handling

- (id)valueForUndefinedKey:(NSString *)key {
    id result = nil;
    
    if ([self.class allowsCustomAttributes]) {
        result = self.storage[key];
    } else {
        result = [super valueForUndefinedKey:key];
    }
    
    return result;
}

- (void)setValue:(id)value forUndefinedKey:(NSString *)key {
    if ([self.class allowsCustomAttributes] && (key && value)) {
        self.storage[key] = value;
    } else {
        [super setValue:value forUndefinedKey:key];
    }
}

#pragma mark Dynamic property handling

+ (BOOL)resolveInstanceMethod:(SEL)sel {
    NSString *propertyName = CSFPropertyNameFromSelector(sel);
    NSDictionary *info = CSFPropertyAttributes(self, propertyName);
    if (!info) {
        return [super resolveInstanceMethod:sel];
    }

    IMP getterIMP = NULL;
    IMP setterIMP = NULL;
    
    NSString *storageKey = [self storageKeyForPropertyName:propertyName];
    if (storageKey == nil) {
        return NO;
    }
    
    Class propertyClass = info[CSFPropertyClassKey];
    if (!propertyClass || ![self dynamicImplementationForProperty:propertyName
                                                       storageKey:storageKey
                                                       attributes:info
                                             getterImplementation:&getterIMP
                                             setterImplementation:&setterIMP])
    {
        const char * rawPropertyType = [info[CSFPropertyTypeKey] UTF8String];

        // BOOL primitives
        if (strcmp(rawPropertyType, @encode(BOOL)) == 0) {
            getterIMP = imp_implementationWithBlock(^BOOL(CSFInput *self) {
                return [self.storage[storageKey] boolValue];
            });
            setterIMP = imp_implementationWithBlock(^(CSFInput *self, BOOL value) {
                self.storage[storageKey] = @(value);
            });
        }
        
        // float primitives
        else if (strcmp(rawPropertyType, @encode(float)) == 0) {
            getterIMP = imp_implementationWithBlock(^float(CSFInput *self) {
                return [self.storage[storageKey] floatValue];
            });
            setterIMP = imp_implementationWithBlock(^(CSFInput *self, float value) {
                self.storage[storageKey] = @(value);
            });
        }
        
        // int primitives
        else if (strcmp(rawPropertyType, @encode(int)) == 0) {
            getterIMP = imp_implementationWithBlock(^int(CSFInput *self) {
                return [self.storage[storageKey] intValue];
            });
            setterIMP = imp_implementationWithBlock(^(CSFInput *self, int value) {
                self.storage[storageKey] = @(value);
            });
        }
        
        // NSUInteger primitives
        else if (strcmp(rawPropertyType, @encode(NSUInteger)) == 0) {
            getterIMP = imp_implementationWithBlock(^NSUInteger(CSFInput *self) {
                return [self.storage[storageKey] unsignedIntegerValue];
            });
            setterIMP = imp_implementationWithBlock(^(CSFInput *self, NSUInteger value) {
                self.storage[storageKey] = @(value);
            });
        }
        
        // NSInteger primitives
        else if (strcmp(rawPropertyType, @encode(NSInteger)) == 0) {
            getterIMP = imp_implementationWithBlock(^NSInteger(CSFInput *self) {
                return [self.storage[storageKey] integerValue];
            });
            setterIMP = imp_implementationWithBlock(^(CSFInput *self, NSInteger value) {
                self.storage[storageKey] = @(value);
            });
        }
        
        // Generic id objects
        else {
            getterIMP = imp_implementationWithBlock(^id(CSFInput *self) {
                return self.storage[storageKey];
            });
            setterIMP = imp_implementationWithBlock(^(CSFInput *self, id value) {
                self.storage[storageKey] = value;
            });
        }
    }
    
    BOOL getterAdded = NO;
    BOOL setterAdded = NO;
    if (getterIMP != NULL) {
        getterAdded = class_addMethod(self, NSSelectorFromString(info[CSFPropertyGetterNameKey]), getterIMP, "@@:");
    }
    
    if ([info[CSFPropertyReadonlyKey] boolValue] == NO) {
        if (setterIMP != NULL && info[CSFPropertySetterNameKey]) {
            setterAdded = class_addMethod(self, NSSelectorFromString(info[CSFPropertySetterNameKey]), setterIMP, "v@:@");
        }
    } else {
        imp_removeBlock(setterIMP);
        setterAdded = YES;
    }
    
    if (!getterAdded || !setterAdded) {
        NetworkVerbose(@"====================");
        NetworkVerbose(@"error adding methods %@", info);
    }
    
    return YES;
}

@end
