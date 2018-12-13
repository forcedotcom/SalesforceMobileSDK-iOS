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

#import "SFSyncUpTarget.h"
#import "SFSmartSyncConstants.h"
#import "SFSmartSyncNetworkUtils.h"
#import "SFSmartSyncSyncManager.h"
#import "SFSmartSyncObjectUtils.h"
#import "SFSyncTarget+Internal.h"
#import <SalesforceSDKCore/SFJsonUtils.h>
#import <SmartStore/SFSmartStore.h>

// target types
static NSString *const kSFSyncUpTargetTypeRestStandard = @"rest";
static NSString *const kSFSyncUpTargetTypeCustom = @"custom";
static NSString *const kSFSyncUpTargetCreateFieldlist = @"createFieldlist";
static NSString *const kSFSyncUpTargetUpdateFieldlist = @"updateFieldlist";

@implementation SFRecordModDate
- (instancetype)initWithTimestamp:(NSString*)timestamp isDeleted:(BOOL)isDeleted {
    self = [super init];
    if (self) {
        self.timestamp = [SFSmartSyncObjectUtils getDateFromIsoDateString:timestamp];
        self.isDeleted = isDeleted;
    }
    return self;
}

@end

typedef void (^SFSyncUpRecordModDateBlock)(SFRecordModDate *remoteModDate);

@interface  SFSyncUpTarget ()
@property (nonatomic, strong) NSArray*  createFieldlist;
@property (nonatomic, strong) NSArray*  updateFieldlist;
@property (nonatomic, strong) NSString* lastError;
@end

@implementation SFSyncUpTarget

#pragma mark - Initialization and serialization methods

- (instancetype)initWithDict:(NSDictionary *)dict {
    return [self initWithCreateFieldlist:dict[kSFSyncUpTargetCreateFieldlist] updateFieldlist:dict[kSFSyncUpTargetUpdateFieldlist]];
}

- (instancetype)init {
    return [self initWithCreateFieldlist:nil updateFieldlist:nil];
}

- (instancetype)initWithCreateFieldlist:(NSArray *)createFieldlist
                        updateFieldlist:(NSArray *)updateFieldlist {
    self = [super init];
    if (self) {
        self.targetType = SFSyncUpTargetTypeRestStandard;
        self.createFieldlist = createFieldlist;
        self.updateFieldlist = updateFieldlist;
    }
    return self;
}


+ (instancetype)newFromDict:(NSDictionary*)dict {
    // We should have an implementation class or a target type
    NSString* implClassName = dict[kSFSyncTargetiOSImplKey];
    if (implClassName.length > 0) {
        Class customSyncUpClass = NSClassFromString(implClassName);
        if (![customSyncUpClass isSubclassOfClass:[SFSyncUpTarget class]]) {
            [SFSDKSmartSyncLogger e:[self class] format:@"%@ Class '%@' is not a subclass of %@.", NSStringFromSelector(_cmd), implClassName, NSStringFromClass([SFSyncUpTarget class])];
            return nil;
        } else {
            return [[customSyncUpClass alloc] initWithDict:dict];
        }        
    }
    // No implementation class - using target type
    else {
        // No target type - assume kSFSyncUpTargetTypeRestStandard (hybrid apps don't specify it a sync up target type by default)
        NSString *targetTypeString = (dict[kSFSyncTargetTypeKey] == nil ? kSFSyncUpTargetTypeRestStandard : dict[kSFSyncTargetTypeKey]);
        switch ([self targetTypeFromString:targetTypeString]) {
            case SFSyncUpTargetTypeRestStandard:
                return [[SFSyncUpTarget alloc] initWithDict:dict];
            case SFSyncUpTargetTypeCustom:
                [SFSDKSmartSyncLogger e:[self class] format:@"%@ Custom class name not specified.", NSStringFromSelector(_cmd)];
                return nil;
        }
    }
}

- (NSMutableDictionary *)asDict {
    NSMutableDictionary *dict = [super asDict];
    dict[kSFSyncTargetTypeKey] = [[self class] targetTypeToString:self.targetType];
    if (self.createFieldlist) dict[kSFSyncUpTargetCreateFieldlist] = self.createFieldlist;
    if (self.updateFieldlist) dict[kSFSyncUpTargetUpdateFieldlist] = self.updateFieldlist;
    return dict;
}

# pragma mark - Public sync up methods

