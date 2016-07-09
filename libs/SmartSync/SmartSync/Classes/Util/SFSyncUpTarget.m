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

#import "SFSyncUpTarget.h"
#import "SFSmartSyncConstants.h"
#import "SFSmartSyncObjectUtils.h"
#import "SFSmartSyncSoqlBuilder.h"
#import "SFSmartSyncNetworkUtils.h"
#import "SFSmartSyncSyncManager.h"
#import <SalesforceRestAPI/SFRestAPI+Blocks.h>
#import <SalesforceRestAPI/SFRestRequest.h>
#import <SalesforceSDKCore/SFJsonUtils.h>
#import <SmartStore/SFSmartStore.h>

// target types
static NSString * const kSFSyncUpTargetTypeRestStandard = @"rest";
static NSString * const kSFSyncUpTargetTypeCustom = @"custom";

@implementation SFSyncUpTarget

- (instancetype)initWithDict:(NSDictionary *)dict {
    self = [super initWithDict:dict];
    if (self) {
        self.targetType = SFSyncUpTargetTypeRestStandard;
    }
    return self;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.targetType = SFSyncUpTargetTypeRestStandard;
    }
    return self;
}

#pragma mark - Serialization and factory methods

+ (instancetype)newFromDict:(NSDictionary*)dict {
    NSString *implClassName;
    NSString *targetTypeString = (dict[kSFSyncTargetTypeKey] == nil ? kSFSyncUpTargetTypeRestStandard : dict[kSFSyncTargetTypeKey]);
    switch ([self targetTypeFromString:targetTypeString]) {
        case SFSyncUpTargetTypeCustom:
            implClassName = dict[kSFSyncTargetiOSImplKey];
            if (implClassName.length == 0) {
                [SFLogger log:self level:SFLogLevelError format:@"%@ Custom class name not specified.", NSStringFromSelector(_cmd)];
                return nil;
            }
            Class customSyncUpClass = NSClassFromString(implClassName);
            if (![customSyncUpClass isSubclassOfClass:[SFSyncUpTarget class]]) {
                [SFLogger log:self level:SFLogLevelError format:@"%@ Class '%@' is not a subclass of %@.", NSStringFromSelector(_cmd), implClassName, NSStringFromClass([SFSyncUpTarget class])];
                return nil;
            } else {
                return [[customSyncUpClass alloc] initWithDict:dict];
            }
        case SFSyncUpTargetTypeRestStandard:
        default:  // SFSyncUpTarget is the default, if not specified.
            return [[SFSyncUpTarget alloc] initWithDict:dict];
    }
    
    // Fell through
    return nil;
}

- (NSMutableDictionary *)asDict {
    NSMutableDictionary *dict = [super asDict];
    dict[kSFSyncTargetTypeKey] = [[self class] targetTypeToString:self.targetType];
    return dict;
}

+ (SFSyncUpTargetType)targetTypeFromString:(NSString *)targetType {
    if ([targetType isEqualToString:kSFSyncUpTargetTypeRestStandard]) {
        return SFSyncUpTargetTypeRestStandard;
    } else {
        return SFSyncUpTargetTypeCustom;
    }
}

+ (NSString *)targetTypeToString:(SFSyncUpTargetType)targetType {
    switch (targetType) {
        case SFSyncUpTargetTypeRestStandard:  return kSFSyncUpTargetTypeRestStandard;
        case SFSyncUpTargetTypeCustom: return kSFSyncUpTargetTypeCustom;
        default: return nil;
    }
}

#pragma mark - Sync up methods

- (void)fetchRecordModificationDates:(NSDictionary *)record
             modificationResultBlock:(SFSyncUpRecordModificationResultBlock)modificationResultBlock {
    
    NSString *objectType = [SFJsonUtils projectIntoJson:record path:kObjectTypeField];
    NSString *objectId = record[self.idFieldName];
    NSDate *localLastModifiedDate = [SFSmartSyncObjectUtils getDateFromIsoDateString:record[self.modificationDateFieldName]];
    __block NSDate *serverLastModifiedDate = nil;
    
    SFSmartSyncSoqlBuilder *soqlBuilder = [SFSmartSyncSoqlBuilder withFields:self.modificationDateFieldName];
    [soqlBuilder from:objectType];
    [soqlBuilder whereClause:[NSString stringWithFormat:@"%@ = '%@'", self.idFieldName, objectId]];
    NSString *query = [soqlBuilder build];
    
    SFRestFailBlock failBlock = ^(NSError *error) {
        [self log:SFLogLevelError format:@"REST request failed with error: %@", error];
        if (modificationResultBlock != NULL) {
            modificationResultBlock(localLastModifiedDate, nil, error);
        }
    };
    
    id completeBlock = ^(NSDictionary *response) {
        if (nil != response && [response[@"records"] count] > 0) {
            NSDictionary *record = response[@"records"][0];
            if (nil != record) {
                NSString *serverLastModifiedStr = record[self.modificationDateFieldName];
                if (nil != serverLastModifiedStr) {
                    serverLastModifiedDate = [SFSmartSyncObjectUtils getDateFromIsoDateString:serverLastModifiedStr];
                }
            }
        }
        if (modificationResultBlock != NULL) {
            modificationResultBlock(localLastModifiedDate, serverLastModifiedDate, nil);
        }
    };
    
    SFRestRequest *request = [[SFRestAPI sharedInstance] requestForQuery:query];
    [SFSmartSyncNetworkUtils sendRequestWithSmartSyncUserAgent:request
                                                     failBlock:failBlock
                                                 completeBlock:completeBlock
     ];
}

- (void)createOnServer:(NSString*)objectType
                fields:(NSDictionary*)fields
       completionBlock:(SFSyncUpTargetCompleteBlock)completionBlock
             failBlock:(SFSyncUpTargetErrorBlock)failBlock
{
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForCreateWithObjectType:objectType fields:fields];
    [SFSmartSyncNetworkUtils sendRequestWithSmartSyncUserAgent:request failBlock:failBlock completeBlock:completionBlock];
}

- (void)updateOnServer:(NSString*)objectType
              objectId:(NSString*)objectId
                fields:(NSDictionary*)fields
       completionBlock:(SFSyncUpTargetCompleteBlock)completionBlock
             failBlock:(SFSyncUpTargetErrorBlock)failBlock
{
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForUpdateWithObjectType:objectType objectId:objectId fields:fields];
    [SFSmartSyncNetworkUtils sendRequestWithSmartSyncUserAgent:request failBlock:failBlock completeBlock:completionBlock];
}

- (void)deleteOnServer:(NSString*)objectType
              objectId:(NSString*)objectId
       completionBlock:(SFSyncUpTargetCompleteBlock)completionBlock
             failBlock:(SFSyncUpTargetErrorBlock)failBlock
{
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForDeleteWithObjectType:objectType objectId:objectId];
    [SFSmartSyncNetworkUtils sendRequestWithSmartSyncUserAgent:request failBlock:failBlock completeBlock:completionBlock];
}


- (NSArray*)getIdsOfRecordsToSyncUp:(SFSmartSyncSyncManager*)syncManager
                           soupName:(NSString*)soupName
{
    return [[syncManager getDirtyRecordIds:soupName idField:SOUP_ENTRY_ID] array];
}


@end
