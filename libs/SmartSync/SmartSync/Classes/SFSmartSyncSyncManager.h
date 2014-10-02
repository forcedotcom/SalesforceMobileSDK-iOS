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

@class SFUserAccount;

NSString * const kSyncsSoup = @"syncs_soup";
NSString * const kSyncsSoupType = @"type";
NSString * const kSyncLocal = @"__local__";
NSString * const kSyncLocallyCreated = @"__locally_created__";
NSString * const kSyncLocallyUpdated = @"__locally_updated__";
NSString * const kSyncLocallyDeleted = @"__locally_deleted__";


/** This class provides methods for doing synching records to/from the server from/to the smartstore.
 */
@interface SFSmartSyncSyncManager : NSObject

/** Singleton method for accessing cache manager instance.
 @param user A user that will scope this manager instance data
 */
+ (id)sharedInstance:(SFUserAccount *)user;

/** Removes the shared instance associated with the specified user
 @param user The user
 */
+ (void)removeSharedInstance:(SFUserAccount *)user;

/** Return details about a sync
 @param syncId
 */
- (NSDictionary*)getSyncStatusWithSyncId:(long)syncId;

/** Create/record a sync but don't start it yet
 */
- (NSDictionary*) recordSyncWithTarget:(NSDictionary*)target withSoupName:(NSString*)soupName withOptions:(NSDictionary*)options;

/** Run a previously created sync
 */
- (void) runSync:(long)syncId;

@end