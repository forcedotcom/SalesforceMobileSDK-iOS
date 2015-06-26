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

#import "CSFDefines.h"
#import <objc/runtime.h>

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#define CSFPlatformiOS
#define NSUIImage UIImage
#else
#import <AppKit/AppKit.h>
#define CSFPlatformOSX
#define NSUIImage NSImage
#endif

@class SFUserAccount;

CSF_EXTERN NSString * const CSFDateValueTransformerName;
CSF_EXTERN NSString * const CSFURLValueTransformerName;
CSF_EXTERN NSString * const CSFPNGImageValueTransformerName;
CSF_EXTERN NSString * const CSFJPEGImageValueTransformerName;
CSF_EXTERN NSString * const CSFUTF8StringValueTransformerName;

CSF_EXTERN NSString * CSFMIMETypeForExtension(NSString * extension);

CSF_EXTERN id CSFNotNull(id value, Class classType);
CSF_EXTERN NSURL * CSFNotNullURL(id value);
CSF_EXTERN NSURL * CSFNotNullURLRelative(id value, NSURL *baseURL);
CSF_EXTERN NSDate * CSFNotNullDate(id value);

CSF_EXTERN NSString * CSFURLEncode(NSString *txt);
CSF_EXTERN NSString * CSFURLDecode(NSString *txt);
CSF_EXTERN NSString * CSFURLFormEncode(NSDictionary *info, NSError **error);
CSF_EXTERN NSDictionary * CSFURLFormDecode(NSString *info, NSError **error);

CSF_EXTERN NSString * CSFNotNullString(id value);
#define CSFNotNullNumber(_value) CSFNotNull(_value, [NSNumber class])
#define CSFNotNullArray(_value) CSFNotNull(_value, [NSArray class])
#define CSFNotNullDictionary(_value) CSFNotNull(_value, [NSDictionary class])

CSF_EXTERN NSURL * CSFCachePath(SFUserAccount *account, NSString *suffix);
CSF_EXTERN NSString *CSFNetworkInstanceKey(SFUserAccount *user);
CSF_EXTERN BOOL CSFNetworkShouldUseQueryStringForHTTPMethod(NSString *method);

CSF_EXTERN CSFParameterStyle CSFRequiredParameterStyleForHTTPMethod(NSString *method);

CSF_EXTERN NSString * const CSFChatterAttributeSegmentType;
CSF_EXTERN NSString * const CSFChatterAttributeMentionEntityId;
CSF_EXTERN NSString * const CSFChatterAttributeLinkURL;
CSF_EXTERN NSString * const CSFChatterAttributeReferenceId;
CSF_EXTERN NSString * const CSFChatterAttributeMentionUserChatterGuest;
CSF_EXTERN NSString * const CSFChatterAttributeMentionUserType;
CSF_EXTERN NSString * const CSFChatterAttributeOriginalEntityId;
CSF_EXTERN NSString * const CSFChatterAttributeMentionUserAccessible;

CSF_EXTERN NSArray * CSFClassProperties(Class currentClass);
CSF_EXTERN NSDictionary * CSFClassIvars(Class currentClass);
CSF_EXTERN Class CSFClassFromEncoding(NSString *encoding);
CSF_EXTERN NSString * CSFPropertyNameFromIvarName(NSString *ivarName);
CSF_EXTERN NSArray * CSFProtocolProperties(Protocol *proto);
CSF_EXTERN objc_property_t CSFPropertyWithName(Class currentClass, NSString *propertyName);
CSF_EXTERN NSString * CSFPropertyNameFromSelector(SEL selector);
CSF_EXTERN BOOL CSFPropertyIsReadonly(objc_property_t property);
CSF_EXTERN NSDictionary * CSFPropertyAttributes(Class currentClass, NSString *propertyName);
CSF_EXTERN BOOL CSFClassOrAncestorConformsToProtocol(Class klass, Protocol *proto);
CSF_EXTERN NSArray * CSFClassesConformingToProtocol(Protocol *prot);

CSF_EXTERN NSString * const CSFPropertyReadonlyKey;
CSF_EXTERN NSString * const CSFPropertyAtomicKey;
CSF_EXTERN NSString * const CSFPropertyRetainPolicyKey;
CSF_EXTERN NSString * const CSFPropertyGetterNameKey;
CSF_EXTERN NSString * const CSFPropertySetterNameKey;
CSF_EXTERN NSString * const CSFPropertyClassKey;
CSF_EXTERN NSString * const CSFPropertyTypeKey;

CSF_EXTERN void CSFPrimitiveIntFormatter(id value, CSFPrimitivePointer outputStruct);
CSF_EXTERN void CSFPrimitiveUnsignedIntFormatter(id value, CSFPrimitivePointer outputStruct);
CSF_EXTERN void CSFPrimitiveBooleanFormatter(id value, CSFPrimitivePointer outputStruct);
CSF_EXTERN void CSFPrimitiveIntegerFormatter(id value, CSFPrimitivePointer outputStruct);
CSF_EXTERN void CSFPrimitiveUnsignedIntegerFormatter(id value, CSFPrimitivePointer outputStruct);
CSF_EXTERN void CSFPrimitiveFloatFormatter(id value, CSFPrimitivePointer outputStruct);
CSF_EXTERN void CSFPrimitiveDoubleFormatter(id value, CSFPrimitivePointer outputStruct);
CSF_EXTERN void CSFPrimitiveCharFormatter(id value, CSFPrimitivePointer outputStruct);
CSF_EXTERN void CSFPrimitiveUnsignedCharFormatter(id value, CSFPrimitivePointer outputStruct);
CSF_EXTERN void CSFPrimitiveShortFormatter(id value, CSFPrimitivePointer outputStruct);
CSF_EXTERN void CSFPrimitiveUnsignedShortFormatter(id value, CSFPrimitivePointer outputStruct);
CSF_EXTERN void CSFPrimitiveLongFormatter(id value, CSFPrimitivePointer outputStruct);
CSF_EXTERN void CSFPrimitiveUnsignedLongFormatter(id value, CSFPrimitivePointer outputStruct);
CSF_EXTERN void CSFPrimitiveLongLongFormatter(id value, CSFPrimitivePointer outputStruct);
CSF_EXTERN void CSFPrimitiveUnsignedLongLongFormatter(id value, CSFPrimitivePointer outputStruct);
