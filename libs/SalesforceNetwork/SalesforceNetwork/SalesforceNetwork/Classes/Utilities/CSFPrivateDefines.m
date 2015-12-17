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

#import "CSFPrivateDefines.h"
#import "CSFInternalDefines.h"

#import <SalesforceSDKCore/SalesforceSDKCore.h>

NSString * const CSFPropertyReadonlyKey = @"readonly";
NSString * const CSFPropertyAtomicKey = @"atomic";
NSString * const CSFPropertyRetainPolicyKey = @"retainPolicy";
NSString * const CSFPropertyGetterNameKey = @"getter";
NSString * const CSFPropertySetterNameKey = @"setter";
NSString * const CSFPropertyClassKey = @"class";
NSString * const CSFPropertyTypeKey = @"type";

id CSFNotNull(id value, Class classType) {
    if ([value isEqual:[NSNull null]]) {
        return nil;
    }
    
    if (![value isKindOfClass:classType]) {
        return nil;
    }
    
    return value;
}

NSURL * CSFNotNullURL(id value) {
    if ([value isKindOfClass:[NSURL class]]) {
        return value;
    }
    
    NSURL *result = nil;
    NSString *stringValue = CSFNotNullString(value);
    if (stringValue) {
        result = [[NSValueTransformer valueTransformerForName:CSFURLValueTransformerName] reverseTransformedValue:stringValue];
    }
    
    return result;
}

NSURL * CSFNotNullURLRelative(id value, NSURL *baseURL) {
    if ([value isKindOfClass:[NSURL class]]) {
        return value;
    }
    
    NSURL *result = nil;
    NSString *stringValue = CSFNotNullString(value);
    if (stringValue) {
        if ([stringValue hasPrefix:@"http"]) {
            result = CSFNotNullURL(stringValue);
        } else {
            result = [NSURL URLWithString:value relativeToURL:baseURL];
            if (!result) {
                stringValue = [stringValue stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
                result = [NSURL URLWithString:value relativeToURL:baseURL];
            }
        }
    }
    
    return result;
}

NSDate * CSFNotNullDate(id value) {
    if ([value isKindOfClass:[NSDate class]]) {
        return value;
    }
    
    NSDate *result = nil;
    NSString *stringValue = CSFNotNullString(value);
    if (stringValue) {
        result = [[NSValueTransformer valueTransformerForName:CSFDateValueTransformerName] reverseTransformedValue:stringValue];
    }
    
    return result;
}

NSString * CSFNotNullString(id value) {
    NSString *stringValue = CSFNotNull(value, [NSString class]);
    if (!stringValue && [value isKindOfClass:[NSNumber class]]) {
        stringValue = [(NSNumber*)value stringValue];
    }
    return stringValue;
}

NSString * CSFURLEncode(NSString *txt) {
    return (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
                                                                                 (CFStringRef)txt,
                                                                                 NULL,
                                                                                 CFSTR(",:/=+&"),
                                                                                 kCFStringEncodingUTF8));
}

NSString * CSFURLDecode(NSString *txt) {
    return (NSString *) CFBridgingRelease(CFURLCreateStringByReplacingPercentEscapesUsingEncoding(NULL,(CFStringRef)txt,
                                                                                                  CFSTR(""),
                                                                                                  kCFStringEncodingUTF8));
}

NSString * CSFURLFormEncode(NSDictionary *info, NSError **error) {
    NSMutableArray *tuples = [NSMutableArray new];
    for (NSString *key in [[info allKeys] sortedArrayUsingSelector:@selector(compare:)]) {
        id obj = info[key];
        
        NSString *value = nil;
        if ([obj isKindOfClass:[NSNumber class]]) {
            NSNumber *numberValue = (NSNumber*)obj;
            value = [numberValue stringValue];
        } else if ([obj isKindOfClass:[NSString class]]) {
            value = obj;
        } else {
            if (error) {
                *error = [NSError errorWithDomain:CSFNetworkErrorDomain
                                             code:CSFNetworkInvalidActionParameterError
                                         userInfo:@{ NSLocalizedDescriptionKey: @"Value supplied to CSFURLFormEncode is not a number or string",
                                                     @"key": key,
                                                     @"value": obj }];
            }
            break;
        }
        
        if (value) {
            [tuples addObject:[NSString stringWithFormat:@"%@=%@",
                               CSFURLEncode(key),
                               CSFURLEncode(value)]];
        }
    }
    return [tuples componentsJoinedByString:@"&"];
}

NSDictionary * CSFURLFormDecode(NSString *info, NSError **error) {
    if (![info isKindOfClass:[NSString class]]) {
        if (error) {
            *error = [NSError errorWithDomain:CSFNetworkErrorDomain
                                         code:CSFNetworkInternalError
                                     userInfo:@{ NSLocalizedDescriptionKey: @"Value supplied to CSFURLFormDecode is not a string" }];
        }
        return nil;
    }
    
    NSMutableDictionary *results = [NSMutableDictionary new];
    [[info componentsSeparatedByString:@"&"] enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL *stop) {
        NSArray *tuples = [obj componentsSeparatedByString:@"="];
        if (tuples.count == 2) {
            results[tuples[0]] = tuples[1];
        }
    }];
    
    return results;
}

