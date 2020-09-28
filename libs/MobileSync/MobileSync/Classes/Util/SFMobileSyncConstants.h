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

#import <Foundation/Foundation.h>

extern NSString * const kId;
extern NSString * const kCreatedId;
extern NSString * const kName;
extern NSString * const kType;
extern NSString * const kAttributes;
extern NSString * const kRecentlyViewed;
extern NSString * const kRawData;
extern NSString * const kObjectTypeField;
extern NSString * const kLastModifiedDate;
extern NSString * const kResponseRecords;
extern NSString * const kResponseSearchRecords;
extern NSString * const kResponseTotalSize;
extern NSString * const kResponseNextRecordsUrl;
extern NSString * const kRecentItems;

/**
 * Salesforce object types.
 */
extern NSString * const kAccount;
extern NSString * const kTask;
extern NSString * const kContact;
extern NSString * const kUser;
extern NSString * const kGroup;
extern NSString * const kContent;

/**
 * Sync target constants.
 */
extern NSString * const kSFSyncTargetTypeKey;
extern NSString * const kSFSyncTargetiOSImplKey;
extern NSString * const kSFSyncTargetIdFieldNameKey;
extern NSString * const kSFSyncTargetModificationDateFieldNameKey;

/**
 * Enum for available MobileSync data fetch modes.
 *
 * SFSDKFetchModeCacheOnly - Fetches data from the cache and returns null if no data is available.
 * SFSDKFetchModeCacheFirst - Fetches data from the cache and falls back on the server if no data is available.
 * SFSDKFetchModeServerFirst - Fetches data from the server and falls back on the cache if the server doesn't
 * return data. The data fetched from the server is automatically cached.
 */
typedef NS_ENUM(NSInteger, SFSDKFetchMode) {
    SFSDKFetchModeCacheOnly = 0,
    SFSDKFetchModeCacheFirst,
    SFSDKFetchModeServerFirst
} NS_SWIFT_NAME(FetchMode);
