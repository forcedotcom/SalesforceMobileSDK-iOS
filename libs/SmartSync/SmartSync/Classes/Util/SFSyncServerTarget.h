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

/**
 Enumeration of types of server targets.
 */
typedef NS_ENUM(NSUInteger, SFSyncServerTargetType) {
    /**
     The default server target, which uses standard REST requests to post updates.
     */
    SFSyncServerTargetTypeRestStandard,
    
    /**
     Server target is a custom target, that manages its own server update logic.
     */
    SFSyncServerTargetTypeCustom,
};

/**
 Enumeration of the types of actions that can be executed against the server target.
 */
typedef NS_ENUM(NSUInteger, SFSyncServerTargetAction) {
    /**
     No action should be taken against the server.
     */
    SFSyncServerTargetActionNone,
    
    /**
     Created data will be posted to the server.
     */
    SFSyncServerTargetActionCreate,
    
    /**
     Updated data will be posted to the server.
     */
    SFSyncServerTargetActionUpdate,
    
    /**
     Data will be deleted from the server.
     */
    SFSyncServerTargetActionDelete
};

/**
 Base class for a server target, used to manage sync ups to the configured service.
 */
@interface SFSyncServerTarget : NSObject

/**
 The type of server target represented by this instance.
 */
@property (nonatomic, assign) SFSyncServerTargetType targetType;

/**
 Creates a new instance of a server target from a serialized dictionary.
 @param dict The dictionary with the serialized server target.
 */
+ (instancetype)newFromDict:(NSDictionary *)dict;

/**
 Serializes the server target to a dictionary.
 @return The serialized server target in an NSDictionary.
 */
- (NSDictionary *)asDict;

/**
 Converts a string representation of a target type into its target type.
 @param targetType The string representation of the target type.
 @return The target type value.
 */
+ (SFSyncServerTargetType)targetTypeFromString:(NSString*)targetType;

/**
 Gives the string representation of a target type.
 @param targetType The target type to display.
 @return The string representation of the target type.
 */
+ (NSString *)targetTypeToString:(SFSyncServerTargetType)targetType;

/**
 Gives the current modification times of a record, on the client and on the server.
 @param record The record to query for modification times.
 @param modificationResultBlock The block to execute with the modification date values.
 */
- (void)fetchRecordModificationDates:(NSDictionary *)record
             modificationResultBlock:(void (^)(NSDate *localDate, NSDate *serverDate, NSError *error))modificationResultBlock;

/**
 Syncs up a record to the service.
 @param record The record to sync up.
 @param fieldList The list of fields to consider for updating.
 @param The action to take against the server (create, update, etc.).
 @param completionBlock The block to execute upon successful sync up.
 @param failBlock The block to execute if the sync up fails.
 */
- (void)syncUpRecord:(NSDictionary *)record
           fieldList:(NSArray *)fieldList
              action:(SFSyncServerTargetAction)action
     completionBlock:(void (^)(NSDictionary *))completionBlock
           failBlock:(void (^)(NSError *))failBlock;

@end
