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

#ifndef CSFForceDefines_h
#define CSFForceDefines_h

#import <Foundation/Foundation.h>
#import "CSFAvailability.h"
#import "CSFDefines.h"

typedef NS_ENUM(NSInteger, CSFForceLayoutComponentType) {
    CSFForceLayoutComponentTypeUnknown,
    CSFForceLayoutComponentTypeEmptySpace,
    CSFForceLayoutComponentTypeField,
    CSFForceLayoutComponentTypeSControl,
    CSFForceLayoutComponentTypeSeparator,

};

typedef NS_ENUM(NSInteger, CSFForceQuickActionType) {
    CSFForceQuickActionTypeUnknown,
    CSFForceQuickActionTypeCreate,
    CSFForceQuickActionTypeVisualforce,
    CSFForceQuickActionTypePost,
    CSFForceQuickActionTypeFeed,
    CSFForceQuickActionTypePoll,
    CSFForceQuickActionTypeFile,
    CSFForceQuickActionTypeThanks,

};

typedef NS_ENUM(NSInteger, CSFForceNotificationFrequency) {
    CSFForceNotificationFrequencyUnknown,
    CSFForceNotificationFrequencyEachPost,
    CSFForceNotificationFrequencyDailyDigest,
    CSFForceNotificationFrequencyWeeklyDigest,
    CSFForceNotificationFrequencyNever,

};

typedef NS_ENUM(NSInteger, CSFForcePortalRoleType) {
    CSFForcePortalRoleTypeUnknown,
    CSFForcePortalRoleTypeExecutive,
    CSFForcePortalRoleTypeManager,
    CSFForcePortalRoleTypeUser,
    CSFForcePortalRoleTypePersonAccount,

};

typedef NS_ENUM(NSInteger, CSFForcePortalType) {
    CSFForcePortalTypeUnknown,
    CSFForcePortalTypeNone,
    CSFForcePortalTypeCustomerPortal,
    CSFForcePortalTypePartner,

};

typedef NS_ENUM(NSInteger, CSFForceFieldMetadataType) {
    CSFForceFieldMetadataTypeUnknown,
    CSFForceFieldMetadataTypeBase64,
    CSFForceFieldMetadataTypeBoolean,
    CSFForceFieldMetadataTypeComboBox,
    CSFForceFieldMetadataTypeCurrency,
    CSFForceFieldMetadataTypeDate,
    CSFForceFieldMetadataTypeDateTime,
    CSFForceFieldMetadataTypeDouble,
    CSFForceFieldMetadataTypeEmail,
    CSFForceFieldMetadataTypeEncryptedString,
    CSFForceFieldMetadataTypeId,
    CSFForceFieldMetadataTypeInteger,
    CSFForceFieldMetadataTypeInt,
    CSFForceFieldMetadataTypeMultiPickList,
    CSFForceFieldMetadataTypePercent,
    CSFForceFieldMetadataTypePhone,
    CSFForceFieldMetadataTypePickList,
    CSFForceFieldMetadataTypeString,
    CSFForceFieldMetadataTypeReference,
    CSFForceFieldMetadataTypeTextArea,
    CSFForceFieldMetadataTypeTime,
    CSFForceFieldMetadataTypeUrl,

};

typedef NS_ENUM(NSInteger, CSFForceTaskStatus) {
    CSFForceTaskStatusUnknown,
    CSFForceTaskStatusNotStarted,
    CSFForceTaskStatusInProgress,
    CSFForceTaskStatusCompleted,
    CSFForceTaskStatusWaitingonsomeoneelse,
    CSFForceTaskStatusDeferred,

};

typedef NS_ENUM(NSInteger, CSFForceTaskPriority) {
    CSFForceTaskPriorityUnknown,
    CSFForceTaskPriorityHigh,
    CSFForceTaskPriorityNormal,
    CSFForceTaskPriorityLow,

};

typedef NS_ENUM(NSInteger, CSFForceTaskCallType) {
    CSFForceTaskCallTypeUnknown,
    CSFForceTaskCallTypeInternal,
    CSFForceTaskCallTypeInbound,
    CSFForceTaskCallTypeOutbound,

};

