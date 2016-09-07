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

#include "CSFForceDefines.h"


NSString * CSFForceStringValueForLayoutComponentType(CSFForceLayoutComponentType type) {
    switch (type) {
        case CSFForceLayoutComponentTypeEmptySpace:
            return @"EmptySpace";

        case CSFForceLayoutComponentTypeField:
            return @"Field";

        case CSFForceLayoutComponentTypeSControl:
            return @"SControl";

        case CSFForceLayoutComponentTypeSeparator:
            return @"Separator";

        case CSFForceLayoutComponentTypeUnknown:
        default:
            return nil;
    }
}

CSFForceLayoutComponentType CSFForceTypeForLayoutComponentTypeName(NSString *name) {
    if ([name isEqualToString:@"EmptySpace"]) {
        return CSFForceLayoutComponentTypeEmptySpace;
    } else if ([name isEqualToString:@"Field"]) {
        return CSFForceLayoutComponentTypeField;
    } else if ([name isEqualToString:@"SControl"]) {
        return CSFForceLayoutComponentTypeSControl;
    } else if ([name isEqualToString:@"Separator"]) {
        return CSFForceLayoutComponentTypeSeparator;
    } else {
        return CSFForceLayoutComponentTypeUnknown;
    }
}

void CSFForcePrimitiveLayoutComponentTypeFormatter(id value, CSFPrimitivePointer outputStruct) {
    if (outputStruct.integerPtr && [value isKindOfClass:[NSString class]]) {
        *outputStruct.integerPtr = CSFForceTypeForLayoutComponentTypeName((NSString *)value);
    }
}

NSString * CSFForceStringValueForQuickActionType(CSFForceQuickActionType type) {
    switch (type) {
        case CSFForceQuickActionTypeCreate:
            return @"Create";

        case CSFForceQuickActionTypeVisualforce:
            return @"Visualforce";

        case CSFForceQuickActionTypePost:
            return @"Post";

        case CSFForceQuickActionTypeFeed:
            return @"Feed";

        case CSFForceQuickActionTypePoll:
            return @"Poll";

        case CSFForceQuickActionTypeFile:
            return @"File";

        case CSFForceQuickActionTypeThanks:
            return @"Thanks";

        case CSFForceQuickActionTypeUnknown:
        default:
            return nil;
    }
}

CSFForceQuickActionType CSFForceTypeForQuickActionTypeName(NSString *name) {
    if ([name isEqualToString:@"Create"]) {
        return CSFForceQuickActionTypeCreate;
    } else if ([name isEqualToString:@"Visualforce"]) {
        return CSFForceQuickActionTypeVisualforce;
    } else if ([name isEqualToString:@"Post"]) {
        return CSFForceQuickActionTypePost;
    } else if ([name isEqualToString:@"Feed"]) {
        return CSFForceQuickActionTypeFeed;
    } else if ([name isEqualToString:@"Poll"]) {
        return CSFForceQuickActionTypePoll;
    } else if ([name isEqualToString:@"File"]) {
        return CSFForceQuickActionTypeFile;
    } else if ([name isEqualToString:@"Thanks"]) {
        return CSFForceQuickActionTypeThanks;
    } else {
        return CSFForceQuickActionTypeUnknown;
    }
}

void CSFForcePrimitiveQuickActionTypeFormatter(id value, CSFPrimitivePointer outputStruct) {
    if (outputStruct.integerPtr && [value isKindOfClass:[NSString class]]) {
        *outputStruct.integerPtr = CSFForceTypeForQuickActionTypeName((NSString *)value);
    }
}

NSString * CSFForceStringValueForNotificationFrequency(CSFForceNotificationFrequency type) {
    switch (type) {
        case CSFForceNotificationFrequencyEachPost:
            return @"P";

        case CSFForceNotificationFrequencyDailyDigest:
            return @"D";

        case CSFForceNotificationFrequencyWeeklyDigest:
            return @"W";

        case CSFForceNotificationFrequencyNever:
            return @"N";

        case CSFForceNotificationFrequencyUnknown:
        default:
            return nil;
    }
}

CSFForceNotificationFrequency CSFForceTypeForNotificationFrequencyName(NSString *name) {
    if ([name isEqualToString:@"P"]) {
        return CSFForceNotificationFrequencyEachPost;
    } else if ([name isEqualToString:@"D"]) {
        return CSFForceNotificationFrequencyDailyDigest;
    } else if ([name isEqualToString:@"W"]) {
        return CSFForceNotificationFrequencyWeeklyDigest;
    } else if ([name isEqualToString:@"N"]) {
        return CSFForceNotificationFrequencyNever;
    } else {
        return CSFForceNotificationFrequencyUnknown;
    }
}

