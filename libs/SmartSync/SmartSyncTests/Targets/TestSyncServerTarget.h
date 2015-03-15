//
//  TestSyncServerTarget.h
//  SmartSync
//
//  Created by Kevin Hawkins on 3/13/15.
//  Copyright (c) 2015 Salesforce Inc. All rights reserved.
//

#import <SmartSync/SmartSync.h>

typedef NS_ENUM(NSUInteger, TestSyncServerTargetModDateCompare) {
    TestSyncServerTargetRemoteModDateSameAsLocal,
    TestSyncServerTargetRemoteModDateGreaterThanLocal,
    TestSyncServerTargetRemoteModDateLessThanLocal,
};

extern NSString * const kCreatedResultIdPrefix;

@interface TestSyncServerTarget : SFSyncServerTarget

- (instancetype)initWithRemoteModDateCompare:(TestSyncServerTargetModDateCompare)dateCompare
                          sendRemoteModError:(BOOL)sendRemoteModError
                             sendSyncUpError:(BOOL)sendSyncUpError;

@end
