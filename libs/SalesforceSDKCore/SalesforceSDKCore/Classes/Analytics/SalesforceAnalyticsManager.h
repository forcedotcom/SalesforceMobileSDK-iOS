/*
 SalesforceAnalyticsManager.h
 SalesforceSDKCore
 
 Created by Bharath Hariharan on 6/16/16.
 
 Copyright (c) 2016, salesforce.com, inc. All rights reserved.
 
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
#import "AnalyticsPublisher.h"
#import <SalesforceAnalytics/AnalyticsManager.h>
#import <SalesforceAnalytics/Transform.h>

@interface SalesforceAnalyticsManager : NSObject

@property (nonatomic, readonly, strong) EventStoreManager *eventStoreManager;
@property (nonatomic, readonly, strong) AnalyticsManager *analyticsManager;

/**
 * Returns an instance of this class associated with the specified user account.
 *
 * @param userAccount User account.
 * @return Instance of this class.
 */
+ (id) sharedInstanceWithUser:(SFUserAccount *) userAccount;

/**
 * Resets and removes the instance associated with the specified user account.
 *
 * @param userAccount User account.
 */
+ (void) removeSharedInstanceWithUser:(SFUserAccount *) userAccount;

/**
 * Publishes all stored events to all registered network endpoints after
 * applying the required event format transforms. Stored events will be
 * deleted if publishing was successful for all registered endpoints.
 */
- (void) publishAllEvents;

/**
 * Publishes a list of events to all registered network endpoints after
 * applying the required event format transforms. Stored events will be
 * deleted if publishing was successful for all registered endpoints.
 *
 * @param events List of events.
 */
- (void) publishEvents:(NSArray<InstrumentationEvent *> *) events;

/**
 * Publishes an event to all registered network endpoints after
 * applying the required event format transforms. Stored event will be
 * deleted if publishing was successful for all registered endpoints.
 *
 * @param event Event.
 */
- (void) publishEvent:(InstrumentationEvent *) event;

/**
 * Adds a remote publisher to publish events to.
 *
 * @param transformer Transformer class.
 * @param publisher Publisher class.
 */
- (void) addRemotePublisher:(Class<Transform>) transformer publisher:(Class<AnalyticsPublisher>) publisher;

@end