void CSFForcePrimitiveNotificationFrequencyFormatter(id value, CSFPrimitivePointer outputStruct) {
    if (outputStruct.integerPtr && [value isKindOfClass:[NSString class]]) {
        *outputStruct.integerPtr = CSFForceTypeForNotificationFrequencyName((NSString *)value);
    }
}

NSString * CSFForceStringValueForPortalRoleType(CSFForcePortalRoleType type) {
    switch (type) {
        case CSFForcePortalRoleTypeExecutive:
            return @"Executive";

        case CSFForcePortalRoleTypeManager:
            return @"Manager";

        case CSFForcePortalRoleTypeUser:
            return @"User";

        case CSFForcePortalRoleTypePersonAccount:
            return @"PersonAccount";

        case CSFForcePortalRoleTypeUnknown:
        default:
            return nil;
    }
}

CSFForcePortalRoleType CSFForceTypeForPortalRoleTypeName(NSString *name) {
    if ([name isEqualToString:@"Executive"]) {
        return CSFForcePortalRoleTypeExecutive;
    } else if ([name isEqualToString:@"Manager"]) {
        return CSFForcePortalRoleTypeManager;
    } else if ([name isEqualToString:@"User"]) {
        return CSFForcePortalRoleTypeUser;
    } else if ([name isEqualToString:@"PersonAccount"]) {
        return CSFForcePortalRoleTypePersonAccount;
    } else {
        return CSFForcePortalRoleTypeUnknown;
    }
}

void CSFForcePrimitivePortalRoleTypeFormatter(id value, CSFPrimitivePointer outputStruct) {
    if (outputStruct.integerPtr && [value isKindOfClass:[NSString class]]) {
        *outputStruct.integerPtr = CSFForceTypeForPortalRoleTypeName((NSString *)value);
    }
}

NSString * CSFForceStringValueForPortalType(CSFForcePortalType type) {
    switch (type) {
        case CSFForcePortalTypeNone:
            return @"None";

        case CSFForcePortalTypeCustomerPortal:
            return @"CustomerPortal";

        case CSFForcePortalTypePartner:
            return @"Partner";

        case CSFForcePortalTypeUnknown:
        default:
            return nil;
    }
}

CSFForcePortalType CSFForceTypeForPortalTypeName(NSString *name) {
    if ([name isEqualToString:@"None"]) {
        return CSFForcePortalTypeNone;
    } else if ([name isEqualToString:@"CustomerPortal"]) {
        return CSFForcePortalTypeCustomerPortal;
    } else if ([name isEqualToString:@"Partner"]) {
        return CSFForcePortalTypePartner;
    } else {
        return CSFForcePortalTypeUnknown;
    }
}

void CSFForcePrimitivePortalTypeFormatter(id value, CSFPrimitivePointer outputStruct) {
    if (outputStruct.integerPtr && [value isKindOfClass:[NSString class]]) {
        *outputStruct.integerPtr = CSFForceTypeForPortalTypeName((NSString *)value);
    }
}

NSString * CSFForceStringValueForFieldMetadataType(CSFForceFieldMetadataType type) {
    switch (type) {
        case CSFForceFieldMetadataTypeBase64:
            return @"base64";

        case CSFForceFieldMetadataTypeBoolean:
            return @"boolean";

        case CSFForceFieldMetadataTypeComboBox:
            return @"combobox";

        case CSFForceFieldMetadataTypeCurrency:
            return @"currency";

        case CSFForceFieldMetadataTypeDate:
            return @"date";

        case CSFForceFieldMetadataTypeDateTime:
            return @"datetime";

        case CSFForceFieldMetadataTypeDouble:
            return @"double";

        case CSFForceFieldMetadataTypeEmail:
            return @"email";

        case CSFForceFieldMetadataTypeEncryptedString:
            return @"encryptedstring";

        case CSFForceFieldMetadataTypeId:
            return @"id";

        case CSFForceFieldMetadataTypeInteger:
            return @"integer";

        case CSFForceFieldMetadataTypeInt:
            return @"int";

        case CSFForceFieldMetadataTypeMultiPickList:
            return @"multipicklist";

        case CSFForceFieldMetadataTypePercent:
            return @"percent";

        case CSFForceFieldMetadataTypePhone:
            return @"phone";

        case CSFForceFieldMetadataTypePickList:
            return @"picklist";

        case CSFForceFieldMetadataTypeString:
            return @"string";

        case CSFForceFieldMetadataTypeReference:
            return @"reference";

        case CSFForceFieldMetadataTypeTextArea:
            return @"textarea";

        case CSFForceFieldMetadataTypeTime:
            return @"time";

        case CSFForceFieldMetadataTypeUrl:
            return @"url";

        case CSFForceFieldMetadataTypeUnknown:
        default:
            return nil;
    }
}

