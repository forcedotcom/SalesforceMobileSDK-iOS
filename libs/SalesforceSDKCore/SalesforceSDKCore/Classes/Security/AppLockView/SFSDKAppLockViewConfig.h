/*
 SFSDKAppLockViewConfig.h
 SalesforceSDKCore
 
 Created by Brandon Page on 10/15/18.
 
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

#import <Foundation/Foundation.h>
#import <SalesforceSDKCore/SFSDKViewControllerConfig.h>
#import <SalesforceSDKCore/SalesforceSDKConstants.h>

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(AppLockViewControllerConfig)
@interface SFSDKAppLockViewConfig : SFSDKViewControllerConfig

/**
 * factory method to create a default config instance
 */
+ (instancetype)createDefaultConfig;

/**
 * The number of allowed passcode entry attempts before the user is logged out.
 */
@property (nonatomic) NSUInteger maxNumberOfAttempts;

/**
 * Primary color used for passcode input circles and forward buttons.
 */
@property (nonatomic, strong, nullable) UIColor * primaryColor;

/**
 * Secondary color used for the background of the passcode and biometric enable fields.
 */
@property (nonatomic, strong, nullable) UIColor * secondaryColor;

/**
 * The background color of the screen.
 */
@property (nonatomic, strong, nullable) UIColor * backgroundColor;

/**
 * The background color of layered content.
 */
@property (nonatomic, strong, nullable) UIColor *secondaryBackgroundColor;

/**
 * Border color for the passcode and biometric enable fields.
 */
@property (nonatomic, strong, nullable) UIColor * borderColor;

/**
 * Color of the instruction text for passcode and biometric fields.
 */
@property (nonatomic, strong, nullable) UIColor * instructionTextColor;

/**
 * Color of the title text for passcode and biometric fields.
 */
@property (nonatomic, strong, nullable) UIColor * titleTextColor;

/**
 * Color of the logout button on passcode verify screen.
 */
@property (nonatomic, strong, nonnull) UIColor * logoutButtonColor;

/**
 * Font used for displaying instructions.
 */
@property (nonatomic, strong, nullable) UIFont * instructionFont;

/**
 * Font used for displaying titles.
 */
@property (nonatomic, strong, nullable) UIFont * titleFont;

/**
 * Font used for displaying buttons.
 */
@property (nonatomic, strong, nullable) UIFont * buttonFont;

/**
 * Image used when enabling Touch Id.
 */
@property (nonatomic, strong, nullable) UIImage * touchIdImage;

/**
 * Image used when enabling Face Id.
 */
@property (nonatomic, strong, nullable) UIImage * faceIdImage;

@end

NS_ASSUME_NONNULL_END