typedef NS_ENUM(NSInteger, CSFForceTaskRecurrenceType) {
    CSFForceTaskRecurrenceTypeUnknown,
    CSFForceTaskRecurrenceTypeRecursDaily,
    CSFForceTaskRecurrenceTypeRecursEveryWeekday,
    CSFForceTaskRecurrenceTypeRecursMonthly,
    CSFForceTaskRecurrenceTypeRecursMonthyNth,
    CSFForceTaskRecurrenceTypeRecursWeekly,
    CSFForceTaskRecurrenceTypeRecursYearly,
    CSFForceTaskRecurrenceTypeRecursYearlyNth,

};

typedef NS_ENUM(NSInteger, CSFForceTaskRecurrenceInstance) {
    CSFForceTaskRecurrenceInstanceUnknown,
    CSFForceTaskRecurrenceInstance1st,
    CSFForceTaskRecurrenceInstance2nd,
    CSFForceTaskRecurrenceInstance3rd,
    CSFForceTaskRecurrenceInstance4th,
    CSFForceTaskRecurrenceInstanceLast,

};

typedef NS_ENUM(NSInteger, CSFForceTaskRecurrenceMonthOfYear) {
    CSFForceTaskRecurrenceMonthOfYearUnknown,
    CSFForceTaskRecurrenceMonthOfYearJanuary,
    CSFForceTaskRecurrenceMonthOfYearFebruary,
    CSFForceTaskRecurrenceMonthOfYearMarch,
    CSFForceTaskRecurrenceMonthOfYearApril,
    CSFForceTaskRecurrenceMonthOfYearMay,
    CSFForceTaskRecurrenceMonthOfYearJune,
    CSFForceTaskRecurrenceMonthOfYearJuly,
    CSFForceTaskRecurrenceMonthOfYearAugust,
    CSFForceTaskRecurrenceMonthOfYearSeptember,
    CSFForceTaskRecurrenceMonthOfYearOctober,
    CSFForceTaskRecurrenceMonthOfYearNovember,
    CSFForceTaskRecurrenceMonthOfYearDecember,

};

typedef NS_ENUM(NSInteger, CSFForceRecordType) {
    CSFForceRecordTypeOther,
    CSFForceRecordTypeAccount,
    CSFForceRecordTypeContact,
    CSFForceRecordTypeTask,
    CSFForceRecordTypeCase,
    CSFForceRecordTypeContract,
    CSFForceRecordTypeOpportunity,
    CSFForceRecordTypeQuote,
    CSFForceRecordTypeLead,
    CSFForceRecordTypeCampaign,

};

CSF_EXTERN NSString * CSFForceStringValueForLayoutComponentType(CSFForceLayoutComponentType type);
CSF_EXTERN CSFForceLayoutComponentType CSFForceTypeForLayoutComponentTypeName(NSString *name);
CSF_EXTERN void CSFForcePrimitiveLayoutComponentTypeFormatter(id value, CSFPrimitivePointer outputStruct);

CSF_EXTERN NSString * CSFForceStringValueForQuickActionType(CSFForceQuickActionType type);
CSF_EXTERN CSFForceQuickActionType CSFForceTypeForQuickActionTypeName(NSString *name);
CSF_EXTERN void CSFForcePrimitiveQuickActionTypeFormatter(id value, CSFPrimitivePointer outputStruct);

CSF_EXTERN NSString * CSFForceStringValueForNotificationFrequency(CSFForceNotificationFrequency type);
CSF_EXTERN CSFForceNotificationFrequency CSFForceTypeForNotificationFrequencyName(NSString *name);
CSF_EXTERN void CSFForcePrimitiveNotificationFrequencyFormatter(id value, CSFPrimitivePointer outputStruct);

