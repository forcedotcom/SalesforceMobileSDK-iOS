/*
 SalesforceSDKCore.h
 SalesforceSDKCore

 Created by Michael Nachbaur on Tue Jan 12 13:24:19 PST 2016.

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

#import "NSArray+SFAdditions.h"
#import "NSData+SFAdditions.h"
#import "NSData+SFSDKUtils.h"
#import "NSDictionary+SFAdditions.h"
#import "NSNotificationCenter+SFAdditions.h"
#import "NSString+SFAdditions.h"
#import "NSURL+SFAdditions.h"
#import "NSURL+SFStringUtils.h"
#import "SalesforceSDKConstants.h"
#import "SalesforceSDKCoreDefines.h"
#import "SalesforceSDKManager.h"
#import "SFAbstractPasscodeViewController.h"
#import "SFApplication.h"
#import "SFAuthenticationManager.h"
#import "SFAuthenticationViewHandler.h"
#import "SFAuthErrorHandler.h"
#import "SFAuthErrorHandlerList.h"
#import "SFAuthorizingViewController.h"
#import "SFCocoaLumberJackCustomFormatter.h"
#import "SFCommunityData.h"
#import "SFCrypto.h"
#import "SFDefaultUserManagementDetailViewController.h"
#import "SFDefaultUserManagementListViewController.h"
#import "SFDefaultUserManagementViewController.h"
#import "SFDirectoryManager.h"
#import "SFEncryptionKey.h"
#import "SFFileProtectionHelper.h"
#import "SFGeneratedKeyStore.h"
#import "SFIdentityCoordinator.h"
#import "SFIdentityData.h"
#import "SFInactivityTimerCenter.h"
#import "SFInstrumentation.h"
#import "SFJsonUtils.h"
#import "SFKeychainItemWrapper.h"
#import "SFKeyStore.h"
#import "SFKeyStoreKey.h"
#import "SFKeyStoreManager.h"
#import "SFLogger.h"
#import "SFManagedPreferences.h"
#import "SFMethodInterceptor.h"
#import "SFOAuthCoordinator.h"
#import "SFOAuthCredentials.h"
#import "SFOAuthCrypto.h"
#import "SFOAuthInfo.h"
#import "SFOAuthKeychainCredentials.h"
#import "SFOAuthOrgAuthConfiguration.h"
#import "SFOAuthSessionRefresher.h"
#import "SFPasscodeKeyStore.h"
#import "SFPasscodeManager+Internal.h"
#import "SFPasscodeManager.h"
#import "SFPasscodeProviderManager.h"
#import "SFPasscodeViewController.h"
#import "SFPasscodeViewControllerTypes.h"
#import "SFPathUtil.h"
#import "SFPBKDF2PasscodeProvider.h"
#import "SFPBKDFData.h"
#import "SFPreferences.h"
#import "SFPushNotificationManager.h"
#import "SFRootViewManager.h"
#import "SFSDKAppConfig.h"
#import "SFSDKAppDelegate.h"
#import "SFSDKAsyncProcessListener.h"
#import "SFSDKCryptoUtils.h"
#import "SFSDKDatasharingHelper.h"
#import "SFSDKReachability.h"
#import "SFSDKResourceUtils.h"
#import "SFSDKTestCredentialsData.h"
#import "SFSDKTestRequestListener.h"
#import "SFSDKWebUtils.h"
#import "SFSecurityLockout+Internal.h"
#import "SFSecurityLockout.h"
#import "SFSHA256PasscodeProvider.h"
#import "SFTestContext.h"
#import "SFUserAccount.h"
#import "SFUserAccountConstants.h"
#import "SFUserAccountIdentity.h"
#import "SFUserAccountManager.h"
#import "SFUserAccountManagerUpgrade.h"
#import "SFUserActivityMonitor.h"
#import "TestSetupUtils.h"
#import "UIDevice+SFHardware.h"
#import "UIScreen+SFAdditions.h"
