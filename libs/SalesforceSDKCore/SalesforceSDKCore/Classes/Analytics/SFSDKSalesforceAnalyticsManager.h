/*
 SalesforceAnalyticsManager.h
 SalesforceSDKCore
 
 Created by Bharath Hariharan on 6/16/16.
 
 Copyright (c) 2016-present, salesforce.com, inc. All rights reserved.
 
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

#import "SFUserAccount.h"
#import "SFSDKAnalyticsPublisher.h"
#import <SalesforceAnalytics/SFSDKAnalyticsManager.h>
#import <SalesforceAnalytics/SFSDKTransform.h>

@interface SFSDKSalesforceAnalyticsManager : NSObject

@property (nonatomic, readonly, strong, nonnull) SFSDKEventStoreManager *eventStoreManager;
@property (nonatomic, readonly, strong, nonnull) SFSDKAnalyticsManager *analyticsManager;
@property (nonatomic, readonly, strong, nullable) SFUserAccount *userAccount;

/**
 * Disables or enables logging of events.
 *
 * @discussion If logging is disabled, no events will be stored. However, publishing
 * of events is still possible.
 */
@property (nonatomic, readwrite, assign, getter=isLoggingEnabled) BOOL loggingEnabled;

/**
 * Returns an instance of this class associated with the specified user account.
 *
 * @param userAccount User account.
 * @return Instance of this class.
 */
+ (nullable instancetype) sharedInstanceWithUser:(nonnull SFUserAccount *) userAccount;

/**
 * Resets and removes the instance associated with the specified user account.
 *
 * @param userAccount User account.
 */
+ (void) removeSharedInstanceWithUser:(nonnull SFUserAccount *) userAccount;

/**
 * Returns an instance of this class associated with an unauthenticated context (no authenticated user account).
 *
 * @return Instance of this class.
 */
+ (nonnull instancetype) sharedUnauthenticatedInstance;

/**
 * Builds device attributes associated with this device.
 *
 * @return Device attributes.
 */
+ (nonnull SFSDKDeviceAppAttributes *) getDeviceAppAttributes;

/**
 * Publishes all stored events to all registered network endpoints after
 * applying the required event format transforms. Stored events will be
 * deleted if publishing was successful for all registered endpoints.
 * This method should NOT be called from the main thread.
 */
- (void) publishAllEvents;

/**
 * Publishes a list of events to all registered network endpoints after
 * applying the required event format transforms. Stored events will be
 * deleted if publishing was successful for all registered endpoints.
 * This method should NOT be called from the main thread.
 *
 * @param events List of events.
 */
- (void) publishEvents:(nonnull NSArray<SFSDKInstrumentationEvent *> *) events;

/**
 * Publishes an event to all registered network endpoints after
 * applying the required event format transforms. Stored event will be
 * deleted if publishing was successful for all registered endpoints.
 * This method should NOT be called from the main thread.
 *
 * @param event Event.
 */
- (void) publishEvent:(nonnull SFSDKInstrumentationEvent *) event;

/**
 * Adds a remote publisher to publish events to.
 *
 * @param transformer Transformer class.
 * @param publisher Publisher class.
 */
- (void) addRemotePublisher:(nonnull id<SFSDKTransform>) transformer publisher:(nonnull id<SFSDKAnalyticsPublisher>) publisher;

/**
 * Updates the preferences of this library.
 */
- (void) updateLoggingPrefs;

@end