- (void)isNewerThanServer:(SFSmartSyncSyncManager *)syncManager
                   record:(NSDictionary*)record
              resultBlock:(SFSyncUpRecordNewerThanServerBlock)resultBlock
{
    if ([self isLocallyCreated:record]) {
        resultBlock(YES);
    }
    else {
        __block SFRecordModDate *localModDate = [[SFRecordModDate alloc]
                initWithTimestamp:record[self.modificationDateFieldName]
                        isDeleted:[self isLocallyDeleted:record]];

        [self fetchLastModifiedDate:record completeBlock:^(SFRecordModDate *remoteModDate) {
            resultBlock([self isNewerThanServer:localModDate remoteModDate:remoteModDate]);
        }];
    }
}


- (void)createOnServer:(SFSmartSyncSyncManager *)syncManager
                record:(NSDictionary*)record
             fieldlist:(NSArray*)fieldlist
       completionBlock:(SFSyncUpTargetCompleteBlock)completionBlock
             failBlock:(SFSyncUpTargetErrorBlock)failBlock
{
    fieldlist = self.createFieldlist ? self.createFieldlist : fieldlist;
    NSString* objectType = [SFJsonUtils projectIntoJson:record path:kObjectTypeField];
    NSDictionary * fields = [self buildFieldsMap:record fieldlist:fieldlist];
    [self createOnServer:objectType fields:fields completionBlock:completionBlock failBlock:failBlock];
}

- (void)updateOnServer:(SFSmartSyncSyncManager *)syncManager
                record:(NSDictionary*)record
             fieldlist:(NSArray*)fieldlist
       completionBlock:(SFSyncUpTargetCompleteBlock)completionBlock
             failBlock:(SFSyncUpTargetErrorBlock)failBlock
{
    fieldlist = self.updateFieldlist ? self.updateFieldlist : fieldlist;
    NSString* objectType = [SFJsonUtils projectIntoJson:record path:kObjectTypeField];
    NSString* objectId = record[self.idFieldName];
    NSDictionary * fields = [self buildFieldsMap:record fieldlist:fieldlist];
    [self updateOnServer:objectType objectId:objectId fields:fields completionBlock:completionBlock failBlock:failBlock];

}

- (void)deleteOnServer:(SFSmartSyncSyncManager *)syncManager
                record:(NSDictionary*)record
       completionBlock:(SFSyncUpTargetCompleteBlock)completionBlock
             failBlock:(SFSyncUpTargetErrorBlock)failBlock
{
    NSString* objectType = [SFJsonUtils projectIntoJson:record path:kObjectTypeField];
    NSString* objectId = record[self.idFieldName];
    [self deleteOnServer:objectType objectId:objectId completionBlock:completionBlock failBlock:failBlock];
}


- (NSArray*)getIdsOfRecordsToSyncUp:(SFSmartSyncSyncManager*)syncManager
                           soupName:(NSString*)soupName
{
    return [[self getDirtyRecordIds:syncManager soupName:soupName idField:SOUP_ENTRY_ID] array];
}

#pragma mark - String to/from enum for sync up target type

+ (SFSyncUpTargetType)targetTypeFromString:(NSString *)targetType {
    if ([targetType isEqualToString:kSFSyncUpTargetTypeRestStandard]) {
        return SFSyncUpTargetTypeRestStandard;
    }
        // Must be custom
    else {
        return SFSyncUpTargetTypeCustom;
    }
}

+ (NSString *)targetTypeToString:(SFSyncUpTargetType)targetType {
    switch (targetType) {
        case SFSyncUpTargetTypeRestStandard:  return kSFSyncUpTargetTypeRestStandard;
        case SFSyncUpTargetTypeCustom: return kSFSyncUpTargetTypeCustom;
    }
}

#pragma mark - Helper methods

- (NSDictionary*) buildFieldsMap:(NSDictionary *)record fieldlist:(NSArray *)fieldlist {
    return [self buildFieldsMap:record fieldlist:fieldlist idFieldName:self.idFieldName modificationDateFieldName:self.modificationDateFieldName];
}

- (NSMutableDictionary *)buildFieldsMap:(NSDictionary *)record
                              fieldlist:(NSArray *)fieldlist
                            idFieldName:(NSString *)idFieldName
              modificationDateFieldName:(NSString *)modificationDateFieldName {
    NSMutableDictionary *fields = [NSMutableDictionary dictionary];
    for (NSString *fieldName in fieldlist) {
        if (![fieldName isEqualToString:idFieldName] && ![fieldName isEqualToString:modificationDateFieldName]) {
            NSObject *fieldValue = [SFJsonUtils projectIntoJson:record path:fieldName];
            if (fieldValue != nil)
                fields[fieldName] = fieldValue;
        }
    }
    return fields;
}

