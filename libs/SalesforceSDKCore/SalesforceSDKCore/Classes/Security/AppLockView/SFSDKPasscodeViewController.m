/*
 SFSDKPasscodeViewController.m
 SalesforceSDKCore
 
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

#import "SFSDKPasscodeViewController.h"
#import "SFSDKPasscodeCreateUpdateController.h"
#import "SFSDKPasscodeVerifyController.h"
#import "SFPasscodeManager.h"
#import "SFSDKBiometricViewController+Internal.h"
#import "SFSDKPasscodeViewConfig.h"
#import "SFSDKResourceUtils.h"
#import <LocalAuthentication/LocalAuthentication.h>

@interface SFSDKPasscodeViewController () <SFSDKPasscodeCreateUpdateDelegate,SFSDKBiometricViewDelegate>
/**
 * The configuration data used to create or update the passcode.
 */
@property (readonly) SFPasscodeConfigurationData configData;

/**
 Setup passcode view related preferences.
 */
@property (nonatomic, readonly) SFSDKPasscodeViewConfig *viewConfig;


@end

@implementation SFSDKPasscodeViewController

- (instancetype)initWithPasscodeConfigData:(SFPasscodeConfigurationData)configData viewConfig:(SFSDKPasscodeViewConfig *)config mode:(SFPasscodeControllerMode)mode {
    
    _configData = configData;
    _viewConfig = config;
    UIViewController *controller = [self controllerFromMode:mode configData:configData andViewConfig:config];
    self = [super initWithRootViewController:controller];
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated{
   [self setupNavBar];
}

- (void)setupNavBar {
    [self.navigationController.view setBackgroundColor:[UIColor clearColor]];
    self.navigationController.navigationBar.backgroundColor = self.viewConfig.navBarColor;
    self.navigationController.navigationBar.tintColor = self.viewConfig.navBarColor;
    self.navigationBar.translucent = NO;
    self.navigationController.navigationBar.titleTextAttributes =
        @{NSForegroundColorAttributeName : self.viewConfig.navBarTextColor,
                     NSFontAttributeName : self.viewConfig.navBarFont};
}


#pragma mark - SFSDKPasscodeCreateUpdateDelegate

- (void)passcodeVerified:(NSString *)passcode
{
    if ([self canPromptBiometricEnrollment]) {
        [self promptBiometricEnrollment:passcode];
    } else {
        SFSecurityLockoutAction action = SFSecurityLockoutActionPasscodeVerified;
        [self unlock:passcode lockAction:action];
    }
}

- (void)passcodeCreated:(NSString *)passcode updateMode:(BOOL)isUpdateMode
{
    if ([self canPromptBiometricEnrollment]) {
        [self promptBiometricEnrollment:passcode];
    } else {
        SFSecurityLockoutAction action = isUpdateMode?SFSecurityLockoutActionPasscodeChanged:SFSecurityLockoutActionPasscodeCreated;
        [self unlock:passcode lockAction:action];
    }
}

#pragma mark - SFSDKBiometricViewDelegate
- (void)biometricUnlockSucceeded:(NSString *)currentPasscode verificationMode:(BOOL)isVerificationMode {
    SFSecurityLockoutAction action = isVerificationMode?SFSecurityLockoutActionPasscodeChanged:SFSecurityLockoutActionPasscodeCreated;
    [self.navigationController popViewControllerAnimated:NO];
    [SFSecurityLockout setBiometricUnlockEnabled:YES];
    [self unlock:currentPasscode lockAction:action];
}

- (void)biometricUnlockFailed:(NSString *)currentPasscode verificationMode:(BOOL)isVerificationMode  {
    if (isVerificationMode) {
        [self.navigationController popViewControllerAnimated:NO];
        SFSDKPasscodeVerifyController *pvc = [[SFSDKPasscodeVerifyController alloc] initWithPasscodeConfigData:self.configData viewConfig:self.viewConfig];
        pvc.verifyDelegate = self;
        [self pushViewController:pvc animated:NO];
    } else {
        [SFSecurityLockout setUserDeclinedBiometricUnlock:YES];
        SFSecurityLockoutAction action = isVerificationMode?SFSecurityLockoutActionPasscodeVerified:SFSecurityLockoutActionPasscodeCreated;
        [self unlock:currentPasscode lockAction:action];
    }
}

-(UIViewController *)controllerFromMode:(SFPasscodeControllerMode) mode configData:(SFPasscodeConfigurationData)configData andViewConfig:(SFSDKPasscodeViewConfig *)viewConfig
{
    UIViewController *currentViewController = nil;
    
    if (mode == SFBiometricControllerModeEnable || mode == SFBiometricControllerModeVerify) {
        SFSDKBiometricViewController *pvc = [[SFSDKBiometricViewController alloc] initWithPasscodeConfigData:configData viewConfig:viewConfig];
        pvc.biometricResponseDelgate = self;
        pvc.verificationMode = (mode == SFBiometricControllerModeVerify);
        currentViewController = pvc;
    } else if (mode == SFPasscodeControllerModeCreate || mode == SFPasscodeControllerModeChange) {
        SFSDKPasscodeCreateUpdateController *pvc = [[SFSDKPasscodeCreateUpdateController alloc] initWithPasscodeConfigData:configData viewConfig:viewConfig];
        pvc.createDelegate = self;
        pvc.updateMode = (mode == SFPasscodeControllerModeChange);
        currentViewController = pvc;
    } else {
        SFSDKPasscodeVerifyController *pvc = [[SFSDKPasscodeVerifyController alloc] initWithPasscodeConfigData:configData viewConfig:viewConfig];
        pvc.verifyDelegate = self;
        currentViewController = pvc;
    }
    return currentViewController;
}

#pragma mark - private methods
- (BOOL)canPromptBiometricEnrollment
{
    return !([SFSecurityLockout userDeclinedBiometricUnlock] || [SFSecurityLockout biometricUnlockEnabled]) && [self canShowBiometric];
}

- (BOOL)canShowBiometric
{
    LAContext *context = [[LAContext alloc] init];
    BOOL deviceHasBiometric = [context canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:nil];
    return [SFSecurityLockout biometricUnlockAllowed] && deviceHasBiometric;
}

- (void)promptBiometricEnrollment:(NSString *)passcode
{
    SFSDKBiometricViewController *pvc = [[SFSDKBiometricViewController alloc] initWithPasscodeConfigData:self.configData viewConfig:self.viewConfig];
    pvc.biometricResponseDelgate = self;
    pvc.currentPasscode = passcode;
    [self pushViewController:pvc animated:NO];
}

- (void)unlock:(NSString *)passcode lockAction:(SFSecurityLockoutAction) action{
    [self.navigationController popViewControllerAnimated:NO];
    dispatch_async(dispatch_get_main_queue(), ^{
        [SFSecurityLockout setupTimer];
        if ([SFSecurityLockout passcodeLength] == 0) {
            [[SFPasscodeManager sharedManager] changePasscode:passcode];
            SFPasscodeConfigurationData newConfigData;
            newConfigData.passcodeLength = passcode.length;
            newConfigData.lockoutTime = self.configData.lockoutTime;
            newConfigData.biometricUnlockAllowed = self.configData.biometricUnlockAllowed;
            [SFSecurityLockout unlock:YES action:action passcodeConfig:newConfigData];
        } else {
            [SFSecurityLockout unlock:YES action:action passcodeConfig:self.configData];
        }
    });
}
@end

