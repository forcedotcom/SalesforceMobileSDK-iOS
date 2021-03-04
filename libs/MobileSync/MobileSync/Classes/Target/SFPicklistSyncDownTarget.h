/*
 SFPicklistSyncDownTarget.h
 MobileSync
 
 Created by Keith Siilats 4/28/2020.
 
 Copyright (c) 2018-present, bytelogics.com, inc. All rights reserved.
 
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
#import <SalesforceSDKCore/SalesforceSDKConstants.h>
#import <MobileSync/SFSyncDownTarget.h>

/**
 * Sync down target for object Picklists. This uses the '/ui-api/object-info/../picklist-values' API to fetch object Picklists.
 * The easiest way to use this sync target is through SFPicklistSyncManager.
 */
NS_SWIFT_NAME(PicklistSyncDownTarget)
@interface SFPicklistSyncDownTarget : SFSyncDownTarget

@property (nonnull, nonatomic, strong, readonly) NSString *objectAPIName;
@property (nullable, nonatomic, strong, readonly) NSString *formFactor;
@property (nullable, nonatomic, strong, readonly) NSString *layoutType;
@property (nullable, nonatomic, strong, readonly) NSString *mode;
@property (nullable, nonatomic, strong, readonly) NSString *recordTypeId;

/**
 * Factory method.
 */
+ (nonnull SFPicklistSyncDownTarget *)newSyncTarget:(nonnull NSString *)objectAPIName formFactor:(nullable NSString *)formFactor layoutType:(nullable NSString *)layoutType mode:(nullable NSString *)mode recordTypeId:(nullable NSString *)recordTypeId;

@end
