/*
 Copyright (c) 2012, salesforce.com, inc. All rights reserved.
 
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

#import "SFIdentityCoordinator.h"
#import "SFOAuthCoordinator.h"
#import "SFOAuthInfo.h"

extern NSString* const kTestRequestStatusWaiting;
extern NSString* const kTestRequestStatusDidLoad;
extern NSString* const kTestRequestStatusDidFail;
extern NSString* const kTestRequestStatusDidCancel;
extern NSString* const kTestRequestStatusDidTimeout;

typedef NS_ENUM(NSUInteger, SFAccountManagerServiceType) {
    SFAccountManagerServiceTypeNone = 0,
    SFAccountManagerServiceTypeOAuth,
    SFAccountManagerServiceTypeIdentity
};

@interface SFSDKTestRequestListener : NSObject <SFIdentityCoordinatorDelegate, SFOAuthCoordinatorDelegate> {
    id _dataResponse;
    NSError *_lastError;
    NSString *_returnStatus;
    NSTimeInterval _maxWaitTime;
}

@property (nonatomic, retain) id dataResponse;
@property (nonatomic, retain) NSError *lastError;
@property (nonatomic, retain) NSString *returnStatus;

/// Max time to wait for request completion
@property (nonatomic, assign) NSTimeInterval maxWaitTime;

- (id)initWithServiceType:(SFAccountManagerServiceType)serviceType;

/**
 * Wait for the request to complete (success or fail)
 * Waits for up to maxWaitTime.
 * @return returnStatus:  kTestRequestStatusDidTimeout if maxWaitTime was exceeded
 */
- (NSString *)waitForCompletion;

- (NSString *)serviceTypeDescription;

@end

