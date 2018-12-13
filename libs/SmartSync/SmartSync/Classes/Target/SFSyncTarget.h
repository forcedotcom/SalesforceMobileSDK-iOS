/*
 Copyright (c) 2015-present, salesforce.com, inc. All rights reserved.
 
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

NS_ASSUME_NONNULL_BEGIN

@class SFSmartSyncSyncManager;

@interface SFSyncTarget : NSObject

extern NSString * const kSyncTargetLocal;
extern NSString * const kSyncTargetLocallyCreated;
extern NSString * const kSyncTargetLocallyUpdated;
extern NSString * const kSyncTargetLocallyDeleted;
extern NSString * const kSyncTargetSyncId;
extern NSString * const kSyncTargetLastError;

/**
 The field name of the ID field of the record.  Defaults to "Id".
 */
@property (nonatomic, copy) NSString *idFieldName;

/**
 The field name of the modification date field of the record.  Defaults to "LastModifiedDate".
 */
@property (nonatomic, copy) NSString *modificationDateFieldName;

/**
 Designated initializer that initializes a sync target from the given dictionary.
 @param dict The sync target serialized to an NSDictionary.
 */
- (instancetype)initWithDict:(NSDictionary *)dict;

/**
 The target represented as a dictionary.  Note: inheriting classes should initialize their
 dictionary from the super representation, as each parent class can add fields to the
 dictionary along the way.
 @return The target represented as a dictionary.
 */
- (NSMutableDictionary *)asDict;

/**
 * Save record in local store (marked as clean)
 * @param syncManager The sync manager
 * @param soupName The soup
 * @param record The record
 */
- (void) cleanAndSaveInLocalStore:(SFSmartSyncSyncManager*)syncManager soupName:(NSString*)soupName record:(NSDictionary*)record;

/**
 * Save records in local store (marked as clean)
 * @param syncManager The sync manager
 * @param soupName The soup
 * @param records The records to save
 * @param syncId The sync id
 */
- (void)cleanAndSaveRecordsToLocalStore:(SFSmartSyncSyncManager *)syncManager soupName:(NSString *)soupName records:(NSArray *)records syncId:(NSNumber *)syncId;

/**
 * @param record The record
 * @return YES if record was locally created
 */
- (BOOL) isLocallyCreated:(NSDictionary*)record;

/**
 * @param record The record
 * @return YES if record was locally updated
 */
- (BOOL) isLocallyUpdated:(NSDictionary*)record;

/**
 * @param record The record
 * @return YES if record was locally deleted
 */
- (BOOL) isLocallyDeleted:(NSDictionary*)record;

/**
 * @param record The record
 * @return YES if record was locally created/updated or deleted
*/
- (BOOL) isDirty:(NSDictionary*)record;

/**
 *
 * @param syncManager The sync manager
 * @param soupName The soup
 * @param idField The field containing the ids to return
 * @return ids of "dirty" records (records locally created/upated or deleted)
 */
- (NSOrderedSet*) getDirtyRecordIds:(SFSmartSyncSyncManager*)syncManager soupName:(NSString*)soupName idField:(NSString*)idField;

/**
 * @param syncManager The sync manager
 * @param soupName The soup
 * @param storeId The soup entry id
 * @return Record from local store by storeId
 */
- (NSDictionary*) getFromLocalStore:(SFSmartSyncSyncManager *)syncManager soupName:(NSString*)soupName storeId:(NSString*)storeId;

/**
 * Delete record from local store
 * @param syncManager The sync manager
 * @param soupName The soup
 * @param record The record to delete
 */
- (void) deleteFromLocalStore:(SFSmartSyncSyncManager *)syncManager soupName:(NSString*)soupName record:(NSDictionary*)record;

@end

NS_ASSUME_NONNULL_END