CSFForceFieldMetadataType CSFForceTypeForFieldMetadataTypeName(NSString *name) {
    if ([name isEqualToString:@"base64"]) {
        return CSFForceFieldMetadataTypeBase64;
    } else if ([name isEqualToString:@"boolean"]) {
        return CSFForceFieldMetadataTypeBoolean;
    } else if ([name isEqualToString:@"combobox"]) {
        return CSFForceFieldMetadataTypeComboBox;
    } else if ([name isEqualToString:@"currency"]) {
        return CSFForceFieldMetadataTypeCurrency;
    } else if ([name isEqualToString:@"date"]) {
        return CSFForceFieldMetadataTypeDate;
    } else if ([name isEqualToString:@"datetime"]) {
        return CSFForceFieldMetadataTypeDateTime;
    } else if ([name isEqualToString:@"double"]) {
        return CSFForceFieldMetadataTypeDouble;
    } else if ([name isEqualToString:@"email"]) {
        return CSFForceFieldMetadataTypeEmail;
    } else if ([name isEqualToString:@"encryptedstring"]) {
        return CSFForceFieldMetadataTypeEncryptedString;
    } else if ([name isEqualToString:@"id"]) {
        return CSFForceFieldMetadataTypeId;
    } else if ([name isEqualToString:@"integer"]) {
        return CSFForceFieldMetadataTypeInteger;
    } else if ([name isEqualToString:@"int"]) {
        return CSFForceFieldMetadataTypeInt;
    } else if ([name isEqualToString:@"multipicklist"]) {
        return CSFForceFieldMetadataTypeMultiPickList;
    } else if ([name isEqualToString:@"percent"]) {
        return CSFForceFieldMetadataTypePercent;
    } else if ([name isEqualToString:@"phone"]) {
        return CSFForceFieldMetadataTypePhone;
    } else if ([name isEqualToString:@"picklist"]) {
        return CSFForceFieldMetadataTypePickList;
    } else if ([name isEqualToString:@"string"]) {
        return CSFForceFieldMetadataTypeString;
    } else if ([name isEqualToString:@"reference"]) {
        return CSFForceFieldMetadataTypeReference;
    } else if ([name isEqualToString:@"textarea"]) {
        return CSFForceFieldMetadataTypeTextArea;
    } else if ([name isEqualToString:@"time"]) {
        return CSFForceFieldMetadataTypeTime;
    } else if ([name isEqualToString:@"url"]) {
        return CSFForceFieldMetadataTypeUrl;
    } else {
        return CSFForceFieldMetadataTypeUnknown;
    }
}

void CSFForcePrimitiveFieldMetadataTypeFormatter(id value, CSFPrimitivePointer outputStruct) {
    if (outputStruct.integerPtr && [value isKindOfClass:[NSString class]]) {
        *outputStruct.integerPtr = CSFForceTypeForFieldMetadataTypeName((NSString *)value);
    }
}

NSString * CSFForceStringValueForTaskStatus(CSFForceTaskStatus type) {
    switch (type) {
        case CSFForceTaskStatusNotStarted:
            return @"Not Started";

        case CSFForceTaskStatusInProgress:
            return @"In Progress";

        case CSFForceTaskStatusCompleted:
            return @"Completed";

        case CSFForceTaskStatusWaitingonsomeoneelse:
            return @"Waiting on someone else";

        case CSFForceTaskStatusDeferred:
            return @"Deferred";

        case CSFForceTaskStatusUnknown:
        default:
            return nil;
    }
}

