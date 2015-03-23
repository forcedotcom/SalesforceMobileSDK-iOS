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

#import "SFSmartSyncConstants.h"

NSString * const kEmptyString = @"";
NSString * const kNullString = @"null";

NSString * const kId = @"Id";
NSString * const kName = @"Name";
NSString * const kType = @"Type";
NSString * const kAttributes = @"attributes";
NSString * const kRecentlyViewed = @"RecentlyViewed";
NSString * const kRawData = @"rawData";
NSString * const kObjectTypeField = @"attributes.type";
NSString * const kLastModifiedDate = @"LastModifiedDate";
NSString * const kResponseRecords = @"records";
NSString * const kResponseTotalSize = @"totalSize";
NSString * const kResponseNextRecordsUrl = @"nextRecordsUrl";
NSString * const kRecentItems = @"recentItems";

NSString * const kAccount = @"Account";
NSString * const kLead = @"Lead";
NSString * const kCase = @"Case";
NSString * const kOpportunity = @"Opportunity";
NSString * const kTask = @"Task";
NSString * const kContact = @"Contact";
NSString * const kCampaign = @"Campaign";
NSString * const kUser = @"User";
NSString * const kGroup = @"CollaborationGroup";
NSString * const kDashboard = @"Dashboard";
NSString * const kContent = @"ContentDocument";
NSString * const kContentVersion = @"ContentVersion";

NSString * const kKeyPrefixField = @"keyPrefix";
NSString * const kNameField = @"name";
NSString * const kLabelField = @"label";
NSString * const kLabelPluralField = @"labelPlural";
NSString * const kFieldsField = @"fields";
NSString * const kLayoutableField = @"layoutable";
NSString * const kSearchableField = @"searchable";
NSString * const kHiddenField = @"deprecatedAndHidden";
NSString * const kNameFieldField = @"nameField";
NSString * const kNetworkIdField = @"NetworkId";
NSString * const kNetworkScopeField = @"NetworkScope";

NSString * const kLayoutNameField = @"name";
NSString * const kLayoutFieldField = @"field";
NSString * const kLayoutFormatField = @"format";
NSString * const kLayoutLabelField = @"label";

NSString * const kLayoutLimitsField = @"limitRows";
NSString * const kLayoutColumnsField = @"searchColumns";
NSString * const kLayoutObjectTypeField = @"objectType";

NSString * const kSFSyncTargetTypeKey = @"type";
NSString * const kSFSyncTargetiOSImplKey = @"iOSImpl";
NSString * const kSFSyncTargetIdFieldNameKey = @"idFieldName";
NSString * const kSFSyncTargetModificationDateFieldNameKey = @"modificationDateFieldName";
