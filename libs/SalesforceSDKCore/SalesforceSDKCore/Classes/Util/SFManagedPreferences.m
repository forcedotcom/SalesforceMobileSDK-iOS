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

@interface SFManagedPreferences ()

@property (nonatomic, strong, readwrite) NSDictionary *rawPreferences;

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
        __weak SFManagedPreferences *weakSelf = self;
        [[NSNotificationCenter defaultCenter] addObserverForName:NSUserDefaultsDidChangeNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *note) {
                                                          weakSelf.rawPreferences = [[NSUserDefaults standardUserDefaults] dictionaryForKey:kManagedConfigurationKey];
                                                      }];
        self.rawPreferences = [[NSUserDefaults standardUserDefaults] dictionaryForKey:kManagedConfigurationKey];
    }
    return self;
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

- (BOOL)clearClipboardOnBackground {
    return [self.rawPreferences[kManagedKeyClearClipboardOnBackground] boolValue];
}

@end