CSFForceTaskStatus CSFForceTypeForTaskStatusName(NSString *name) {
    if ([name isEqualToString:@"Not Started"]) {
        return CSFForceTaskStatusNotStarted;
    } else if ([name isEqualToString:@"In Progress"]) {
        return CSFForceTaskStatusInProgress;
    } else if ([name isEqualToString:@"Completed"]) {
        return CSFForceTaskStatusCompleted;
    } else if ([name isEqualToString:@"Waiting on someone else"]) {
        return CSFForceTaskStatusWaitingonsomeoneelse;
    } else if ([name isEqualToString:@"Deferred"]) {
        return CSFForceTaskStatusDeferred;
    } else {
        return CSFForceTaskStatusUnknown;
    }
}

void CSFForcePrimitiveTaskStatusFormatter(id value, CSFPrimitivePointer outputStruct) {
    if (outputStruct.integerPtr && [value isKindOfClass:[NSString class]]) {
        *outputStruct.integerPtr = CSFForceTypeForTaskStatusName((NSString *)value);
    }
}

NSString * CSFForceStringValueForTaskPriority(CSFForceTaskPriority type) {
    switch (type) {
        case CSFForceTaskPriorityHigh:
            return @"High";

        case CSFForceTaskPriorityNormal:
            return @"Normal";

        case CSFForceTaskPriorityLow:
            return @"Low";

        case CSFForceTaskPriorityUnknown:
        default:
            return nil;
    }
}

CSFForceTaskPriority CSFForceTypeForTaskPriorityName(NSString *name) {
    if ([name isEqualToString:@"High"]) {
        return CSFForceTaskPriorityHigh;
    } else if ([name isEqualToString:@"Normal"]) {
        return CSFForceTaskPriorityNormal;
    } else if ([name isEqualToString:@"Low"]) {
        return CSFForceTaskPriorityLow;
    } else {
        return CSFForceTaskPriorityUnknown;
    }
}

void CSFForcePrimitiveTaskPriorityFormatter(id value, CSFPrimitivePointer outputStruct) {
    if (outputStruct.integerPtr && [value isKindOfClass:[NSString class]]) {
        *outputStruct.integerPtr = CSFForceTypeForTaskPriorityName((NSString *)value);
    }
}

NSString * CSFForceStringValueForTaskCallType(CSFForceTaskCallType type) {
    switch (type) {
        case CSFForceTaskCallTypeInternal:
            return @"Internal";

        case CSFForceTaskCallTypeInbound:
            return @"Inbound";

        case CSFForceTaskCallTypeOutbound:
            return @"Outbound";

        case CSFForceTaskCallTypeUnknown:
        default:
            return nil;
    }
}

CSFForceTaskCallType CSFForceTypeForTaskCallTypeName(NSString *name) {
    if ([name isEqualToString:@"Internal"]) {
        return CSFForceTaskCallTypeInternal;
    } else if ([name isEqualToString:@"Inbound"]) {
        return CSFForceTaskCallTypeInbound;
    } else if ([name isEqualToString:@"Outbound"]) {
        return CSFForceTaskCallTypeOutbound;
    } else {
        return CSFForceTaskCallTypeUnknown;
    }
}

void CSFForcePrimitiveTaskCallTypeFormatter(id value, CSFPrimitivePointer outputStruct) {
    if (outputStruct.integerPtr && [value isKindOfClass:[NSString class]]) {
        *outputStruct.integerPtr = CSFForceTypeForTaskCallTypeName((NSString *)value);
    }
}

NSString * CSFForceStringValueForTaskRecurrenceType(CSFForceTaskRecurrenceType type) {
    switch (type) {
        case CSFForceTaskRecurrenceTypeRecursDaily:
            return @"RecursDaily";

        case CSFForceTaskRecurrenceTypeRecursEveryWeekday:
            return @"RecursEveryWeekday";

        case CSFForceTaskRecurrenceTypeRecursMonthly:
            return @"RecursMonthly";

        case CSFForceTaskRecurrenceTypeRecursMonthyNth:
            return @"RecursMonthlyNth";

        case CSFForceTaskRecurrenceTypeRecursWeekly:
            return @"RecursWeekly";

        case CSFForceTaskRecurrenceTypeRecursYearly:
            return @"RecursYearly";

        case CSFForceTaskRecurrenceTypeRecursYearlyNth:
            return @"RecursYearlyNth";

        case CSFForceTaskRecurrenceTypeUnknown:
        default:
            return nil;
    }
}

