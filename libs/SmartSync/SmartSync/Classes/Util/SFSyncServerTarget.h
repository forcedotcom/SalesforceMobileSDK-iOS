//
//  SFSyncServerTarget.h
//  SmartSync
//
//  Created by Kevin Hawkins on 3/10/15.
//  Copyright (c) 2015 Salesforce Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, SFSyncServerTargetType) {
    SFSyncServerTargetTypeRestStandard,
    SFSyncServerTargetTypeCustom,
};

// action type
typedef NS_ENUM(NSUInteger, SFSyncServerTargetAction) {
    SyncServerTargetActionNone,
    SyncServerTargetActionCreate,
    SyncServerTargetActionUpdate,
    SyncServerTargetActionDelete
};

@interface SFSyncServerTarget : NSObject

@property (nonatomic, assign) SFSyncServerTargetType targetType;

+ (instancetype)newFromDict:(NSDictionary *)dict;
- (NSDictionary *)asDict;
+ (SFSyncServerTargetType)targetTypeFromString:(NSString*)targetType;
+ (NSString *)targetTypeToString:(SFSyncServerTargetType)targetType;

- (void)fetchRecordModificationDates:(NSDictionary *)record
             modificationResultBlock:(void (^)(NSDate *localDate, NSDate *serverDate, NSError *error))modificationResultBlock;

- (void)syncUpRecord:(NSDictionary *)record
           fieldList:(NSArray *)fieldList
              action:(SFSyncServerTargetAction)action
     completionBlock:(void (^)(NSDictionary *))completionBlock
           failBlock:(void (^)(NSError *))failBlock;

@end
