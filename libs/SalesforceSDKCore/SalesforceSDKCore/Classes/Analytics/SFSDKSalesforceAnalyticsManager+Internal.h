/*
 SFSDKSalesforceAnalyticsManager+Internal.h
 SalesforceSDKCore
 
 Created by Kevin Hawkins on 3/9/18.
 
 Copyright (c) 2018-present, salesforce.com, inc. All rights reserved.
 
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

#import <SalesforceSDKCore/SFSDKSalesforceAnalyticsManager.h>
#import <SalesforceSDKCore/SFAuthenticationManager.h>

@interface SFSDKAnalyticsTransformPublisherPair : NSObject

@property (nonnull, nonatomic, readonly, strong) id<SFSDKTransform> transform;
@property (nonnull, nonatomic, readonly, strong) id<SFSDKAnalyticsPublisher> publisher;

- (nonnull instancetype)initWithTransform:(nonnull id<SFSDKTransform>)transform publisher:(nonnull id<SFSDKAnalyticsPublisher>)publisher;

@end
SFSDK_USE_DEPRECATED_BEGIN

@interface SFSDKSalesforceAnalyticsManager () <SFAuthenticationManagerDelegate>

SFSDK_USE_DEPRECATED_END
@property (nonnull, nonatomic, readwrite, strong) SFSDKAnalyticsManager *analyticsManager;
@property (nonnull, nonatomic, readwrite, strong) SFSDKEventStoreManager *eventStoreManager;
@property (nullable, nonatomic, readwrite, strong) SFUserAccount *userAccount;
@property (nonnull, nonatomic, readwrite, strong) NSMutableArray<SFSDKAnalyticsTransformPublisherPair *> *remotes;

@end
