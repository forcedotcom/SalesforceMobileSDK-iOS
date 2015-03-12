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
    NSString *targetTypeString = (dict[kSFSyncTargetTypeKey] == nil ? kSFSyncServerTargetTypeRestStandard : dict[kSFSyncTargetTypeKey]);
    switch ([self targetTypeFromString:targetTypeString]) {
        case SFSyncServerTargetTypeCustom:
            implClassName = dict[kSFSyncTargetiOSImplKey];
            return [NSClassFromString(implClassName) newFromDict:dict];
        case SFSyncServerTargetTypeRestStandard:
        default:  // SFSyncServerTarget is the default, if not specified.
            return [[SFSyncServerTarget alloc] init];
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
     completionBlock:(void (^)(NSDictionary *))completionBlock
           failBlock:(void (^)(NSError *))failBlock {
    
    // Getting type and id
    NSString* objectType = [SFJsonUtils projectIntoJson:record path:kObjectTypeField];
    NSString* objectId = record[kId];
    
    // Fields to save (in the case of create or update)
    NSMutableDictionary* fields = [NSMutableDictionary dictionary];
    if (action == SFSyncServerTargetActionCreate || action == SFSyncServerTargetActionUpdate) {
        for (NSString *fieldName in fieldList) {
            if (![fieldName isEqualToString:kId] && ![fieldName isEqualToString:kLastModifiedDate]) {
                if (record[fieldName] != nil)
                    fields[fieldName] = record[fieldName];
            }
        }
    }
    
    SFRestRequest *request;
    switch(action) {
        case SFSyncServerTargetActionCreate:
            request = [[SFRestAPI sharedInstance] requestForCreateWithObjectType:objectType fields:fields];
            break;
        case SFSyncServerTargetActionUpdate:
            request = [[SFRestAPI sharedInstance] requestForUpdateWithObjectType:objectType objectId:objectId fields:fields];
            break;
        case SFSyncServerTargetActionDelete:
            request = [[SFRestAPI sharedInstance] requestForDeleteWithObjectType:objectType objectId:objectId];
            break;
        default:
            // Unsupported action.
            [self log:SFLogLevelInfo format:@"%@ unsupported action with value %d.  No action taken.", NSStringFromSelector(_cmd), action];
            if (completionBlock != NULL) {
                completionBlock(nil);
            }
            return;
    }
    
    // Send request
    [SFSmartSyncNetworkUtils sendRequestWithSmartSyncUserAgent:request failBlock:failBlock completeBlock:completionBlock];
}

@end
