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

#import "TestSyncServerTarget.h"

NSString * const kCreatedResultIdPrefix = @"testSyncServerCreatedId_";

static NSString * const kTestSyncServerTargetErrorDomain = @"com.smartsync.test.TestServerTargetErrorDomain";

static NSString * const kTestSyncServerDateCompareKey = @"dateCompareKey";
static NSString * const kTestSyncServerSendRemoteModErrorKey = @"sendRemoteModErrorKey";
static NSString * const kTestSyncServerSendSyncUpErrorKey = @"sendSyncUpErrorKey";

@interface TestSyncServerTarget ()

@property (nonatomic, assign) TestSyncServerTargetModDateCompare dateCompare;
@property (nonatomic, assign) BOOL sendRemoteModError;
@property (nonatomic, assign) BOOL sendSyncUpError;

@end

@implementation TestSyncServerTarget

- (instancetype)initWithRemoteModDateCompare:(TestSyncServerTargetModDateCompare)dateCompare
                          sendRemoteModError:(BOOL)sendRemoteModError
                             sendSyncUpError:(BOOL)sendSyncUpError {
    self = [super init];
    if (self) {
        self.targetType = SFSyncServerTargetTypeCustom;
        self.dateCompare = dateCompare;
        self.sendRemoteModError = sendRemoteModError;
        self.sendSyncUpError = sendSyncUpError;
    }
    return self;
}

- (instancetype)init {
    return [self initWithRemoteModDateCompare:TestSyncServerTargetRemoteModDateSameAsLocal
                           sendRemoteModError:NO
                              sendSyncUpError:NO];
}

+ (TestSyncServerTarget *)newFromDict:(NSDictionary *)dict {
    TestSyncServerTargetModDateCompare compare = (dict[kTestSyncServerDateCompareKey] == nil ? TestSyncServerTargetRemoteModDateSameAsLocal : (TestSyncServerTargetModDateCompare)[dict[kTestSyncServerDateCompareKey] unsignedIntegerValue]);
    BOOL sendRemoteModError = (dict[kTestSyncServerSendRemoteModErrorKey] == nil ? NO : [dict[kTestSyncServerSendRemoteModErrorKey] boolValue]);
    BOOL sendSyncUpError = (dict[kTestSyncServerSendSyncUpErrorKey] == nil ? NO : [dict[kTestSyncServerSendSyncUpErrorKey] boolValue]);
    return [[TestSyncServerTarget alloc] initWithRemoteModDateCompare:compare sendRemoteModError:sendRemoteModError sendSyncUpError:sendSyncUpError];
}

- (NSDictionary *)asDict {
    return @{
             kSFSyncTargetTypeKey: [[self class] targetTypeToString:self.targetType],
             kSFSyncTargetiOSImplKey: NSStringFromClass([self class]),
             kTestSyncServerDateCompareKey: @(self.dateCompare),
             kTestSyncServerSendRemoteModErrorKey: @(self.sendRemoteModError),
             kTestSyncServerSendSyncUpErrorKey: @(self.sendSyncUpError)
             };
}

- (void)fetchRecordModificationDates:(NSDictionary *)record
             modificationResultBlock:(SFSyncServerRecordModificationResultBlock)modificationResultBlock {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (modificationResultBlock != NULL) {
            if (self.sendRemoteModError) {
                NSError *remoteModError = [NSError errorWithDomain:kTestSyncServerTargetErrorDomain
                                                              code:555
                                                          userInfo:@{ NSLocalizedDescriptionKey: @"RemoteModError" }];
                modificationResultBlock(nil, nil, remoteModError);
            } else {
                NSDate *localLastModifiedDate = [SFSmartSyncObjectUtils getDateFromIsoDateString:record[kLastModifiedDate]];
                NSDate *remoteLastModifiedDate;
                switch (self.dateCompare) {
                    case TestSyncServerTargetRemoteModDateGreaterThanLocal:
                        remoteLastModifiedDate = [NSDate dateWithTimeInterval:60.0 * 60.0 sinceDate:localLastModifiedDate];
                        break;
                    case TestSyncServerTargetRemoteModDateLessThanLocal:
                        remoteLastModifiedDate = [NSDate dateWithTimeInterval:-60.0 * 60.0 sinceDate:localLastModifiedDate];
                        break;
                    case TestSyncServerTargetRemoteModDateSameAsLocal:
                        remoteLastModifiedDate = [localLastModifiedDate copy];
                        break;
                }
                modificationResultBlock(localLastModifiedDate, remoteLastModifiedDate, nil);
            }
        }
    });
}

- (void)syncUpRecord:(NSDictionary *)record
           fieldList:(NSArray *)fieldList
              action:(SFSyncServerTargetAction)action
     completionBlock:(SFSyncServerTargetCompleteBlock)completionBlock
           failBlock:(SFSyncServerTargetErrorBlock)failBlock {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self.sendSyncUpError) {
            if (failBlock != NULL) {
                NSError *syncUpError = [NSError errorWithDomain:kTestSyncServerTargetErrorDomain
                                                           code:556
                                                       userInfo:@{ NSLocalizedDescriptionKey: @"RemoteSyncUpError" }];
                failBlock(syncUpError);
            }
        } else {
            if (completionBlock != NULL) {
                NSDictionary *result = nil;
                if (action == SFSyncServerTargetActionCreate) {
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
