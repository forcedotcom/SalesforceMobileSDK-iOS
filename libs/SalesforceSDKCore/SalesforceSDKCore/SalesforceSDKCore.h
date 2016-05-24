/*
 SalesforceSDKCore.h
 SalesforceSDKCore

 Created by Michael Nachbaur on Wed May 11 11:34:05 PDT 2016.

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

#import <SalesforceSDKCore/NSArray+SFAdditions.h>
#import <SalesforceSDKCore/NSData+SFAdditions.h>
#import <SalesforceSDKCore/NSData+SFSDKUtils.h>
#import <SalesforceSDKCore/NSDictionary+SFAdditions.h>
#import <SalesforceSDKCore/NSNotificationCenter+SFAdditions.h>
#import <SalesforceSDKCore/NSString+SFAdditions.h>
#import <SalesforceSDKCore/NSURL+SFAdditions.h>
#import <SalesforceSDKCore/NSURL+SFStringUtils.h>
#import <SalesforceSDKCore/SalesforceSDKConstants.h>
#import <SalesforceSDKCore/SalesforceSDKCoreDefines.h>
#import <SalesforceSDKCore/SalesforceSDKManager.h>
#import <SalesforceSDKCore/SFAbstractPasscodeViewController.h>
#import <SalesforceSDKCore/SFApplication.h>
#import <SalesforceSDKCore/SFApplicationHelper.h>
#import <SalesforceSDKCore/SFAuthenticationManager.h>
#import <SalesforceSDKCore/SFAuthenticationViewHandler.h>
#import <SalesforceSDKCore/SFAuthErrorHandler.h>
#import <SalesforceSDKCore/SFAuthErrorHandlerList.h>
#import <SalesforceSDKCore/SFCommunityData.h>
#import <SalesforceSDKCore/SFCryptChunks.h>
#import <SalesforceSDKCore/SFCrypto.h>
#import <SalesforceSDKCore/SFDecryptStream.h>
#import <SalesforceSDKCore/SFDefaultUserManagementDetailViewController.h>
#import <SalesforceSDKCore/SFDefaultUserManagementListViewController.h>
#import <SalesforceSDKCore/SFDefaultUserManagementViewController.h>
#import <SalesforceSDKCore/SFDirectoryManager.h>
#import <SalesforceSDKCore/SFEncryptionKey.h>
#import <SalesforceSDKCore/SFEncryptStream.h>
#import <SalesforceSDKCore/SFFileProtectionHelper.h>
#import <SalesforceSDKCore/SFGeneratedKeyStore.h>
#import <SalesforceSDKCore/SFIdentityCoordinator.h>
#import <SalesforceSDKCore/SFIdentityData.h>
#import <SalesforceSDKCore/SFInactivityTimerCenter.h>
#import <SalesforceSDKCore/SFInstrumentation.h>
#import <SalesforceSDKCore/SFJsonUtils.h>
#import <SalesforceSDKCore/SFKeychainItemWrapper.h>
#import <SalesforceSDKCore/SFKeyStore.h>
#import <SalesforceSDKCore/SFKeyStoreKey.h>
#import <SalesforceSDKCore/SFKeyStoreManager.h>
#import <SalesforceSDKCore/SFLogger.h>
#import <SalesforceSDKCore/SFLoggerMacros.h>
#import <SalesforceSDKCore/SFLoginViewController.h>
#import <SalesforceSDKCore/SFManagedPreferences.h>
#import <SalesforceSDKCore/SFMethodInterceptor.h>
#import <SalesforceSDKCore/SFOAuthCoordinator.h>
#import <SalesforceSDKCore/SFOAuthCredentials.h>
#import <SalesforceSDKCore/SFOAuthCrypto.h>
#import <SalesforceSDKCore/SFOAuthInfo.h>
#import <SalesforceSDKCore/SFOAuthKeychainCredentials.h>
#import <SalesforceSDKCore/SFOAuthOrgAuthConfiguration.h>
#import <SalesforceSDKCore/SFOAuthSessionRefresher.h>
#import <SalesforceSDKCore/SFPasscodeKeyStore.h>
#import <SalesforceSDKCore/SFPasscodeManager+Internal.h>
#import <SalesforceSDKCore/SFPasscodeManager.h>
#import <SalesforceSDKCore/SFPasscodeProviderManager.h>
#import <SalesforceSDKCore/SFPasscodeViewController.h>
#import <SalesforceSDKCore/SFPasscodeViewControllerTypes.h>
#import <SalesforceSDKCore/SFPathUtil.h>
#import <SalesforceSDKCore/SFPBKDF2PasscodeProvider.h>
#import <SalesforceSDKCore/SFPBKDFData.h>
#import <SalesforceSDKCore/SFPreferences.h>
#import <SalesforceSDKCore/SFPushNotificationManager.h>
#import <SalesforceSDKCore/SFRootViewManager.h>
#import <SalesforceSDKCore/SFSDKAppConfig.h>
#import <SalesforceSDKCore/SFSDKAppDelegate.h>
#import <SalesforceSDKCore/SFSDKAsyncProcessListener.h>
#import <SalesforceSDKCore/SFSDKCryptoUtils.h>
#import <SalesforceSDKCore/SFSDKDatasharingHelper.h>
#import <SalesforceSDKCore/SFSDKLoginHost.h>
#import <SalesforceSDKCore/SFSDKLoginHostDelegate.h>
#import <SalesforceSDKCore/SFSDKLoginHostListViewController.h>
#import <SalesforceSDKCore/SFSDKLoginHostStorage.h>
#import <SalesforceSDKCore/SFSDKReachability.h>
#import <SalesforceSDKCore/SFSDKResourceUtils.h>
#import <SalesforceSDKCore/SFSDKTestCredentialsData.h>
#import <SalesforceSDKCore/SFSDKTestRequestListener.h>
#import <SalesforceSDKCore/SFSDKWebUtils.h>
#import <SalesforceSDKCore/SFSecurityLockout+Internal.h>
#import <SalesforceSDKCore/SFSecurityLockout.h>
#import <SalesforceSDKCore/SFSHA256PasscodeProvider.h>
#import <SalesforceSDKCore/SFTestContext.h>
#import <SalesforceSDKCore/SFUserAccount.h>
#import <SalesforceSDKCore/SFUserAccountConstants.h>
#import <SalesforceSDKCore/SFUserAccountIdentity.h>
#import <SalesforceSDKCore/SFUserAccountManager.h>
#import <SalesforceSDKCore/SFUserAccountManagerUpgrade.h>
#import <SalesforceSDKCore/SFUserActivityMonitor.h>
#import <SalesforceSDKCore/TestSetupUtils.h>
#import <SalesforceSDKCore/UIDevice+SFHardware.h>
#import <SalesforceSDKCore/UIScreen+SFAdditions.h>
