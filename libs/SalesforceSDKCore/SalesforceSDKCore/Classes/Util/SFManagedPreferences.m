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

#import "SFManagedPreferences.h"
#import "SFUserAccountManager.h"
#import "SFIdentityData.h"
#import "SFSDKEventBuilderHelper.h"
#import "SFSDKAppFeatureMarkers.h"
#import <SalesforceAnalytics/NSUserDefaults+SFAdditions.h>

// See "Extending Your Apps for Enterprise and Education Use" in the WWDC 2013 videos
// See https://developer.apple.com/library/ios/samplecode/sc2279/ManagedAppConfig.zip
static NSString * const kManagedConfigurationKey   = @"com.apple.configuration.managed";
static NSString * const kManagedFeedbackKey        = @"com.apple.feedback.managed";  // XXX - For future "feedback" impl

// Managed key constants
static NSString * const kManagedKeyRequireCertAuth            = @"RequireCertAuth";
static NSString * const kManagedKeyLoginHosts                 = @"AppServiceHosts";
static NSString * const kManagedKeyLoginHostLabels            = @"AppServiceHostLabels";
static NSString * const kManagedKeyConnectedAppId             = @"ManagedAppOAuthID";
static NSString * const kManagedKeyConnectedAppCallbackUri    = @"ManagedAppCallbackURL";
static NSString * const kManagedKeyClearClipboardOnBackground = @"ClearClipboardOnBackground";
static NSString * const kManagedKeyOnlyShowAuthorizedHosts    = @"OnlyShowAuthorizedHosts";
static NSString * const kManagedKeyIDPAppURLScheme = @"IDPAppURLScheme";
static NSString * const kSFAppFeatureManagedByMDM   = @"MM";
static NSString * const kSFDisableExternalPaste = @"DISABLE_EXTERNAL_PASTE";

@interface SFManagedPreferences ()

@property (nonatomic, strong, readwrite) NSDictionary *rawPreferences;
@property (nonatomic, strong) NSOperationQueue *syncQueue;

@end

@implementation SFManagedPreferences

@synthesize rawPreferences = _rawPreferences;

+ (instancetype)sharedPreferences {
    static dispatch_once_t pred;
    static SFManagedPreferences *preferences = nil;
    dispatch_once(&pred, ^{
        preferences = [[self alloc] init];
    });
    return preferences;
}

- (id)init {
    self = [super init];
    if (self) {
        self.syncQueue = [[NSOperationQueue alloc] init];
        self.syncQueue.name = @"NSUserDefaults Sync Queue";
        __weak typeof(self) weakSelf = self;
        [[NSNotificationCenter defaultCenter] addObserverForName:NSUserDefaultsDidChangeNotification
                                                          object:nil
                                                           queue:self.syncQueue
                                                      usingBlock:^(NSNotification *note) {
                                                          [weakSelf configurePreferences];
                                                      }];
        [self configurePreferences];
        NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
        [notificationCenter addObserver:self
                               selector:@selector(storeAnalyticsEvent)
                                   name:SFUserAccountManagerDidFinishUserInitNotification
                                 object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)configurePreferences {
    self.rawPreferences = [[NSUserDefaults msdkUserDefaults] dictionaryForKey:kManagedConfigurationKey];
    if ([self hasManagedPreferences]) {
        [SFSDKAppFeatureMarkers registerAppFeature:kSFAppFeatureManagedByMDM];
    }
}

- (BOOL)hasManagedPreferences {
    return ([self.rawPreferences allKeys].count > 0);
}

- (BOOL)requireCertificateAuthentication {
    return [self.rawPreferences[kManagedKeyRequireCertAuth] boolValue];
}

- (BOOL)onlyShowAuthorizedHosts {
    return [self.rawPreferences[kManagedKeyOnlyShowAuthorizedHosts] boolValue];
}

- (NSString *)idpAppURLScheme {
    return self.rawPreferences[kManagedKeyIDPAppURLScheme];
}

- (NSArray *)loginHosts {
    id objLoginHosts = self.rawPreferences[kManagedKeyLoginHosts];
    if ([objLoginHosts isKindOfClass:[NSString class]]) {
        objLoginHosts = @[ objLoginHosts ];
    }
    return objLoginHosts;
}

- (NSArray *)loginHostLabels {
    id objLoginHostLabels = self.rawPreferences[kManagedKeyLoginHostLabels];
    if ([objLoginHostLabels isKindOfClass:[NSString class]]) {
        objLoginHostLabels = @[ objLoginHostLabels ];
    }
    return objLoginHostLabels;
}

- (NSString *)connectedAppId {
    return self.rawPreferences[kManagedKeyConnectedAppId];
}

- (NSString *)connectedAppCallbackUri {
    return self.rawPreferences[kManagedKeyConnectedAppCallbackUri];
}

- (BOOL)shouldDisableExternalPasteDefinedByConnectedApp {
    NSDictionary *customAttributes = [SFUserAccountManager sharedInstance].currentUser.idData.customAttributes;
    if (customAttributes) {
        NSString *disableExternalPaste = customAttributes[kSFDisableExternalPaste];
        if (disableExternalPaste) {
            return [disableExternalPaste boolValue];
        }
    }
    return NO;
}

- (BOOL)clearClipboardOnBackground {
    return [self.rawPreferences[kManagedKeyClearClipboardOnBackground] boolValue] || [self shouldDisableExternalPasteDefinedByConnectedApp];
}

- (void)storeAnalyticsEvent {
    NSMutableDictionary *attributes = [[NSMutableDictionary alloc] init];
    if (self.rawPreferences) {
        attributes[@"mdmIsActive"] = [NSNumber numberWithBool:YES];
        attributes[@"mdmConfigs"] = self.rawPreferences;
    } else {
        attributes[@"mdmIsActive"] = [NSNumber numberWithBool:NO];
    }
    [SFSDKEventBuilderHelper createAndStoreEvent:@"mdmConfiguration" userAccount:nil className:NSStringFromClass([self class]) attributes:attributes];
}

@end