NSURL * CSFCachePath(SFUserAccount *account, NSString *suffix) {
    NSURL *result = nil;
    
    NSString *bundleId = [[NSBundle bundleForClass:NSClassFromString(@"CSFNetwork")] bundleIdentifier];
    NSArray *directories = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    if (directories.count > 0) {
        NSMutableString *path = [NSMutableString stringWithFormat:@"%@/%@", directories[0], bundleId];
        
        if (account && account.credentials.organizationId && account.credentials.userId) {
            if (account.credentials.organizationId) {
                [path appendFormat:@"/%@", account.credentials.organizationId];
                if (account.credentials.userId) {
                    [path appendFormat:@"/%@", account.credentials.userId];
                    if (account.credentials.communityId) {
                        [path appendFormat:@"/%@", account.credentials.communityId];
                    } else {
                        [path appendString:@"/Default"];
                    }
                }
            }
        }
        
        if (suffix) {
            [path appendFormat:@"/%@/", suffix];
        } else {
            [path appendString:@"/"];
        }
        
        result = [NSURL fileURLWithPath:path];
    }
    return result;
}

static NSMutableDictionary * CSFClassPropertiesDict = nil;
NSArray * CSFClassProperties(Class currentClass) {
    NSMutableArray *propertyList = nil;
    
    @synchronized (CSFClassPropertiesDict) {
        NSString *className = NSStringFromClass(currentClass);
        
        if (!CSFClassPropertiesDict) CSFClassPropertiesDict = [NSMutableDictionary new];
        propertyList = CSFClassPropertiesDict[className];
        
        if (!propertyList) {
            propertyList = CSFClassPropertiesDict[className] = [NSMutableArray new];
            
            static NSArray *omitProperties = nil;
            if (!omitProperties) omitProperties = @[ @"hash", @"superclass", @"description", @"debugDescription", @"parentObject" ]; // TODO: Add support to define objects that should be skipped more flexibly
            
            do {
                unsigned int outCount, idx;
                objc_property_t *properties = class_copyPropertyList(currentClass, &outCount);
                
                for (idx = 0; idx < outCount; idx++) {
                    objc_property_t property = properties[idx];
                    
                    NSString *propertyName = [NSString stringWithFormat:@"%s", property_getName(property)];
                    if (![omitProperties containsObject:propertyName]) {
                        [propertyList addObject:propertyName];
                    }
                }
                free(properties);
                currentClass = [currentClass superclass];
            } while ([currentClass superclass]);
        }
    }
    
    return propertyList;
}

static NSMutableDictionary * CSFProtocolPropertiesDict = nil;
NSArray * CSFProtocolProperties(Protocol *proto) {
    NSMutableArray *propertyList = nil;
    
    @synchronized (CSFProtocolPropertiesDict) {
        NSString *protocolName = NSStringFromProtocol(proto);
        
        if (!CSFProtocolPropertiesDict) CSFProtocolPropertiesDict = [NSMutableDictionary new];
        propertyList = CSFProtocolPropertiesDict[protocolName];
        
        if (!propertyList) {
            propertyList = CSFProtocolPropertiesDict[protocolName] = [NSMutableArray new];
            
            unsigned int outCount, idx;
            objc_property_t *properties = protocol_copyPropertyList(proto, &outCount);
            
            for (idx = 0; idx < outCount; idx++) {
                objc_property_t property = properties[idx];
                
                NSString *propertyName = [NSString stringWithFormat:@"%s", property_getName(property)];
                
                [propertyList addObject:propertyName];
            }
            free(properties);
        }
    }
    
    return propertyList;
}

objc_property_t CSFPropertyWithName(Class currentClass, NSString *propertyName) {
    objc_property_t property = class_getProperty(currentClass, [propertyName UTF8String]);
    if (property == NULL) {
        // unable to find property
        // let's see if we can brute-force find it
        while (currentClass != nil) {
            unsigned int count = 0;
            objc_property_t *allProperties = class_copyPropertyList(currentClass, &count);
            for (int idx = 0; idx < count; ++idx) {
                objc_property_t aProperty = allProperties[idx];
                NSString *propertyInfo = [NSString stringWithUTF8String:property_getAttributes(aProperty)];
                if ([propertyInfo rangeOfString:propertyName].location != NSNotFound) {
                    property = aProperty;
                    break;
                }
            }
            if (allProperties) {
                free(allProperties);
            }
            if (property != NULL) {
                break;
            } else {
                currentClass = class_getSuperclass(currentClass);
            }
        }
    }
    
    return property;
}

BOOL CSFClassOrAncestorConformsToProtocol(Class klass, Protocol *proto) {
    BOOL result = NO;
    if (class_conformsToProtocol(klass, proto)) {
        result = YES;
    } else {
        Class superClass = class_getSuperclass(klass);
        if (superClass) {
            result = CSFClassOrAncestorConformsToProtocol(superClass, proto);
        }
    }
    return result;
}

