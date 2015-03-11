//
//  SFSyncServerTarget.m
//  SmartSync
//
//  Created by Kevin Hawkins on 3/10/15.
//  Copyright (c) 2015 Salesforce Inc. All rights reserved.
//

#import "SFSyncServerTarget.h"
#import "SFSmartSyncConstants.h"
#import "SFSmartSyncObjectUtils.h"
#import "SFSmartSyncSoqlBuilder.h"
#import "SFSmartSyncNetworkUtils.h"
#import <SalesforceRestAPI/SFRestAPI+Blocks.h>
#import <SalesforceRestAPI/SFRestRequest.h>
#import <SalesforceSDKCore/SFJsonUtils.h>

// target types
static NSString * const kSFSyncServerTargetTypeRestStandard = @"rest";
static NSString * const kSFSyncServerTargetTypeCustom = @"custom";

@implementation SFSyncServerTarget

- (instancetype)init {
    self = [super init];
    if (self) {
        self.targetType = SFSyncServerTargetTypeRestStandard;
    }
    return self;
}

#pragma mark - Serialization and factory methods

+ (instancetype)newFromDict:(NSDictionary*)dict {
    NSString *implClassName;
    switch ([self targetTypeFromString:dict[kSFSyncTargetTypeKey]]) {
        case SFSyncServerTargetTypeRestStandard:
            return [[SFSyncServerTarget alloc] init];
        case SFSyncServerTargetTypeCustom:
            implClassName = dict[kSFSyncTargetiOSImplKey];
            return [NSClassFromString(implClassName) newFromDict:dict];
    }
    
    // Fell through
    return nil;
}

- (NSDictionary *)asDict {
    return @{
             kSFSyncTargetTypeKey: [[self class] targetTypeToString:self.targetType],
             };
}

+ (SFSyncServerTargetType)targetTypeFromString:(NSString *)targetType {
    if ([targetType isEqualToString:kSFSyncServerTargetTypeRestStandard]) {
        return SFSyncServerTargetTypeRestStandard;
    } else {
        return SFSyncServerTargetTypeCustom;
    }
}

+ (NSString *)targetTypeToString:(SFSyncServerTargetType)targetType {
    switch (targetType) {
        case SFSyncServerTargetTypeRestStandard:  return kSFSyncServerTargetTypeRestStandard;
        case SFSyncServerTargetTypeCustom: return kSFSyncServerTargetTypeCustom;
        default: return nil;
    }
}

#pragma mark - Sync up methods

- (void)fetchRecordModificationDates:(NSDictionary *)record
             modificationResultBlock:(void (^)(NSDate *, NSDate *, NSError *))modificationResultBlock {
    
    NSString *objectType = [SFJsonUtils projectIntoJson:record path:kObjectTypeField];
    NSString *objectId = record[kId];
    NSDate *localLastModifiedDate = [SFSmartSyncObjectUtils getDateFromIsoDateString:record[kLastModifiedDate]];
    __block NSDate *serverLastModifiedDate = [NSDate dateWithTimeIntervalSince1970:0.0];
    
    SFSmartSyncSoqlBuilder *soqlBuilder = [SFSmartSyncSoqlBuilder withFields:kLastModifiedDate];
    [soqlBuilder from:objectType];
    [soqlBuilder where:[NSString stringWithFormat:@"Id = '%@'", objectId]];
    NSString *query = [soqlBuilder build];
    
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForQuery:query];
    [SFSmartSyncNetworkUtils sendRequestWithSmartSyncUserAgent:request
                                                     failBlock:^(NSError *error) {
                                                         [self log:SFLogLevelError format:@"REST request failed with error: %@", error];
                                                         if (modificationResultBlock != NULL) {
                                                             modificationResultBlock(nil, nil, error);
                                                         }
                                                     }
                                                 completeBlock:^(NSDictionary *response) {
                                                     if (nil != response) {
                                                         NSDictionary *record = response[@"records"][0];
                                                         if (nil != record) {
                                                             NSString *serverLastModifiedStr = record[kLastModifiedDate];
                                                             if (nil != serverLastModifiedStr) {
                                                                 NSDate *testServerModifiedDate = [SFSmartSyncObjectUtils getDateFromIsoDateString:serverLastModifiedStr];
                                                                 if (testServerModifiedDate != nil) {
                                                                     serverLastModifiedDate = testServerModifiedDate;
                                                                 }
                                                             }
                                                         }
                                                     }
                                                     if (modificationResultBlock != NULL) {
                                                         modificationResultBlock(localLastModifiedDate, serverLastModifiedDate, nil);
                                                     }
                                                 }
     ];
}

- (void)syncUpRecord:(NSDictionary *)record
           fieldList:(NSArray *)fieldList
              action:(SFSyncServerTargetAction)action
     completionBlock:(void (^)(NSDictionary *response))response
           failBlock:(void (^)(NSError *))failBlock {
    
    // Getting type and id
    NSString* objectType = [SFJsonUtils projectIntoJson:record path:kObjectTypeField];
    NSString* objectId = record[kId];
    
    // Fields to save (in the case of create or update)
    NSMutableDictionary* fields = [NSMutableDictionary dictionary];
    if (action == SyncServerTargetActionCreate || action == SyncServerTargetActionUpdate) {
        for (NSString *fieldName in fieldList) {
            if (![fieldName isEqualToString:kId] && ![fieldName isEqualToString:kLastModifiedDate]) {
                if (record[fieldName] != nil)
                    fields[fieldName] = record[fieldName];
            }
        }
    }
    
    SFRestRequest *request;
    switch(action) {
        case SyncServerTargetActionCreate:
            request = [[SFRestAPI sharedInstance] requestForCreateWithObjectType:objectType fields:fields];
            break;
        case SyncServerTargetActionUpdate:
            request = [[SFRestAPI sharedInstance] requestForUpdateWithObjectType:objectType objectId:objectId fields:fields];
            break;
        case SyncServerTargetActionDelete:
            request = [[SFRestAPI sharedInstance] requestForDeleteWithObjectType:objectType objectId:objectId];
            break;
        default:
            // Unsupported action.
            [self log:SFLogLevelInfo format:@"%@ unsupported action with value %d.  No action taken.", NSStringFromSelector(_cmd), action];
            if (response != NULL) {
                response(nil);
            }
            return;
    }
    
    // Send request
    [SFSmartSyncNetworkUtils sendRequestWithSmartSyncUserAgent:request failBlock:failBlock completeBlock:response];
}

@end
