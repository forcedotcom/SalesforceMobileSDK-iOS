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
#import "SFSyncTarget.h"

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
 Block definition for returning record modification information.
 */
typedef void (^SFSyncUpRecordModificationResultBlock)(NSDate *localModificationDate, NSDate *remoteModificationDate, NSError *error);

/**
 Block definition for calling a sync up completion block.
 */
typedef void (^SFSyncUpTargetCompleteBlock)(NSDictionary *syncUpResult);

/**
 Block definition for calling a sync up failure block.
 */
typedef void (^SFSyncUpTargetErrorBlock)(NSError *error);

/**
 Base class for a server target, used to manage sync ups to the configured service.
 */
@interface SFSyncUpTarget : SFSyncTarget

/**
 The type of server target represented by this instance.
 */
@property (nonatomic, assign) SFSyncUpTargetType targetType;

/**
 Creates a new instance of a server target from a serialized dictionary.
 @param dict The dictionary with the serialized server target.
 */
+ (instancetype)newFromDict:(NSDictionary *)dict;

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
 Gives the current modification times of a record, on the client and on the server.
 @param record The record to query for modification times.
 @param modificationResultBlock The block to execute with the modification date values.
 */
- (void)fetchRecordModificationDates:(NSDictionary *)record
             modificationResultBlock:(SFSyncUpRecordModificationResultBlock)modificationResultBlock;

/**
 Save locally created record back to server
 @param objectType The object type of the record.
 @param fields The map of record attribute names to values.
 @param completionBlock The block to execute after the server call completes.
 @param failBlock The block to execute if the server call fails.
 */
- (void)createOnServer:(NSString*)objectType
                fields:(NSDictionary*)fields
       completionBlock:(SFSyncUpTargetCompleteBlock)completionBlock
             failBlock:(SFSyncUpTargetErrorBlock)failBlock;

/**
 Save locally updated record back to server
 @param objectType The object type of the record.
 @param objectId The object id of the record.
 @param fields The map of record attribute names to values.
 @param completionBlock The block to execute after the server call completes.
 @param failBlock The block to execute if the server call fails.
 */
- (void)updateOnServer:(NSString*)objectType
              objectId:(NSString*)objectId
                fields:(NSDictionary*)fields
       completionBlock:(SFSyncUpTargetCompleteBlock)completionBlock
             failBlock:(SFSyncUpTargetErrorBlock)failBlock;

/**
 Delete locally deleted record from server
 @param objectType The object type of the record.
 @param objectId The object id of the record.
 @param completionBlock The block to execute after the server call completes.
 @param failBlock The block to execute if the server call fails.
 */
- (void)deleteOnServer:(NSString*)objectType
              objectId:(NSString*)objectId
       completionBlock:(SFSyncUpTargetCompleteBlock)completionBlock
             failBlock:(SFSyncUpTargetErrorBlock)failBlock;


/**
 Return set of record ids (soup element ids) that need to be sent up to the server
 @param syncManager The sync manager running the sync.
 @param soupName The soup name to look into for records.
 */
- (NSArray*)getIdsOfRecordsToSyncUp:(SFSmartSyncSyncManager*)syncManager
                           soupName:(NSString*)soupName;
@end