static NSMutableDictionary * CSFPropertyAttributesDict = nil;
NSDictionary * CSFPropertyAttributes(Class currentClass, NSString *propertyName) {
    NSMutableDictionary *attributes = nil;
    
    @synchronized (CSFPropertyAttributesDict) {
        NSString *lookupKey = [NSString stringWithFormat:@"%@.%@", NSStringFromClass(currentClass), propertyName];
        
        if (!CSFPropertyAttributesDict) CSFPropertyAttributesDict = [NSMutableDictionary new];
        attributes = CSFPropertyAttributesDict[lookupKey];
        
        if (!attributes) {
            objc_property_t property = CSFPropertyWithName(currentClass, propertyName);
            if (property == NULL) {
                return nil;
            }
            
            attributes = CSFPropertyAttributesDict[lookupKey] = [NSMutableDictionary new];
            
            const char *rawPropertyName = property_getName(property);
            propertyName = [NSString stringWithUTF8String:rawPropertyName];
            
            NSString *getterName = nil;
            NSString *setterName = nil;
            NSString *propertyType = nil;
            Class propertyClass = nil;
            BOOL isReadonly = NO;
            BOOL isAtomic = YES;
            objc_AssociationPolicy policy = OBJC_ASSOCIATION_ASSIGN;
            
            NSString *propertyInfo = [NSString stringWithUTF8String:property_getAttributes(property)];
            NSArray *propertyAttributes = [propertyInfo componentsSeparatedByString:@","];
            for (NSString *attribute in propertyAttributes) {
                if ([attribute hasPrefix:@"G"] && getterName == nil) {
                    getterName = [attribute substringFromIndex:1];
                } else if ([attribute hasPrefix:@"S"] && setterName == nil) {
                    setterName = [attribute substringFromIndex:1];
                } else if ([attribute hasPrefix:@"t"] && propertyType == nil) {
                    propertyType = [attribute substringFromIndex:1];
                } else if ([attribute hasPrefix:@"T@"] && propertyClass == nil) {
                    propertyType = [attribute substringFromIndex:1];
                    propertyClass = CSFClassFromEncoding(propertyType);
                } else if ([attribute isEqualToString:@"N"]) {
                    isAtomic = NO;
                } else if ([attribute isEqualToString:@"R"]) {
                    isReadonly = YES;
                } else if ([attribute isEqualToString:@"C"]) {
                    policy = OBJC_ASSOCIATION_COPY;
                } else if ([attribute isEqualToString:@"&"]) {
                    policy = OBJC_ASSOCIATION_RETAIN;
                }
            }
            
            if (!isAtomic) {
                if (policy == OBJC_ASSOCIATION_COPY) {
                    policy = OBJC_ASSOCIATION_COPY_NONATOMIC;
                } else if (policy == OBJC_ASSOCIATION_RETAIN) {
                    policy = OBJC_ASSOCIATION_RETAIN_NONATOMIC;
                }
            }
            
            if (getterName == nil) {
                getterName = propertyName;
            }
            if (setterName == nil) {
                setterName = [NSString stringWithFormat:@"set%c%s:", toupper(rawPropertyName[0]), (rawPropertyName+1)];
            }
            
            attributes[CSFPropertyAtomicKey] = @(isAtomic);
            attributes[CSFPropertyReadonlyKey] = @(isReadonly);
            attributes[CSFPropertyRetainPolicyKey] = @(policy);
            attributes[CSFPropertyGetterNameKey] = getterName;
            
            if (!isReadonly && setterName) {
                attributes[CSFPropertySetterNameKey] = setterName;
            }
            
            if (propertyClass) {
                attributes[CSFPropertyClassKey] = propertyClass;
            }
            
            if (propertyType) {
                attributes[CSFPropertyTypeKey] = propertyType;
            }
        }
    }
    
    return attributes;
}

static NSMutableDictionary *CSFClassesConformingToProtocolDict = nil;
NSArray * CSFClassesConformingToProtocol(Protocol *prot) {
    NSArray *result = nil;
    
    @synchronized (CSFClassesConformingToProtocolDict) {
        if (!CSFClassesConformingToProtocolDict) {
            CSFClassesConformingToProtocolDict = [NSMutableDictionary new];
        }
        
        NSString *key = NSStringFromProtocol(prot);
        result = CSFClassesConformingToProtocolDict[key];
        if (!result) {
            NSMutableArray *results = [NSMutableArray new];
            int numClasses = objc_getClassList(NULL, 0);
            if (numClasses > 0) {
                Class *classes = (__unsafe_unretained Class *)malloc(sizeof(Class) * numClasses);
                numClasses = objc_getClassList(classes, numClasses);
                for (NSInteger index = 0; index < numClasses; index++) {
                    Class c = classes[index];
                    if (CSFClassOrAncestorConformsToProtocol(c, prot)) {
                        [results addObject:c];
                    }
                }
                free(classes);
            }
            result = CSFClassesConformingToProtocolDict[key] = [NSArray arrayWithArray:results];
        }
    }
    
    return result;
}