- (void)createOnServer:(NSString*)objectType
                fields:(NSDictionary*)fields
       completionBlock:(SFSyncUpTargetCompleteBlock)completionBlock
             failBlock:(SFSyncUpTargetErrorBlock)failBlock
{
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForCreateWithObjectType:objectType fields:fields];
    [SFSmartSyncNetworkUtils sendRequestWithSmartSyncUserAgent:request failBlock:^(NSError *e, NSURLResponse *rawResponse) {
        self.lastError = e.description;
        failBlock(e);
    } completeBlock:^(NSDictionary* d, NSURLResponse *rawResponse) {
        completionBlock(d);
    }];
}

- (void)updateOnServer:(NSString*)objectType
              objectId:(NSString*)objectId
                fields:(NSDictionary*)fields
       completionBlock:(SFSyncUpTargetCompleteBlock)completionBlock
             failBlock:(SFSyncUpTargetErrorBlock)failBlock
{
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForUpdateWithObjectType:objectType objectId:objectId fields:fields];
    [SFSmartSyncNetworkUtils sendRequestWithSmartSyncUserAgent:request failBlock:^(NSError *e, NSURLResponse *rawResponse) {
        self.lastError = e.description;
        failBlock(e);
    } completeBlock:^(NSDictionary* d, NSURLResponse *rawResponse) {
        completionBlock(d);
    }];
}

- (void)deleteOnServer:(NSString*)objectType
              objectId:(NSString*)objectId
       completionBlock:(SFSyncUpTargetCompleteBlock)completionBlock
             failBlock:(SFSyncUpTargetErrorBlock)failBlock
{
    SFRestRequest* request = [[SFRestAPI sharedInstance] requestForDeleteWithObjectType:objectType objectId:objectId];
    [SFSmartSyncNetworkUtils sendRequestWithSmartSyncUserAgent:request failBlock:^(NSError *e, NSURLResponse *rawResponse) {
        self.lastError = e.description;
        failBlock(e);
    } completeBlock:^(NSDictionary* d, NSURLResponse *rawResponse) {
        completionBlock(d);
    }];
}

- (void)fetchLastModifiedDate:(NSDictionary *)record
                completeBlock:(SFSyncUpRecordModDateBlock)completeBlock {

    NSString *objectType = [SFJsonUtils projectIntoJson:record path:kObjectTypeField];
    NSString *objectId = record[self.idFieldName];
    SFRestRequest *request = [[SFRestAPI sharedInstance]
            requestForRetrieveWithObjectType:objectType
                                    objectId:objectId
                                   fieldList:self.modificationDateFieldName];

    [SFSmartSyncNetworkUtils
            sendRequestWithSmartSyncUserAgent:request
                                    failBlock:^(NSError *e, NSURLResponse *rawResponse) {
                                        completeBlock([[SFRecordModDate alloc] initWithTimestamp:nil isDeleted:e.code == 404]);
                                    }
                                completeBlock:^(id response, NSURLResponse *rawResponse) {
                                    completeBlock([[SFRecordModDate alloc] initWithTimestamp:response[self.modificationDateFieldName] isDeleted:FALSE]);
                                }
    ];
}
/**
 Return true if local mod date is greater than remote mod date
 NB: also return true if both were deleted or if local mod date is missing
*/
- (BOOL)isNewerThanServer:(SFRecordModDate*)localModDate
        remoteModDate:(SFRecordModDate*)remoteModDate
{
if ((localModDate.timestamp != nil && remoteModDate.timestamp != nil
        && [localModDate.timestamp compare:remoteModDate.timestamp] >= 0) // we got a local and remote mod date and the local one is greater
        || (localModDate.isDeleted && remoteModDate.isDeleted)            // or we have a local delete and a remote delete
        || localModDate.timestamp == nil)                                 // or we don't have a local mod date
    {
        return true;
    }
    return false;
}

- (void) saveRecordToLocalStoreWithLastError:(SFSmartSyncSyncManager*)syncManager
                                    soupName:(NSString*) soupName
                                      record:(NSDictionary*) record {
    [self saveRecordToLocalStoreWithLastError:syncManager
                                     soupName:soupName
                                       record:record
                                    lastError:self.lastError];
    self.lastError = nil;
}

- (void) saveRecordToLocalStoreWithLastError:(SFSmartSyncSyncManager*)syncManager
                                    soupName:(NSString*) soupName
                                      record:(NSDictionary*) record
                                   lastError:(NSString*) lastError {
    if (lastError) {
        [self saveInLocalStore:syncManager
                      soupName:soupName
                       records:@[record]
                   idFieldName:self.idFieldName
                        syncId:nil
                     lastError:lastError
                    cleanFirst:NO];
    }
}

@end
