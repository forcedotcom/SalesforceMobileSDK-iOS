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

#import <Foundation/Foundation.h>
#import "SFSyncTarget.h"

NS_ASSUME_NONNULL_BEGIN

@class SFSmartSyncSyncManager;

/**
 Enumeration of types of server targets.
 */
typedef NS_ENUM(NSUInteger, SFSyncUpTargetType) {
    /**
     The default server target, which uses standard REST requests to post updates.
     */
    SFSyncUpTargetTypeRestStandard,
    
    /**
     Server target is a custom target, that manages its own server update logic.
     */
    SFSyncUpTargetTypeCustom,
};

/**
 Enumeration of the types of actions that can be executed against the server target.
 */
typedef NS_ENUM(NSUInteger, SFSyncUpTargetAction) {
    /**
     No action should be taken against the server.
     */
    SFSyncUpTargetActionNone,
    
    /**
     Created data will be posted to the server.
     */
    SFSyncUpTargetActionCreate,
    
    /**
     Updated data will be posted to the server.
     */
    SFSyncUpTargetActionUpdate,
    
    /**
     Data will be deleted from the server.
     */
    SFSyncUpTargetActionDelete
};

/**
 Block definition for returning whether a records changed on server.
 */
typedef void (^SFSyncUpRecordNewerThanServerBlock)(BOOL isNewerThanServer);

/**
 Block definition for calling a sync up completion block.
 */
typedef void (^SFSyncUpTargetCompleteBlock)(NSDictionary * _Nullable syncUpResult);

/**
 Block definition for calling a sync up failure block.
 */
typedef void (^SFSyncUpTargetErrorBlock)(NSError *error);

/**
 Helper class for isNewerThanServer
 */
@interface SFRecordModDate : NSObject

@property (nonatomic, strong) NSDate*  timestamp;   // time stamp - can be nil if unknown
@property (nonatomic, assign) BOOL isDeleted;       // YES if record was deleted

- (instancetype)initWithTimestamp:(nullable NSString*)timestamp isDeleted:(BOOL)isDeleted;
@end

/**
 Base class for a server target, used to manage sync ups to the configured service.
 */
@interface SFSyncUpTarget : SFSyncTarget

/**
 The type of server target represented by this instance.
 */
@property (nonatomic, assign) SFSyncUpTargetType targetType;


/**
 Create field list (optional)
 */
@property (nonatomic, strong, readonly) NSArray*  createFieldlist;

/**
 Update field list (optional)
 */
@property (nonatomic, strong, readonly) NSArray*  updateFieldlist;

/**
 Creates a new instance of a server target from a serialized dictionary.
 @param dict The dictionary with the serialized server target.
 */
+ (nullable instancetype)newFromDict:(NSDictionary *)dict;

/**
 Converts a string representation of a target type into its target type.
 @param targetType The string representation of the target type.
 @return The target type value.
 */
+ (SFSyncUpTargetType)targetTypeFromString:(NSString*)targetType;

/**
 Gives the string representation of a target type.
 @param targetType The target type to display.
 @return The string representation of the target type.
 */
+ (NSString *)targetTypeToString:(SFSyncUpTargetType)targetType;

/**
 * Constructor
 */
- (instancetype)initWithCreateFieldlist:(nullable NSArray *)createFieldlist
                        updateFieldlist:(nullable NSArray *)updateFieldlist;

/**
 Call resultBlock with YES if record is more recent than corresponding record on server
 NB: also call resultBlock true if both were deleted or if local mod date is missing
 Used to decide whether a record should be synced up or not when using merge mode leave-if-changed
 @param record The record
 @param resultBlock The block to execute
 */
- (void)isNewerThanServer:(SFSmartSyncSyncManager *)syncManager
                   record:(NSDictionary*)record
             resultBlock:(SFSyncUpRecordNewerThanServerBlock)resultBlock;

/**
 Save locally created record back to server
 @param syncManager The sync manager doing the sync
 @param record The record being synced
 @param fieldlist List of fields to send to server
 @param completionBlock The block to execute after the server call completes.
 @param failBlock The block to execute if the server call fails.
 */
- (void)createOnServer:(SFSmartSyncSyncManager *)syncManager
                record:(NSDictionary*)record
             fieldlist:(NSArray*)fieldlist
       completionBlock:(SFSyncUpTargetCompleteBlock)completionBlock
             failBlock:(SFSyncUpTargetErrorBlock)failBlock;

/**
 Save locally updated record back to server
 @param syncManager The sync manager doing the sync
 @param record The record being synced
 @param fieldlist List of fields to send to server
 @param completionBlock The block to execute after the server call completes.
 @param failBlock The block to execute if the server call fails.
 */
- (void)updateOnServer:(SFSmartSyncSyncManager *)syncManager
                record:(NSDictionary*)record
             fieldlist:(NSArray*)fieldlist
       completionBlock:(SFSyncUpTargetCompleteBlock)completionBlock
             failBlock:(SFSyncUpTargetErrorBlock)failBlock;

/**
 Delete locally deleted record from server
 @param syncManager The sync manager doing the sync
 @param record The record being synced
 @param completionBlock The block to execute after the server call completes.
 @param failBlock The block to execute if the server call fails.
 */
- (void)deleteOnServer:(SFSmartSyncSyncManager *)syncManager
                record:(NSDictionary*)record
       completionBlock:(SFSyncUpTargetCompleteBlock)completionBlock
             failBlock:(SFSyncUpTargetErrorBlock)failBlock;


/**
 Return set of record ids (soup element ids) that need to be sent up to the server
 @param syncManager The sync manager running the sync.
 @param soupName The soup name to look into for records.
 */
- (NSArray *)getIdsOfRecordsToSyncUp:(SFSmartSyncSyncManager *)syncManager
                            soupName:(NSString *)soupName;
/**
 Save record with last error if any
 @param syncManager The sync manager doing the sync
 @param soupName the soup to save the record to
 @param record The record being synced
 */
- (void) saveRecordToLocalStoreWithLastError:(SFSmartSyncSyncManager*)syncManager
                                    soupName:(NSString*) soupName
                                      record:(NSDictionary*) record;

@end

NS_ASSUME_NONNULL_END
