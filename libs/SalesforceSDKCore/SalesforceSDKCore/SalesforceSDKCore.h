/*
 SalesforceSDKCore.h
 SalesforceSDKCore

 Created by Wolfgang Mathurin on Thu May 12 16:16:51 PDT 2022.

 Copyright (c) 2022-present, salesforce.com, inc. All rights reserved.
 
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

#import <SalesforceSDKCore/SFDefaultUserManagementDetailViewController.h>
#import <SalesforceSDKCore/SFSDKCoreLogger.h>
#import <SalesforceSDKCore/SFFormatUtils.h>
#import <SalesforceSDKCore/SFCryptChunks.h>
#import <SalesforceSDKCore/SFSDKAlertMessageBuilder.h>
#import <SalesforceSDKCore/SFSDKSoslBuilder.h>
#import <SalesforceSDKCore/SFOAuthInfo.h>
#import <SalesforceSDKCore/SFDecryptStream.h>
#import <SalesforceSDKCore/SFSDKCollectionResponse.h>
#import <SalesforceSDKCore/NSData+SFAdditions.h>
#import <SalesforceSDKCore/SFSDKSalesforceAnalyticsManager.h>
#import <SalesforceSDKCore/NSURL+SFAdditions.h>
#import <SalesforceSDKCore/SFLoginViewController.h>
#import <SalesforceSDKCore/SFSDKDevInfoViewController.h>
#import <SalesforceSDKCore/SFSDKUserSelectionNavViewController.h>
#import <SalesforceSDKCore/SFRestAPI+Notifications.h>
#import <SalesforceSDKCore/SFSDKInstrumentationHelper.h>
#import <SalesforceSDKCore/SFSDKPrimingRecordsResponse.h>
#import <SalesforceSDKCore/SFSDKAsyncProcessListener.h>
#import <SalesforceSDKCore/SFSDKTestRequestListener.h>
#import <SalesforceSDKCore/UIColor+SFColors.h>
#import <SalesforceSDKCore/SFSDKLoginHostDelegate.h>
#import <SalesforceSDKCore/SFSDKPushNotificationError.h>
#import <SalesforceSDKCore/SFOAuthCoordinator.h>
#import <SalesforceSDKCore/SFSDKOAuth2.h>
#import <SalesforceSDKCore/SFKeyStoreManager.h>
#import <SalesforceSDKCore/SFOAuthOrgAuthConfiguration.h>
#import <SalesforceSDKCore/SFSDKCompositeResponse.h>
#import <SalesforceSDKCore/SFOAuthCredentials.h>
#import <SalesforceSDKCore/SFUserAccountManager.h>
#import <SalesforceSDKCore/SFUserAccount.h>
#import <SalesforceSDKCore/SFSDKBatchRequest.h>
#import <SalesforceSDKCore/SFSDKWindowManager.h>
#import <SalesforceSDKCore/NSNotificationCenter+SFAdditions.h>
#import <SalesforceSDKCore/SFEncryptionKey.h>
#import <SalesforceSDKCore/SFDirectoryManager.h>
#import <SalesforceSDKCore/SFSDKPushNotificationDecryption.h>
#import <SalesforceSDKCore/SFSDKAILTNPublisher.h>
#import <SalesforceSDKCore/SFSDKLoginHost.h>
#import <SalesforceSDKCore/SFSDKTestCredentialsData.h>
#import <SalesforceSDKCore/SFIdentityCoordinator.h>
#import <SalesforceSDKCore/SFSDKUserSelectionView.h>
#import <SalesforceSDKCore/NSURLResponse+SFAdditions.h>
#import <SalesforceSDKCore/SFApplicationHelper.h>
#import <SalesforceSDKCore/SFDefaultUserManagementViewController.h>
#import <SalesforceSDKCore/SFSecureEncryptionKey.h>
#import <SalesforceSDKCore/SFSDKUserSelectionTableViewController.h>
#import <SalesforceSDKCore/SFSDKNavigationController.h>
#import <SalesforceSDKCore/SFSDKLoginHostStorage.h>
#import <SalesforceSDKCore/SFSDKWindowContainer.h>
#import <SalesforceSDKCore/SFSDKCompositeRequest.h>
#import <SalesforceSDKCore/SFSDKLoginHostListViewController.h>
#import <SalesforceSDKCore/SFSDKAnalyticsPublisher.h>
#import <SalesforceSDKCore/SFSDKAppConfig.h>
#import <SalesforceSDKCore/NSArray+SFAdditions.h>
#import <SalesforceSDKCore/SFSDKEventBuilderHelper.h>
#import <SalesforceSDKCore/SFSDKSoqlBuilder.h>
#import <SalesforceSDKCore/NSString+SFAdditions.h>
#import <SalesforceSDKCore/NSData+SFSDKUtils.h>
#import <SalesforceSDKCore/UIScreen+SFAdditions.h>
#import <SalesforceSDKCore/SFRestAPI+QueryBuilder.h>
#import <SalesforceSDKCore/SFSDKAppDelegate.h>
#import <SalesforceSDKCore/SFRestAPI+Blocks.h>
#import <SalesforceSDKCore/SFSDKAuthConfigUtil.h>
#import <SalesforceSDKCore/SFSDKAlertMessage.h>
#import <SalesforceSDKCore/SFUserAccountIdentity.h>
#import <SalesforceSDKCore/SFSDKAuthHelper.h>
#import <SalesforceSDKCore/SFManagedPreferences.h>
#import <SalesforceSDKCore/SFRestRequest.h>
#import <SalesforceSDKCore/TestSetupUtils.h>
#import <SalesforceSDKCore/SalesforceSDKManager.h>
#import <SalesforceSDKCore/SFSDKBatchResponse.h>
#import <SalesforceSDKCore/NSURL+SFStringUtils.h>
#import <SalesforceSDKCore/SFInactivityTimerCenter.h>
#import <SalesforceSDKCore/SalesforceSDKConstants.h>
#import <SalesforceSDKCore/SFSObjectTree.h>
#import <SalesforceSDKCore/SFSDKUITableViewCell.h>
#import <SalesforceSDKCore/SFRestAPI.h>
#import <SalesforceSDKCore/NSDictionary+SFAdditions.h>
#import <SalesforceSDKCore/SalesforceSDKCoreDefines.h>
#import <SalesforceSDKCore/SFAuthErrorHandlerList.h>
#import <SalesforceSDKCore/SFDefaultUserManagementListViewController.h>
#import <SalesforceSDKCore/SFSDKWebViewStateManager.h>
#import <SalesforceSDKCore/SFPushNotificationManager.h>
#import <SalesforceSDKCore/SFSDKViewController.h>
#import <SalesforceSDKCore/NSObject+SFBlocks.h>
#import <SalesforceSDKCore/SFSDKViewControllerConfig.h>
#import <SalesforceSDKCore/SFNetwork.h>
#import <SalesforceSDKCore/SFIdentityData.h>
#import <SalesforceSDKCore/SFPreferences.h>
#import <SalesforceSDKCore/SFSDKWebUtils.h>
#import <SalesforceSDKCore/SFRestAPI+Files.h>
#import <SalesforceSDKCore/SFSDKLoginViewControllerConfig.h>
#import <SalesforceSDKCore/SFUserAccountConstants.h>
#import <SalesforceSDKCore/SFOAuthSessionRefresher.h>
#import <SalesforceSDKCore/SFSDKResourceUtils.h>
#import <SalesforceSDKCore/SFSDKCryptoUtils.h>
#import <SalesforceSDKCore/SFSDKPushNotificationFieldsConstants.h>
#import <SalesforceSDKCore/UIDevice+SFHardware.h>
#import <SalesforceSDKCore/SFSDKLoginFlowSelectionView.h>
#import <SalesforceSDKCore/SFMethodInterceptor.h>
#import <SalesforceSDKCore/SFSDKAppFeatureMarkers.h>
#import <SalesforceSDKCore/SFSDKSoslReturningBuilder.h>
#import <SalesforceSDKCore/SFApplication.h>
#import <SalesforceSDKCore/SFInstrumentation.h>
