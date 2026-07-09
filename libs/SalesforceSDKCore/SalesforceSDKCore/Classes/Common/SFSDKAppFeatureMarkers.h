/*
 Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.
 
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

@class SFUserAccount;

NS_ASSUME_NONNULL_BEGIN

// App Feature Marker Constants
extern NSString * const kSFAppFeatureSwiftApp;
extern NSString * const kSFAppFeatureMultiUser;
extern NSString * const kSFAppFeatureMacApp;
extern NSString * const kSFAppFeatureNativeLogin;
extern NSString * const kSFAppFeatureWelcomeDiscovery;
extern NSString * const kSFAppFeatureSafariBrowserForLogin;
extern NSString * const kSFAppFeatureScreenLock;
extern NSString * const kSFAppFeatureBioAuth;
extern NSString * const kSFAppFeatureManagedByMDM;
extern NSString * const kSFAppFeatureOAuth;
extern NSString * const kSFAppFeatureAiltnEnabled;
extern NSString * const kSFSPAppFeatureIDPLogin;
extern NSString * const kSFIDPAppFeatureIDPLogin;
extern NSString * const kSFAppFeatureQrCodeLogin;
extern NSString * const kSFAppFeatureRTR;
extern NSString * const kSFAppFeatureAppAttestation;

/**
 Class to register and unregister feature markers associated with SDK facilities being used in
 an app.
 */
@interface SFSDKAppFeatureMarkers : NSObject

/**
 Register a particular app feature (global — all users).
 @param appFeature The string representation of the feature to register.
 */
+ (void)registerAppFeature:(nonnull NSString *)appFeature;

/**
 Unregister a particular app feature (global — all users).
 @param appFeature The string representation of the feature to unregister.
 */
+ (void)unregisterAppFeature:(nonnull NSString *)appFeature;

/**
 @return The current set of globally registered features.
 */
+ (nonnull NSSet<NSString *> *)appFeatures;

/**
 Register a feature for a specific user. If user is nil, registers globally.
 @param appFeature The string representation of the feature to register.
 @param user The user account to register the feature for, or nil for global registration.
 */
+ (void)registerAppFeature:(nonnull NSString *)appFeature forUser:(nullable SFUserAccount *)user;

/**
 Unregister a feature for a specific user. If user is nil, unregisters globally.
 @param appFeature The string representation of the feature to unregister.
 @param user The user account to unregister the feature for, or nil for global unregistration.
 */
+ (void)unregisterAppFeature:(nonnull NSString *)appFeature forUser:(nullable SFUserAccount *)user;

/**
 Returns the union of global features and per-user features for the given user.
 @param user The user account, or nil to return global features only.
 @return The combined set of registered features.
 */
+ (nonnull NSSet<NSString *> *)appFeaturesForUser:(nullable SFUserAccount *)user;

/**
 Populates the in-memory per-user map from persisted flags without triggering a save.
 Called during SDK startup after accounts are loaded.
 @param features The set of persisted feature flags.
 @param user The user account to load flags for.
 */
+ (void)loadPersistedFeatures:(nonnull NSSet<NSString *> *)features forUser:(nonnull SFUserAccount *)user;

@end

NS_ASSUME_NONNULL_END
