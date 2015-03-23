/*
 Copyright (c) 2014, salesforce.com, inc. All rights reserved.
 
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

extern NSString * const kEmptyString;
extern NSString * const kNullString;

extern NSString * const kId;
extern NSString * const kName;
extern NSString * const kType;
extern NSString * const kAttributes;
extern NSString * const kRecentlyViewed;
extern NSString * const kRawData;
extern NSString * const kObjectTypeField;
extern NSString * const kLastModifiedDate;
extern NSString * const kResponseRecords;
extern NSString * const kResponseTotalSize;
extern NSString * const kResponseNextRecordsUrl;
extern NSString * const kRecentItems;

/**
 * Salesforce object types.
 */
extern NSString * const kAccount;
extern NSString * const kLead;
extern NSString * const kCase;
extern NSString * const kOpportunity;
extern NSString * const kTask;
extern NSString * const kContact;
extern NSString * const kCampaign;
extern NSString * const kUser;
extern NSString * const kGroup;
extern NSString * const kDashboard;
extern NSString * const kContent;
extern NSString * const kContentVersion;

/**
 * Salesforce object type field constants.
 */
extern NSString * const kKeyPrefixField;
extern NSString * const kNameField;
extern NSString * const kLabelField;
extern NSString * const kLabelPluralField;
extern NSString * const kFieldsField;
extern NSString * const kLayoutableField;
extern NSString * const kSearchableField;
extern NSString * const kHiddenField;
extern NSString * const kNameFieldField;
extern NSString * const kNetworkIdField;
extern NSString * const kNetworkScopeField;

/**
 * Salesforce object layout column field constants.
 */
extern NSString * const kLayoutNameField;
extern NSString * const kLayoutFieldField;
extern NSString * const kLayoutFormatField;
extern NSString * const kLayoutLabelField;

/**
 * Salesforce object type layout field constants.
 */
extern NSString * const kLayoutLimitsField;
extern NSString * const kLayoutColumnsField;
extern NSString * const kLayoutObjectTypeField;

/**
 * Sync target constants.
 */
extern NSString * const kSFSyncTargetTypeKey;
extern NSString * const kSFSyncTargetiOSImplKey;
extern NSString * const kSFSyncTargetIdFieldNameKey;
extern NSString * const kSFSyncTargetModificationDateFieldNameKey;
