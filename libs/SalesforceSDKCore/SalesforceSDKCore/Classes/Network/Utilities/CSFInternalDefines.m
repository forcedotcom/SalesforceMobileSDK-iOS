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

#import "CSFInternalDefines.h"

#import <SalesforceSDKCore/SalesforceSDKCore.h>

#ifdef CSFPlatformiOS
@import MobileCoreServices;
#else
@import LaunchServices;
#endif

NSInteger kCSFNetworkLogContext = 0;

__attribute__((constructor))
static void initialize_logging() {
    kCSFNetworkLogContext = [[SFLogger sharedLogger] registerIdentifier:CSFNetworkLogIdentifier];
}

NSString * CSFMIMETypeForExtension(NSString * extension) {
    NSString *type = @"application/octet-stream";
    CFStringRef uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)extension, NULL);
    if (uti) {
        CFStringRef mime = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType);
        CFRelease(uti);
        if (mime) {
            type = [NSString stringWithString:(__bridge NSString *)mime];
            CFRelease(mime);
        }
    }
    return type;
}

BOOL CSFNetworkShouldUseQueryStringForHTTPMethod(NSString *method) {
    NSString *upperMethod = [method uppercaseString];
    BOOL result = ([upperMethod isEqualToString:@"GET"] ||
                   [upperMethod isEqualToString:@"HEAD"] ||
                   [upperMethod isEqualToString:@"DELETE"]);
    return result;
}

CSFParameterStyle CSFRequiredParameterStyleForHTTPMethod(NSString *method) {
    CSFParameterStyle result = CSFParameterStyleQueryString;

    NSString *upperMethod = [method uppercaseString];
    if (![upperMethod isEqualToString:@"GET"] &&
        ![upperMethod isEqualToString:@"HEAD"] &&
        ![upperMethod isEqualToString:@"DELETE"])
    {
        result = CSFParameterStyleURLEncoded;
    }

    return result;
}

Class CSFClassFromEncoding(NSString *encoding) {
    Class result = nil;
    if ([encoding hasPrefix:@"@"]) {
        NSString *className = [[encoding substringFromIndex:2] stringByReplacingOccurrencesOfString:@"\"" withString:@""];
        result = NSClassFromString(className);
    }
    return result;
}

NSString * CSFPropertyNameFromIvarName(NSString *ivarName) {
    return ([ivarName rangeOfString:@"_"].location == 0) ? [ivarName substringFromIndex:1] : ivarName;
}

static NSMutableDictionary * CSFClassIvarsDict = nil;
NSDictionary * CSFClassIvars(Class currentClass) {
    NSMutableDictionary *ivarList = nil;
    
    @synchronized (CSFClassIvarsDict) {
        NSString *className = NSStringFromClass(currentClass);
        
        if (!CSFClassIvarsDict) CSFClassIvarsDict = [NSMutableDictionary new];
        ivarList = CSFClassIvarsDict[className];
        
        if (!ivarList) {
            ivarList = CSFClassIvarsDict[className] = [NSMutableDictionary new];

            do {
                unsigned int outCount, idx;
                Ivar *ivars = class_copyIvarList(currentClass, &outCount);
                
                for (idx = 0; idx < outCount; idx++) {
                    Ivar ivar = ivars[idx];
                    
                    NSString *name = [NSString stringWithFormat:@"%s", ivar_getName(ivar)];
                    NSString *encoding = [NSString stringWithFormat:@"%s", ivar_getTypeEncoding(ivar)];
                    ivarList[name] = @{ @"encoding": encoding,
                                        @"class": currentClass };
                }
                free(ivars);
                currentClass = [currentClass superclass];
            } while ([currentClass superclass]);
        }
    }
    
    return ivarList;
}

NSString * CSFPropertyNameFromSelector(SEL selector) {
    const char *rawName = sel_getName(selector);
    NSString *name = NSStringFromSelector(selector);
    
    NSString *propertyName = nil;
    if ([name hasPrefix:@"set"]) {
        propertyName = [NSString stringWithFormat:@"%c%s", tolower(rawName[3]), (rawName+4)];
    } else if ([name hasPrefix:@"is"]) {
        propertyName = [NSString stringWithFormat:@"%c%s", tolower(rawName[2]), (rawName+3)];
    } else {
        propertyName = name;
    }
    propertyName = [propertyName stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@":"]];
    return propertyName;
}

