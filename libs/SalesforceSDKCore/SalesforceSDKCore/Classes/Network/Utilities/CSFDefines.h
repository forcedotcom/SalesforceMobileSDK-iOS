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

#ifndef CSF_EXTERN
#ifdef __cplusplus
#define CSF_EXTERN   extern "C" __attribute__((visibility ("default")))
#else
#define CSF_EXTERN   extern __attribute__((visibility ("default")))
#endif
#endif

#ifndef NS_STRING_ENUM
#define NS_STRING_ENUM
#endif

@class CSFAction;

CSF_EXTERN NSString * const kCSFConnectVersion;

CSF_EXTERN NSString * const CSFNetworkLogIdentifier;

/**
 This block is invoked after the action has completed with or without error.
 This block is defined by the user of the CHAction class.
 */
typedef void (^CSFActionResponseBlock)(CSFAction *action, NSError *error);

typedef struct _CSFPrimitivePointer {
    int                *intPtr;
    unsigned int       *unsignedIntPtr;
    BOOL               *boolPtr;
    NSInteger          *integerPtr;
    NSUInteger         *unsignedIntegerPtr;
    float              *floatPtr;
    double             *doublePtr;
    char               *charPtr;
    unsigned char      *unsignedCharPtr;
    short              *shortPtr;
    unsigned short     *unsignedShortPtr;
    long               *longPtr;
    unsigned long      *unsignedLongPtr;
    long long          *longLongPtr;
    unsigned long long *unsignedLongLongPtr;
} CSFPrimitivePointer;

typedef void (*CSFPrimitiveFormatterPtr)(id value, CSFPrimitivePointer outputStruct);

/** This type defines the execution cap that an action has.
 Notes:
 (1) An action is identified by its actionVerb only.
 (2) A session is defined as lasting from the time the application starts (or resumes) until
 it is backgrounded or killed.
 */
typedef NS_ENUM(NSUInteger, CSFActionExecutionCapType) {
    /** Default value which means the action can be executed as many times as it wants
     */
    CSFActionExecutionCapTypeUnlimited = 0,
    
    /** The action is going to be executed only once per session.
     */
    CSFActionExecutionCapTypeOncePerSession,
};

typedef NS_ENUM(NSInteger, CSFInteractionContext) {
    CSFInteractionContextUser = 0,       /// the event was caused by user interaction
    CSFInteractionContextProgrammatic    /// the event was programmatically triggered
};

typedef NS_ENUM(NSInteger, CSFChatterCommunityMode)  {
    CSFChatterCommunityOptional = 0,
    CSFChatterCommunityRequired,
    CSFChatterCommunityDisallowed
};

CSF_EXTERN NSString * const CSFNetworkErrorDomain;
CSF_EXTERN NSString * const CSFNetworkErrorActionKey;
CSF_EXTERN NSString * const CSFNetworkErrorAuthenticationFailureKey;

/** Enumerator listing the error codes used by CSFNetwork
   - CSFNetworkAPIError: Server-generated API error
   - CSFNetworkInternalError: An unknown internal error occurred
   - CSFNetworkCancelledError: The network operation was cancelled
   - CSFNetworkNetworkNotReadyError: The network is not initialized or is not ready
   - CSFNetworkHTTPResponseError: An HTTP error occurred
   - CSFNetworkURLResponseInvalidError: The URL response type is invalid
   - CSFNetworkURLCredentialsError: The URL credentials are missing or invalid
   - CSFNetworkInvalidActionParameterError: The supplied action parameter was invalid
   - CSFNetworkJSONInvalidError: The returned result could not be parsed as JSON
 */
typedef NS_ENUM(NSInteger, CSFNetworkErrorCode) {
    CSFNetworkAPIError = 1000,
    CSFNetworkInternalError,
    CSFNetworkCancelledError,
    CSFNetworkNetworkNotReadyError,
    CSFNetworkHTTPResponseError,
    CSFNetworkURLResponseInvalidError,
    CSFNetworkURLCredentialsError,
    CSFNetworkInvalidActionParameterError,
    CSFNetworkJSONInvalidError,
    CSFNetworkCacheError,
};

CSF_EXTERN NSString * const CSFValidationErrorDomain;
typedef NS_ENUM(NSInteger, CSFValidationErrorCode) {
    CSFValidationDataTypeError = 1100,
    CSFValidationRangeError,
};

typedef NS_ENUM(NSUInteger, CSFParameterStyle) {
    CSFParameterStyleNone = 0,
    CSFParameterStyleQueryString,
    CSFParameterStyleURLEncoded,
    CSFParameterStyleMultipart,
};

CSF_EXTERN NSString * const CSFNetworkInitializedNotification;