CSFForceTaskRecurrenceType CSFForceTypeForTaskRecurrenceTypeName(NSString *name) {
    if ([name isEqualToString:@"RecursDaily"]) {
        return CSFForceTaskRecurrenceTypeRecursDaily;
    } else if ([name isEqualToString:@"RecursEveryWeekday"]) {
        return CSFForceTaskRecurrenceTypeRecursEveryWeekday;
    } else if ([name isEqualToString:@"RecursMonthly"]) {
        return CSFForceTaskRecurrenceTypeRecursMonthly;
    } else if ([name isEqualToString:@"RecursMonthlyNth"]) {
        return CSFForceTaskRecurrenceTypeRecursMonthyNth;
    } else if ([name isEqualToString:@"RecursWeekly"]) {
        return CSFForceTaskRecurrenceTypeRecursWeekly;
    } else if ([name isEqualToString:@"RecursYearly"]) {
        return CSFForceTaskRecurrenceTypeRecursYearly;
    } else if ([name isEqualToString:@"RecursYearlyNth"]) {
        return CSFForceTaskRecurrenceTypeRecursYearlyNth;
    } else {
        return CSFForceTaskRecurrenceTypeUnknown;
    }
}

void CSFForcePrimitiveTaskRecurrenceTypeFormatter(id value, CSFPrimitivePointer outputStruct) {
    if (outputStruct.integerPtr && [value isKindOfClass:[NSString class]]) {
        *outputStruct.integerPtr = CSFForceTypeForTaskRecurrenceTypeName((NSString *)value);
    }
}

NSString * CSFForceStringValueForTaskRecurrenceInstance(CSFForceTaskRecurrenceInstance type) {
    switch (type) {
        case CSFForceTaskRecurrenceInstance1st:
            return @"First";

        case CSFForceTaskRecurrenceInstance2nd:
            return @"Second";

        case CSFForceTaskRecurrenceInstance3rd:
            return @"Third";

        case CSFForceTaskRecurrenceInstance4th:
            return @"Fourth";

        case CSFForceTaskRecurrenceInstanceLast:
            return @"Last";

        case CSFForceTaskRecurrenceInstanceUnknown:
        default:
            return nil;
    }
}

CSFForceTaskRecurrenceInstance CSFForceTypeForTaskRecurrenceInstanceName(NSString *name) {
    if ([name isEqualToString:@"First"]) {
        return CSFForceTaskRecurrenceInstance1st;
    } else if ([name isEqualToString:@"Second"]) {
        return CSFForceTaskRecurrenceInstance2nd;
    } else if ([name isEqualToString:@"Third"]) {
        return CSFForceTaskRecurrenceInstance3rd;
    } else if ([name isEqualToString:@"Fourth"]) {
        return CSFForceTaskRecurrenceInstance4th;
    } else if ([name isEqualToString:@"Last"]) {
        return CSFForceTaskRecurrenceInstanceLast;
    } else {
        return CSFForceTaskRecurrenceInstanceUnknown;
    }
}

void CSFForcePrimitiveTaskRecurrenceInstanceFormatter(id value, CSFPrimitivePointer outputStruct) {
    if (outputStruct.integerPtr && [value isKindOfClass:[NSString class]]) {
        *outputStruct.integerPtr = CSFForceTypeForTaskRecurrenceInstanceName((NSString *)value);
    }
}

NSString * CSFForceStringValueForTaskRecurrenceMonthOfYear(CSFForceTaskRecurrenceMonthOfYear type) {
    switch (type) {
        case CSFForceTaskRecurrenceMonthOfYearJanuary:
            return @"January";

        case CSFForceTaskRecurrenceMonthOfYearFebruary:
            return @"February";

        case CSFForceTaskRecurrenceMonthOfYearMarch:
            return @"March";

        case CSFForceTaskRecurrenceMonthOfYearApril:
            return @"April";

        case CSFForceTaskRecurrenceMonthOfYearMay:
            return @"May";

        case CSFForceTaskRecurrenceMonthOfYearJune:
            return @"June";

        case CSFForceTaskRecurrenceMonthOfYearJuly:
            return @"July";

        case CSFForceTaskRecurrenceMonthOfYearAugust:
            return @"August";

        case CSFForceTaskRecurrenceMonthOfYearSeptember:
            return @"September";

        case CSFForceTaskRecurrenceMonthOfYearOctober:
            return @"October";

        case CSFForceTaskRecurrenceMonthOfYearNovember:
            return @"November";

        case CSFForceTaskRecurrenceMonthOfYearDecember:
            return @"December";

        case CSFForceTaskRecurrenceMonthOfYearUnknown:
        default:
            return nil;
    }
}

