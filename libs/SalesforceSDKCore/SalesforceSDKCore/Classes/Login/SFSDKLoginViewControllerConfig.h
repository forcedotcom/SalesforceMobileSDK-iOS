/*
 SFSDKLoginViewControllerConfig.h
 SalesforceSDKCore

 Created by Raj Rao on 11/15/17.

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
@protocol SFLoginViewControllerDelegate;
@class SFLoginViewController;

/**
 Block typedef for setting up a custom SFLoginViewController.
 */
typedef SFLoginViewController * _Nonnull (^SFLoginViewControllerCreationBlock)(void);

@interface SFSDKLoginViewControllerConfig : NSObject

/** Specify the font to use for navigation bar header text.*/
@property (nonatomic, strong, nullable) UIFont * navBarFont;

/** Specify the text color to use for navigation bar header text. */
@property (nonatomic, strong, nullable) UIColor * navBarTextColor;

/** Specify navigation bar color. This color will be used by the login view header.
 */
@property (nonatomic, strong, nullable) UIColor *navBarColor;

/** Specify navigation bar title color. This color will be used by the login view header.
 */
@property (nonatomic, strong, nullable) UIColor *navBarTitleColor;

/** Specify visibility of nav bar. This property will be used to hide/show the nav bar*/
@property (nonatomic) BOOL showNavbar;

/** Specifiy the visibility of the settings icon. This property will be used to hide/show the settings icon*/
@property (nonatomic) BOOL showSettingsIcon;

/** Specifiy the visibility of the back icon. This property value can be changed by changing the value of shouldAuthenticate in bootconfig or by subclasssing SFLoginViewController.
 */
@property (nonatomic,readonly) BOOL shouldDisplayBackButton;

/** Specifiy a delegate for LoginViewController. */
@property (nonatomic, weak, nullable) id<SFLoginViewControllerDelegate> delegate;

@property (nonatomic, copy, nullable) SFLoginViewControllerCreationBlock  loginViewControllerCreationBlock;

@end
