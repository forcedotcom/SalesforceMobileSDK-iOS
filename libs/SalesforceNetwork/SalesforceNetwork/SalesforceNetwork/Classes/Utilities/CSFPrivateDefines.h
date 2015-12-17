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

#import <objc/runtime.h>
#import <Foundation/Foundation.h>

#ifndef CSF_PRIVATE_EXTERN
#ifdef __cplusplus
#define CSF_PRIVATE_EXTERN   extern "C" __attribute__((visibility ("default")))
#else
#define CSF_PRIVATE_EXTERN   extern __attribute__((visibility ("default")))
#endif
#endif

@class SFUserAccount;

CSF_PRIVATE_EXTERN id CSFNotNull(id value, Class classType);
CSF_PRIVATE_EXTERN NSURL * CSFNotNullURL(id value);
CSF_PRIVATE_EXTERN NSURL * CSFNotNullURLRelative(id value, NSURL *baseURL);
CSF_PRIVATE_EXTERN NSDate * CSFNotNullDate(id value);
CSF_PRIVATE_EXTERN NSString * CSFNotNullString(id value);

#define CSFNotNullNumber(_value) CSFNotNull(_value, [NSNumber class])
#define CSFNotNullArray(_value) CSFNotNull(_value, [NSArray class])
#define CSFNotNullDictionary(_value) CSFNotNull(_value, [NSDictionary class])

CSF_PRIVATE_EXTERN NSString * CSFURLEncode(NSString *txt);
CSF_PRIVATE_EXTERN NSString * CSFURLDecode(NSString *txt);
CSF_PRIVATE_EXTERN NSString * CSFURLFormEncode(NSDictionary *info, NSError **error);
CSF_PRIVATE_EXTERN NSDictionary * CSFURLFormDecode(NSString *info, NSError **error);

CSF_PRIVATE_EXTERN NSURL * CSFCachePath(SFUserAccount *account, NSString *suffix);

CSF_PRIVATE_EXTERN NSArray * CSFClassProperties(Class currentClass);
CSF_PRIVATE_EXTERN NSArray * CSFProtocolProperties(Protocol *proto);
CSF_PRIVATE_EXTERN objc_property_t CSFPropertyWithName(Class currentClass, NSString *propertyName);
CSF_PRIVATE_EXTERN NSDictionary * CSFPropertyAttributes(Class currentClass, NSString *propertyName);
CSF_PRIVATE_EXTERN BOOL CSFClassOrAncestorConformsToProtocol(Class klass, Protocol *proto);
CSF_PRIVATE_EXTERN NSArray * CSFClassesConformingToProtocol(Protocol *prot);

CSF_PRIVATE_EXTERN NSString * const CSFPropertyReadonlyKey;
CSF_PRIVATE_EXTERN NSString * const CSFPropertyAtomicKey;
CSF_PRIVATE_EXTERN NSString * const CSFPropertyRetainPolicyKey;
CSF_PRIVATE_EXTERN NSString * const CSFPropertyGetterNameKey;
CSF_PRIVATE_EXTERN NSString * const CSFPropertySetterNameKey;
CSF_PRIVATE_EXTERN NSString * const CSFPropertyClassKey;
CSF_PRIVATE_EXTERN NSString * const CSFPropertyTypeKey;