CSF_EXTERN NSString * CSFForceStringValueForPortalRoleType(CSFForcePortalRoleType type);
CSF_EXTERN CSFForcePortalRoleType CSFForceTypeForPortalRoleTypeName(NSString *name);
CSF_EXTERN void CSFForcePrimitivePortalRoleTypeFormatter(id value, CSFPrimitivePointer outputStruct);

CSF_EXTERN NSString * CSFForceStringValueForPortalType(CSFForcePortalType type);
CSF_EXTERN CSFForcePortalType CSFForceTypeForPortalTypeName(NSString *name);
CSF_EXTERN void CSFForcePrimitivePortalTypeFormatter(id value, CSFPrimitivePointer outputStruct);

CSF_EXTERN NSString * CSFForceStringValueForFieldMetadataType(CSFForceFieldMetadataType type);
CSF_EXTERN CSFForceFieldMetadataType CSFForceTypeForFieldMetadataTypeName(NSString *name);
CSF_EXTERN void CSFForcePrimitiveFieldMetadataTypeFormatter(id value, CSFPrimitivePointer outputStruct);

CSF_EXTERN NSString * CSFForceStringValueForTaskStatus(CSFForceTaskStatus type);
CSF_EXTERN CSFForceTaskStatus CSFForceTypeForTaskStatusName(NSString *name);
CSF_EXTERN void CSFForcePrimitiveTaskStatusFormatter(id value, CSFPrimitivePointer outputStruct);

CSF_EXTERN NSString * CSFForceStringValueForTaskPriority(CSFForceTaskPriority type);
CSF_EXTERN CSFForceTaskPriority CSFForceTypeForTaskPriorityName(NSString *name);
CSF_EXTERN void CSFForcePrimitiveTaskPriorityFormatter(id value, CSFPrimitivePointer outputStruct);

CSF_EXTERN NSString * CSFForceStringValueForTaskCallType(CSFForceTaskCallType type);
CSF_EXTERN CSFForceTaskCallType CSFForceTypeForTaskCallTypeName(NSString *name);
CSF_EXTERN void CSFForcePrimitiveTaskCallTypeFormatter(id value, CSFPrimitivePointer outputStruct);

CSF_EXTERN NSString * CSFForceStringValueForTaskRecurrenceType(CSFForceTaskRecurrenceType type);
CSF_EXTERN CSFForceTaskRecurrenceType CSFForceTypeForTaskRecurrenceTypeName(NSString *name);
CSF_EXTERN void CSFForcePrimitiveTaskRecurrenceTypeFormatter(id value, CSFPrimitivePointer outputStruct);

CSF_EXTERN NSString * CSFForceStringValueForTaskRecurrenceInstance(CSFForceTaskRecurrenceInstance type);
CSF_EXTERN CSFForceTaskRecurrenceInstance CSFForceTypeForTaskRecurrenceInstanceName(NSString *name);
CSF_EXTERN void CSFForcePrimitiveTaskRecurrenceInstanceFormatter(id value, CSFPrimitivePointer outputStruct);

CSF_EXTERN NSString * CSFForceStringValueForTaskRecurrenceMonthOfYear(CSFForceTaskRecurrenceMonthOfYear type);
CSF_EXTERN CSFForceTaskRecurrenceMonthOfYear CSFForceTypeForTaskRecurrenceMonthOfYearName(NSString *name);
CSF_EXTERN void CSFForcePrimitiveTaskRecurrenceMonthOfYearFormatter(id value, CSFPrimitivePointer outputStruct);

CSF_EXTERN NSString * CSFForceStringValueForRecordType(CSFForceRecordType type);
CSF_EXTERN CSFForceRecordType CSFForceTypeForRecordTypeName(NSString *name);
CSF_EXTERN void CSFForcePrimitiveRecordTypeFormatter(id value, CSFPrimitivePointer outputStruct);

#define __CSF_AVAILABLE_INTERNAL_29_0 NS_UNAVAILABLE
#define __CSF_AVAILABLE_INTERNAL_29_0 NS_UNAVAILABLE
#define __CSF_AVAILABLE_INTERNAL_29_0 NS_UNAVAILABLE


#endif
