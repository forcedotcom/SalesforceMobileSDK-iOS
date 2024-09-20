/*
 SFLoginViewController.h
 SalesforceSDKCore
 
 Created by Kunal Chitalia on 1/22/16.
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
#import <SalesforceSDKCore/SFSDKViewController.h>

@class SFLoginViewController;
@class SFSDKLoginHost;
@class SFSDKLoginViewControllerConfig;
@class SFSDKLoginHostListViewController;
@class SFBiometricAuthenticationManager;

/**
 * Delegate protocol for the owner of SFLoginViewController.
 */
NS_SWIFT_NAME(SalesforceLoginViewControllerDelegate)
@protocol SFLoginViewControllerDelegate <NSObject>

@optional

/**
 * Notifies the delegate that the selected login host has been changed.
 * @param loginViewController The instance sending this message.
 * @param newLoginHost The updated login host.
 */
- (void)loginViewController:(nonnull SFLoginViewController *)loginViewController didChangeLoginHost:(nonnull SFSDKLoginHost *)newLoginHost;

@end

/** The Salesforce login screen view.
 */
NS_SWIFT_NAME(SalesforceLoginViewController)
@interface SFLoginViewController : SFSDKViewController


/**
 * The delegate representing the owner of this object.
 */
@property (nonatomic, weak, nullable) id<SFLoginViewControllerDelegate> delegate;

/**
 * Outlet to the OAuth web view.
 */
@property (nonatomic, strong, nullable) IBOutlet UIView *oauthView;

/** The biometric log in button */
@property (nonatomic, strong, readonly, nullable) UIButton *biometricButton;

/** Specify the font to use for navigation bar header text.*/
@property (nonatomic, strong, nullable) UIFont * navBarFont NS_SWIFT_NAME(navigationBarFont);

/** Specify the text color to use for navigation bar header text. */
@property (nonatomic, strong, nullable) UIColor * navBarTintColor  NS_SWIFT_NAME(navigationBarTintColor);

/** Specify the text color to use for navigation bar header text. */
@property (nonatomic, strong, nullable) UIColor * navBarTitleColor  NS_SWIFT_NAME(navigationBarTitleColor);

/** Specify navigation bar color. This color will be used by the login view header.
 */
@property (nonatomic, strong, nullable) UIColor *navBarColor NS_SWIFT_NAME(navigationBarColor);

/** Specify visibility of nav bar. This property will be used to hide/show the nav bar*/
@property (nonatomic) BOOL showNavbar NS_SWIFT_NAME(showsNavigationBar);

/** Specifiy the visibility of the settings icon. This property will be used to hide/show the settings icon*/
@property (nonatomic) BOOL showSettingsIcon NS_SWIFT_NAME(showsSettingsIcon);

/** Specify all display properties in a config. All the above properties are backed by
 a config object */
@property (nonatomic, strong, nonnull) SFSDKLoginViewControllerConfig *config;

/** Get the instance of nav bar. Use this property to get the instance of navBar*/
@property (nonatomic, strong, readonly, nullable) UINavigationBar *navBar;

/** Get the refrence  to the SFSDKLoginHostListViewController */
@property (nonatomic, strong) SFSDKLoginHostListViewController * _Nonnull loginHostListViewController;

/** Applies the view's style attributes to the given navigation bar.
 @param navigationBar The navigation bar that the style is applied to.
 */
- (void)styleNavigationBar:(nullable UINavigationBar *)navigationBar;

/** Present the Host List View.
 */
- (void)showHostListView;

/** Hide the Host List View.
 @param animated Indicates whether or not the hiding should be animated.
 */
- (void)hideHostListView:(BOOL)animated;

/** Factory Method to create the back button.
 */
- (nonnull UIBarButtonItem *)createBackButton;

/** Factory Method to create the settings button.
 */
- (nonnull UIBarButtonItem *)createSettingsButton;

/** Factory Method to create the navigation title.
 */
- (nonnull UIView *)createTitleItem;

/** Factory Method to create the hostListView Controller.
 */
- (nonnull SFSDKLoginHostListViewController *)createLoginHostListViewController;

/** Logic to show back button.
 */
- (BOOL)shouldShowBackButton;

/** Back Button was pressed by user
 */
- (void)handleBackButtonAction;

/** User Selected a host from the host list
 @param host SFSDKLoginHost
 */
- (void)handleLoginHostSelectedAction:(nonnull SFSDKLoginHost *)host;
@end
