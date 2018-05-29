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
#import "SFSmartSyncPersistableObject.h"
#import <SalesforceSDKCore/SalesforceSDKConstants.h>

NS_ASSUME_NONNULL_BEGIN

@interface SFObjectType : SFSmartSyncPersistableObject <NSCoding>

/** Object type key prefix */
@property (nonatomic, strong, readonly) NSString *keyPrefix SFSDK_DEPRECATED(6.2, 7.0, "Will be removed in Mobile SDK 7.0.");

/** Object name */
@property (nonatomic, strong, readonly) NSString *name SFSDK_DEPRECATED(6.2, 7.0, "Will be removed in Mobile SDK 7.0.");

/** Object label */
@property (nonatomic, strong, readonly) NSString *label SFSDK_DEPRECATED(6.2, 7.0, "Will be removed in Mobile SDK 7.0.");

/** Object plural label */
@property (nonatomic, strong, readonly) NSString *labelPlural SFSDK_DEPRECATED(6.2, 7.0, "Will be removed in Mobile SDK 7.0.");

/** Object name field */
@property (nonatomic, strong, readonly, nullable) NSString *nameField SFSDK_DEPRECATED(6.2, 7.0, "Will be removed in Mobile SDK 7.0.");

/** Fields, array of NSDictionary objects */
@property (nonatomic, strong, readonly) NSArray *fields SFSDK_DEPRECATED(6.2, 7.0, "Will be removed in Mobile SDK 7.0.");

/** Searchable */
- (BOOL)isSearchable SFSDK_DEPRECATED(6.2, 7.0, "Will be removed in Mobile SDK 7.0.");

/** Layoutable */
- (BOOL)isLayoutable SFSDK_DEPRECATED(6.2, 7.0, "Will be removed in Mobile SDK 7.0.");

@end

NS_ASSUME_NONNULL_END
