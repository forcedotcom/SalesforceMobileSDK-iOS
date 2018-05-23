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

#import "TestSyncUpTarget.h"

NSString * const kCreatedResultIdPrefix = @"testSyncUpCreatedId_";

static NSString * const kTestSyncUpTargetErrorDomain = @"com.smartsync.test.TestServerTargetErrorDomain";

static NSString * const kTestSyncUpDateCompareKey = @"dateCompareKey";
static NSString * const kTestSyncUpSendRemoteModErrorKey = @"sendRemoteModErrorKey";
static NSString * const kTestSyncUpSendSyncUpErrorKey = @"sendSyncUpErrorKey";

@interface TestSyncUpTarget ()

@property (nonatomic, assign) TestSyncUpTargetModDateCompare dateCompare;
@property (nonatomic, assign) BOOL sendRemoteModError;
@property (nonatomic, assign) BOOL sendSyncUpError;

@end

@implementation TestSyncUpTarget

- (instancetype)initWithRemoteModDateCompare:(TestSyncUpTargetModDateCompare)dateCompare
                          sendRemoteModError:(BOOL)sendRemoteModError
                             sendSyncUpError:(BOOL)sendSyncUpError {
    self = [super init];
    if (self) {
        [self commonInitWithRemoteModDateCompare:dateCompare sendRemoteModError:sendRemoteModError sendSyncUpError:sendSyncUpError];
    }
    return self;
}

- (instancetype)initWithDict:(NSDictionary *)dict {
    self = [super initWithDict:dict];
    if (self) {
        TestSyncUpTargetModDateCompare dateCompare = (dict[kTestSyncUpDateCompareKey] == nil ? TestSyncUpTargetRemoteModDateSameAsLocal : (TestSyncUpTargetModDateCompare)[dict[kTestSyncUpDateCompareKey] unsignedIntegerValue]);
        BOOL sendRemoteModError = (dict[kTestSyncUpSendRemoteModErrorKey] == nil ? NO : [dict[kTestSyncUpSendRemoteModErrorKey] boolValue]);
        BOOL sendSyncUpError = (dict[kTestSyncUpSendSyncUpErrorKey] == nil ? NO : [dict[kTestSyncUpSendSyncUpErrorKey] boolValue]);
        [self commonInitWithRemoteModDateCompare:dateCompare sendRemoteModError:sendRemoteModError sendSyncUpError:sendSyncUpError];
    }
    return self;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self commonInitWithRemoteModDateCompare:TestSyncUpTargetRemoteModDateSameAsLocal sendRemoteModError:NO sendSyncUpError:NO];
    }
    return self;
}

- (void)commonInitWithRemoteModDateCompare:(TestSyncUpTargetModDateCompare)dateCompare
                        sendRemoteModError:(BOOL)sendRemoteModError
                           sendSyncUpError:(BOOL)sendSyncUpError {
    self.dateCompare = dateCompare;
    self.sendRemoteModError = sendRemoteModError;
    self.sendSyncUpError = sendSyncUpError;
}

- (NSMutableDictionary *)asDict {
    NSMutableDictionary *dict = [super asDict];
    dict[kTestSyncUpDateCompareKey] = @(self.dateCompare);
    dict[kTestSyncUpSendRemoteModErrorKey] = @(self.sendRemoteModError);
    dict[kTestSyncUpSendSyncUpErrorKey] = @(self.sendSyncUpError);
    return dict;
}

- (void)isNewerThanServer:(SFSmartSyncSyncManager *)syncManager
                   record:(NSDictionary*)record
              resultBlock:(SFSyncUpRecordNewerThanServerBlock)resultBlock
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (resultBlock != NULL) {
            if (self.sendRemoteModError) {
                resultBlock(YES);
            } else {
                switch (self.dateCompare) {
                    case TestSyncUpTargetRemoteModDateGreaterThanLocal:
                        resultBlock(NO);
                        break;
                    case TestSyncUpTargetRemoteModDateLessThanLocal:
                        resultBlock(YES);
                        break;
                    case TestSyncUpTargetRemoteModDateSameAsLocal:
                        resultBlock(YES);
                        break;
                }
            }
        }
    });
}

- (void)createOnServer:(NSString*)objectType
                fields:(NSDictionary*)fields
       completionBlock:(SFSyncUpTargetCompleteBlock)completionBlock
             failBlock:(SFSyncUpTargetErrorBlock)failBlock
{
    [self fakeRemoteCall:YES completionBlock:completionBlock failBlock:failBlock];
}

- (void)updateOnServer:(NSString*)objectType
              objectId:(NSString*)objectId
                fields:(NSDictionary*)fields
       completionBlock:(SFSyncUpTargetCompleteBlock)completionBlock
             failBlock:(SFSyncUpTargetErrorBlock)failBlock
{
    [self fakeRemoteCall:NO completionBlock:completionBlock failBlock:failBlock];
}

- (void)deleteOnServer:(NSString*)objectType
              objectId:(NSString*)objectId
       completionBlock:(SFSyncUpTargetCompleteBlock)completionBlock
             failBlock:(SFSyncUpTargetErrorBlock)failBlock
{
    [self fakeRemoteCall:NO completionBlock:completionBlock failBlock:failBlock];
}


- (void)fakeRemoteCall:(BOOL)isCreate
       completionBlock:(SFSyncUpTargetCompleteBlock)completionBlock
             failBlock:(SFSyncUpTargetErrorBlock)failBlock {

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self.sendSyncUpError) {
            if (failBlock != NULL) {
                NSError *syncUpError = [NSError errorWithDomain:kTestSyncUpTargetErrorDomain
                                                           code:kCFURLErrorCannotConnectToHost // only network error cause the sync to fail
                                                       userInfo:@{ NSLocalizedDescriptionKey: @"RemoteSyncUpError" }];
                failBlock(syncUpError);
            }
        } else {
            if (completionBlock != NULL) {
                NSDictionary *result = nil;
                if (isCreate) {
                    u_int32_t randomId = arc4random() % 10000000;
                    NSString *resultId = [NSString stringWithFormat:@"%@%u", kCreatedResultIdPrefix, randomId];
                    result = @{ @"id": resultId, @"errors": @[ ], @"success": @YES };
                }
                completionBlock(result);
            }
        }
    });
}

@end