BOOL CSFPropertyIsReadonly(objc_property_t property) {
    NSString *propertyInfo = [NSString stringWithUTF8String:property_getAttributes(property)];
    NSArray *propertyAttributes = [propertyInfo componentsSeparatedByString:@","];
    return [propertyAttributes containsObject:@"R"];
}

void CSFPrimitiveIntFormatter(id value, CSFPrimitivePointer outputStruct) {
    if (outputStruct.intPtr) {
        *outputStruct.intPtr = [CSFNotNullNumber(value) intValue];
    }
}

void CSFPrimitiveUnsignedIntFormatter(id value, CSFPrimitivePointer outputStruct) {
    if (outputStruct.unsignedIntPtr) {
        *outputStruct.unsignedIntPtr = [CSFNotNullNumber(value) unsignedIntValue];
    }
}

void CSFPrimitiveBooleanFormatter(id value, CSFPrimitivePointer outputStruct) {
    if (outputStruct.boolPtr) {
        *outputStruct.boolPtr = [CSFNotNullNumber(value) boolValue];
    }
}

void CSFPrimitiveIntegerFormatter(id value, CSFPrimitivePointer outputStruct) {
    if (outputStruct.integerPtr) {
        *outputStruct.integerPtr = [CSFNotNullNumber(value) integerValue];
    }
}

void CSFPrimitiveUnsignedIntegerFormatter(id value, CSFPrimitivePointer outputStruct) {
    if (outputStruct.unsignedIntegerPtr) {
        *outputStruct.unsignedIntegerPtr = [CSFNotNullNumber(value) unsignedIntegerValue];
    }
}

void CSFPrimitiveFloatFormatter(id value, CSFPrimitivePointer outputStruct) {
    if (outputStruct.floatPtr) {
        *outputStruct.floatPtr = [CSFNotNullNumber(value) floatValue];
    }
}

void CSFPrimitiveDoubleFormatter(id value, CSFPrimitivePointer outputStruct) {
    if (outputStruct.doublePtr) {
        *outputStruct.doublePtr = [CSFNotNullNumber(value) doubleValue];
    }
}

void CSFPrimitiveCharFormatter(id value, CSFPrimitivePointer outputStruct) {
    if (outputStruct.charPtr) {
        *outputStruct.charPtr = [CSFNotNullNumber(value) charValue];
    }
}

void CSFPrimitiveUnsignedCharFormatter(id value, CSFPrimitivePointer outputStruct) {
    if (outputStruct.unsignedCharPtr) {
        *outputStruct.unsignedCharPtr = [CSFNotNullNumber(value) unsignedCharValue];
    }
}

void CSFPrimitiveShortFormatter(id value, CSFPrimitivePointer outputStruct) {
    if (outputStruct.shortPtr) {
        *outputStruct.shortPtr = [CSFNotNullNumber(value) shortValue];
    }
}

void CSFPrimitiveUnsignedShortFormatter(id value, CSFPrimitivePointer outputStruct) {
    if (outputStruct.unsignedShortPtr) {
        *outputStruct.unsignedShortPtr = [CSFNotNullNumber(value) unsignedShortValue];
    }
}

void CSFPrimitiveLongFormatter(id value, CSFPrimitivePointer outputStruct) {
    if (outputStruct.longPtr) {
        *outputStruct.longPtr = [CSFNotNullNumber(value) longValue];
    }
}

void CSFPrimitiveUnsignedLongFormatter(id value, CSFPrimitivePointer outputStruct) {
    if (outputStruct.unsignedLongPtr) {
        *outputStruct.unsignedLongPtr = [CSFNotNullNumber(value) unsignedLongValue];
    }
}

void CSFPrimitiveLongLongFormatter(id value, CSFPrimitivePointer outputStruct) {
    if (outputStruct.longLongPtr) {
        *outputStruct.longLongPtr = [CSFNotNullNumber(value) longLongValue];
    }
}

void CSFPrimitiveUnsignedLongLongFormatter(id value, CSFPrimitivePointer outputStruct) {
    if (outputStruct.unsignedLongLongPtr) {
        *outputStruct.unsignedLongLongPtr = [CSFNotNullNumber(value) unsignedLongLongValue];
    }
}