CSFForceTaskRecurrenceMonthOfYear CSFForceTypeForTaskRecurrenceMonthOfYearName(NSString *name) {
    if ([name isEqualToString:@"January"]) {
        return CSFForceTaskRecurrenceMonthOfYearJanuary;
    } else if ([name isEqualToString:@"February"]) {
        return CSFForceTaskRecurrenceMonthOfYearFebruary;
    } else if ([name isEqualToString:@"March"]) {
        return CSFForceTaskRecurrenceMonthOfYearMarch;
    } else if ([name isEqualToString:@"April"]) {
        return CSFForceTaskRecurrenceMonthOfYearApril;
    } else if ([name isEqualToString:@"May"]) {
        return CSFForceTaskRecurrenceMonthOfYearMay;
    } else if ([name isEqualToString:@"June"]) {
        return CSFForceTaskRecurrenceMonthOfYearJune;
    } else if ([name isEqualToString:@"July"]) {
        return CSFForceTaskRecurrenceMonthOfYearJuly;
    } else if ([name isEqualToString:@"August"]) {
        return CSFForceTaskRecurrenceMonthOfYearAugust;
    } else if ([name isEqualToString:@"September"]) {
        return CSFForceTaskRecurrenceMonthOfYearSeptember;
    } else if ([name isEqualToString:@"October"]) {
        return CSFForceTaskRecurrenceMonthOfYearOctober;
    } else if ([name isEqualToString:@"November"]) {
        return CSFForceTaskRecurrenceMonthOfYearNovember;
    } else if ([name isEqualToString:@"December"]) {
        return CSFForceTaskRecurrenceMonthOfYearDecember;
    } else {
        return CSFForceTaskRecurrenceMonthOfYearUnknown;
    }
}

void CSFForcePrimitiveTaskRecurrenceMonthOfYearFormatter(id value, CSFPrimitivePointer outputStruct) {
    if (outputStruct.integerPtr && [value isKindOfClass:[NSString class]]) {
        *outputStruct.integerPtr = CSFForceTypeForTaskRecurrenceMonthOfYearName((NSString *)value);
    }
}

NSString * CSFForceStringValueForRecordType(CSFForceRecordType type) {
    switch (type) {
        case CSFForceRecordTypeAccount:
            return @"Account";

        case CSFForceRecordTypeContact:
            return @"Contact";

        case CSFForceRecordTypeTask:
            return @"Task";

        case CSFForceRecordTypeCase:
            return @"Case";

        case CSFForceRecordTypeContract:
            return @"Contract";

        case CSFForceRecordTypeOpportunity:
            return @"Opportunity";

        case CSFForceRecordTypeQuote:
            return @"Quote";

        case CSFForceRecordTypeLead:
            return @"Lead";

        case CSFForceRecordTypeCampaign:
            return @"Campaign";

        case CSFForceRecordTypeOther:
        default:
            return nil;
    }
}

CSFForceRecordType CSFForceTypeForRecordTypeName(NSString *name) {
    if ([name isEqualToString:@"Account"]) {
        return CSFForceRecordTypeAccount;
    } else if ([name isEqualToString:@"Contact"]) {
        return CSFForceRecordTypeContact;
    } else if ([name isEqualToString:@"Task"]) {
        return CSFForceRecordTypeTask;
    } else if ([name isEqualToString:@"Case"]) {
        return CSFForceRecordTypeCase;
    } else if ([name isEqualToString:@"Contract"]) {
        return CSFForceRecordTypeContract;
    } else if ([name isEqualToString:@"Opportunity"]) {
        return CSFForceRecordTypeOpportunity;
    } else if ([name isEqualToString:@"Quote"]) {
        return CSFForceRecordTypeQuote;
    } else if ([name isEqualToString:@"Lead"]) {
        return CSFForceRecordTypeLead;
    } else if ([name isEqualToString:@"Campaign"]) {
        return CSFForceRecordTypeCampaign;
    } else {
        return CSFForceRecordTypeOther;
    }
}

void CSFForcePrimitiveRecordTypeFormatter(id value, CSFPrimitivePointer outputStruct) {
    if (outputStruct.integerPtr && [value isKindOfClass:[NSString class]]) {
        *outputStruct.integerPtr = CSFForceTypeForRecordTypeName((NSString *)value);
    }
}
