/*
 Copyright (c) 2014-present, salesforce.com, inc. All rights reserved.
 
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

NSString * const kId = @"Id";
NSString * const kCreatedId = @"id"; // id in sobject create response
NSString * const kName = @"Name";
NSString * const kType = @"Type";
NSString * const kAttributes = @"attributes";
NSString * const kRecentlyViewed = @"RecentlyViewed";
NSString * const kRawData = @"rawData";
NSString * const kObjectTypeField = @"attributes.type";
NSString * const kLastModifiedDate = @"LastModifiedDate";
NSString * const kResponseRecords = @"records";
NSString * const kResponseSearchRecords = @"searchRecords";
NSString * const kResponseTotalSize = @"totalSize";
NSString * const kResponseNextRecordsUrl = @"nextRecordsUrl";
NSString * const kRecentItems = @"recentItems";
NSString * const kCompositeResponse = @"compositeResponse";
NSString * const kHttpStatusCode = @"httpStatusCode";
NSString * const kReferenceId = @"referenceId";
NSString * const kBody = @"body";

NSString * const kAccount = @"Account";
NSString * const kTask = @"Task";
NSString * const kContact = @"Contact";
NSString * const kUser = @"User";
NSString * const kGroup = @"CollaborationGroup";
NSString * const kContent = @"ContentDocument";

NSString * const kSFSyncTargetTypeKey = @"type";
NSString * const kSFSyncTargetiOSImplKey = @"iOSImpl";
NSString * const kSFSyncTargetIdFieldNameKey = @"idFieldName";
NSString * const kSFSyncTargetModificationDateFieldNameKey = @"modificationDateFieldName";
