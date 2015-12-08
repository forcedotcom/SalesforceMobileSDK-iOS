Pod::Spec.new do |s|

  s.name         = "SalesforceMobileSDK-iOS"
  s.version      = "4.0.0"
  s.summary      = "Salesforce Mobile SDK for iOS"
  s.homepage     = "https://github.com/forcedotcom/SalesforceMobileSDK-iOS"

  s.license      = { :type => "Salesforce.com Mobile SDK License", :file => "LICENSE.md" }
  s.author       = { "Kevin Hawkins" => "khawkins@salesforce.com" }

  s.platform     = :ios, "8.0"

  s.source       = { :git => "https://github.com/forcedotcom/SalesforceMobileSDK-iOS.git",
                     :tag => "pod_v#{s.version}",
                     :submodules => true }
  
  s.requires_arc = true
  s.default_subspec  = 'SalesforceSDKCore'

  s.subspec 'SalesforceSDKCore' do |sdkcore|

      sdkcore.dependency 'CocoaLumberjack', '~> 2.2.0'
      sdkcore.source_files = 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/**/*.{h,m}', 'libs/SalesforceSDKCore/SalesforceSDKCore/SalesforceSDKCore.h'
      sdkcore.exclude_files = 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Common/SFKeychainItemWrapper.m'
      sdkcore.public_header_files = 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Common/NSArray+SFAdditions.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Common/NSData+SFAdditions.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Common/NSData+SFSDKUtils.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Common/NSDictionary+SFAdditions.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Common/NSNotificationCenter+SFAdditions.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Common/NSString+SFAdditions.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Common/NSURL+SFAdditions.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Util/NSURL+SFStringUtils.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFAbstractPasscodeViewController.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Common/SFApplication.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFAuthErrorHandler.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFAuthErrorHandlerList.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFAuthenticationManager.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFAuthenticationViewHandler.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFAuthorizingViewController.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Common/Logging/SFCocoaLumberJackCustomFormatter.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFCommunityData.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Common/SFCrypto.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFDefaultUserManagementDetailViewController.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFDefaultUserManagementListViewController.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFDefaultUserManagementViewController.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Util/SFDirectoryManager.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFEncryptionKey.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Common/SFFileProtectionHelper.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFGeneratedKeyStore.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Identity/SFIdentityCoordinator.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Identity/SFIdentityData.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Common/SFInactivityTimerCenter.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Instrumentation/SFInstrumentation.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Util/SFJsonUtils.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFKeyStore.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFKeyStoreKey.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFKeyStoreManager.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Common/SFKeychainItemWrapper.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Common/Logging/SFLogger.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Util/SFManagedPreferences.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Instrumentation/SFMethodInterceptor.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/OAuth/SFOAuthCoordinator.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/OAuth/SFOAuthCredentials.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/OAuth/SFOAuthCrypto.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/OAuth/SFOAuthInfo.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/OAuth/SFOAuthKeychainCredentials.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/OAuth/SFOAuthOrgAuthConfiguration.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/OAuth/SFOAuthSessionRefresher.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFPBKDF2PasscodeProvider.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFPBKDFData.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFPasscodeKeyStore.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFPasscodeManager+Internal.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFPasscodeManager.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFPasscodeProviderManager.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFPasscodeViewController.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFPasscodeViewControllerTypes.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Common/SFPathUtil.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Util/SFPreferences.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/PushNotification/SFPushNotificationManager.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Util/SFRootViewManager.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Common/SFSDKAppConfig.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Protocols/SFSDKAppDelegate.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Test/SFSDKAsyncProcessListener.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFSDKCryptoUtils.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Common/SFSDKDatasharingHelper.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Common/SFSDKReachability.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Util/SFSDKResourceUtils.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Test/SFSDKTestCredentialsData.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Test/SFSDKTestRequestListener.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Util/SFSDKWebUtils.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFSHA256PasscodeProvider.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFSecurityLockout+Internal.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFSecurityLockout.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Common/SFTestContext.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFUserAccount.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFUserAccountConstants.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFUserAccountIdentity.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFUserAccountManager.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFUserAccountManagerUpgrade.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Common/SFUserActivityMonitor.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Common/SalesforceSDKConstants.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/SalesforceSDKCore.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Util/SalesforceSDKCoreDefines.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Common/SalesforceSDKManager.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Test/TestSetupUtils.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Common/UIDevice+SFHardware.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Common/UIScreen+SFAdditions.h'
      sdkcore.header_dir = 'Headers/SalesforceSDKCore'
      sdkcore.prefix_header_contents = '#import "SFLogger.h"', '#import "SalesforceSDKConstants.h"'
      sdkcore.libraries = 'z'
      sdkcore.resource_bundles = { 'SalesforceSDKResources' => [ 'shared/resources/SalesforceSDKResources.bundle/**' ], 'Settings' => [ 'shared/resources/Settings.bundle/**' ] }
      sdkcore.xcconfig = { 'HEADER_SEARCH_PATHS' => "${PODS_ROOT}/Headers/Public/#{s.name}/Headers" }
      sdkcore.requires_arc = true

      sdkcore.subspec 'no-arc' do |sp|
          sp.source_files = 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Common/SFKeychainItemWrapper.m'
          sp.requires_arc = false
       end
  end

  s.subspec 'SalesforceNetwork' do |networksdk|

      networksdk.dependency 'SalesforceMobileSDK-iOS/SalesforceSDKCore'
      networksdk.source_files = 'libs/SalesforceNetwork/SalesforceNetwork/SalesforceNetwork/Classes/**/*.{h,m}', 'libs/SalesforceNetwork/SalesforceNetwork/SalesforceNetwork/*.{h,m}', 'libs/SalesforceNetwork/SalesforceNetwork.h'
      networksdk.public_header_files = 'libs/SalesforceNetwork/SalesforceNetwork/SalesforceNetwork/Classes/Network/Action/CSFAction.h', 'libs/SalesforceNetwork/SalesforceNetwork/SalesforceNetwork/Classes/Protocols/CSFActionInput.h', 'libs/SalesforceNetwork/SalesforceNetwork/SalesforceNetwork/Classes/Protocols/CSFActionModel.h', 'libs/SalesforceNetwork/SalesforceNetwork/SalesforceNetwork/Classes/Protocols/CSFActionValue.h', 'libs/SalesforceNetwork/SalesforceNetwork/SalesforceNetwork/Classes/Network/OAuth/CSFAuthRefresh.h', 'libs/SalesforceNetwork/SalesforceNetwork/SalesforceNetwork/Classes/Utilities/CSFAvailability.h', 'libs/SalesforceNetwork/SalesforceNetwork/SalesforceNetwork/Classes/Utilities/CSFDefines.h', 'libs/SalesforceNetwork/SalesforceNetwork/SalesforceNetwork/Classes/Utilities/CSFForceDefines.h', 'libs/SalesforceNetwork/SalesforceNetwork/SalesforceNetwork/Classes/Protocols/CSFIndexedEntity.h', 'libs/SalesforceNetwork/SalesforceNetwork/SalesforceNetwork/Classes/Network/Model/CSFInput.h', 'libs/SalesforceNetwork/SalesforceNetwork/SalesforceNetwork/Classes/Network/Queue/CSFNetwork.h', 'libs/SalesforceNetwork/SalesforceNetwork/SalesforceNetwork/Classes/Protocols/CSFNetworkOutputCache.h', 'libs/SalesforceNetwork/SalesforceNetwork/SalesforceNetwork/Classes/Network/Model/CSFOutput.h', 'libs/SalesforceNetwork/SalesforceNetwork/SalesforceNetwork/Classes/Network/Support/CSFParameterStorage.h', 'libs/SalesforceNetwork/SalesforceNetwork/SalesforceNetwork/Classes/Network/Action/CSFSalesforceAction.h', 'libs/SalesforceNetwork/SalesforceNetwork/SalesforceNetwork/Classes/Additions/SFUserAccount+SalesforceNetwork.h', 'libs/SalesforceNetwork/SalesforceNetwork.h'
      networksdk.header_dir = 'Headers/SalesforceNetwork'
      networksdk.xcconfig = { 'HEADER_SEARCH_PATHS' => "${PODS_ROOT}/Headers/Public/#{s.name}/Headers" }
      networksdk.requires_arc = true
      networksdk.frameworks = 'MobileCoreServices'

  end

  s.subspec 'SQLCipher' do |sqlcipher|

      sqlcipher.preserve_paths = 'external/ThirdPartyDependencies/sqlcipher/LICENSE'
      sqlcipher.vendored_libraries = 'external/ThirdPartyDependencies/sqlcipher/libsqlcipher.a'

  end

  s.subspec 'SmartStore' do |smartstore|

      smartstore.dependency 'SalesforceMobileSDK-iOS/SalesforceSDKCore'
      smartstore.dependency 'SalesforceMobileSDK-iOS/SQLCipher'
      smartstore.dependency 'FMDB', '~> 2.5'
      smartstore.source_files = 'libs/Smartstore/Smartstore/Classes/**/*.{h,m}', 'libs/Smartstore/Smartstore/Smartstore.h'
      smartstore.public_header_files = 'libs/SmartStore/SmartStore/Classes/SFAlterSoupLongOperation.h', 'libs/SmartStore/SmartStore/Classes/SFQuerySpec.h', 'libs/SmartStore/SmartStore/Classes/SFSmartSqlHelper.h', 'libs/SmartStore/SmartStore/Classes/SFSmartStore.h', 'libs/SmartStore/SmartStore/Classes/SFSmartStoreDatabaseManager.h', 'libs/SmartStore/SmartStore/Classes/SFSmartStoreInspectorViewController.h', 'libs/SmartStore/SmartStore/Classes/SFSmartStoreUpgrade.h', 'libs/SmartStore/SmartStore/Classes/SFSmartStoreUtils.h', 'libs/SmartStore/SmartStore/Classes/SFSoupIndex.h', 'libs/SmartStore/SmartStore/Classes/SFStoreCursor.h', 'libs/SmartStore/SmartStore/Classes/SalesforceSDKManagerWithSmartStore.h', 'libs/SmartStore/SmartStore/SmartStore.h', 'libs/SmartStore/SmartStore/Classes/sqlite/SqliteAdditions.h'
      smartstore.header_dir = 'Headers/SmartStore'
      smartstore.prefix_header_contents = '#import <SalesforceSDKCore/SFLogger.h>'
      smartstore.xcconfig = { 'HEADER_SEARCH_PATHS' => "${PODS_ROOT}/Headers/Public/#{s.name}/Headers", 'OTHER_CFLAGS' => '-DSQLITE_HAS_CODEC' }
      smartstore.requires_arc = true

  end

  s.subspec 'SalesforceRestAPI' do |restapi|

      restapi.dependency 'SalesforceMobileSDK-iOS/SalesforceNetwork'
      restapi.dependency 'SalesforceMobileSDK-iOS/SalesforceSDKCore'
      restapi.source_files = 'libs/SalesforceRestAPI/SalesforceRestAPI/Classes/*.{h,m}', 'libs/SalesforceRestAPI/SalesforceRestAPI/SalesforceRestAPI.h'
      restapi.public_header_files = 'libs/SalesforceRestAPI/SalesforceRestAPI/Classes/SFRestAPI+Blocks.h', 'libs/SalesforceRestAPI/SalesforceRestAPI/Classes/SFRestAPI+Files.h', 'libs/SalesforceRestAPI/SalesforceRestAPI/Classes/SFRestAPI+QueryBuilder.h', 'libs/SalesforceRestAPI/SalesforceRestAPI/Classes/SFRestAPI.h', 'libs/SalesforceRestAPI/SalesforceRestAPI/Classes/SFRestAPISalesforceAction.h', 'libs/SalesforceRestAPI/SalesforceRestAPI/Classes/SFRestRequest.h', 'libs/SalesforceRestAPI/SalesforceRestAPI/SalesforceRestAPI.h'
      restapi.header_dir = 'Headers/SalesforceRestAPI'
      restapi.prefix_header_contents = '#import <SalesforceSDKCore/SFLogger.h>'
      restapi.xcconfig = { 'HEADER_SEARCH_PATHS' => "${PODS_ROOT}/Headers/Public/#{s.name}/Headers" }
      restapi.requires_arc = true

  end

  s.subspec 'SmartSync' do |smartsync|

      smartsync.dependency 'SalesforceMobileSDK-iOS/SalesforceRestAPI'
      smartsync.dependency 'SalesforceMobileSDK-iOS/SmartStore'
      smartsync.source_files = 'libs/SmartSync/SmartSync/Classes/**/*.{h,m}', 'libs/SmartSync/SmartSync/SmartSync.h'
      smartsync.public_header_files = 'libs/SmartSync/SmartSync/Classes/Util/SFMruSyncDownTarget.h', 'libs/SmartSync/SmartSync/Classes/Model/SFObject.h', 'libs/SmartSync/SmartSync/Classes/Model/SFObjectType.h', 'libs/SmartSync/SmartSync/Classes/Model/SFObjectTypeLayout.h', 'libs/SmartSync/SmartSync/Classes/Manager/SFSmartSyncCacheManager.h', 'libs/SmartSync/SmartSync/Classes/Util/SFSmartSyncConstants.h', 'libs/SmartSync/SmartSync/Classes/Manager/SFSmartSyncMetadataManager.h', 'libs/SmartSync/SmartSync/Classes/Util/SFSmartSyncNetworkUtils.h', 'libs/SmartSync/SmartSync/Classes/Util/SFSmartSyncObjectUtils.h', 'libs/SmartSync/SmartSync/Classes/Model/SFSmartSyncPersistableObject.h', 'libs/SmartSync/SmartSync/Classes/Util/SFSmartSyncSoqlBuilder.h', 'libs/SmartSync/SmartSync/Classes/Util/SFSmartSyncSoslBuilder.h', 'libs/SmartSync/SmartSync/Classes/Util/SFSmartSyncSoslReturningBuilder.h', 'libs/SmartSync/SmartSync/Classes/Manager/SFSmartSyncSyncManager.h', 'libs/SmartSync/SmartSync/Classes/Util/SFSoqlSyncDownTarget.h', 'libs/SmartSync/SmartSync/Classes/Util/SFSoslSyncDownTarget.h', 'libs/SmartSync/SmartSync/Classes/Util/SFSyncDownTarget.h', 'libs/SmartSync/SmartSync/Classes/Util/SFSyncOptions.h', 'libs/SmartSync/SmartSync/Classes/Util/SFSyncState.h', 'libs/SmartSync/SmartSync/Classes/Util/SFSyncTarget.h', 'libs/SmartSync/SmartSync/Classes/Util/SFSyncUpTarget.h', 'libs/SmartSync/SmartSync/SmartSync.h'
      smartsync.header_dir = 'Headers/SmartSync'
      smartsync.prefix_header_contents = '#import <SalesforceSDKCore/SFLogger.h>'
      smartsync.xcconfig = { 'HEADER_SEARCH_PATHS' => "${PODS_ROOT}/Headers/Public/#{s.name}/Headers" }
      smartsync.requires_arc = true

  end

  s.subspec 'SalesforceReact' do |salesforcereact|

      salesforcereact.dependency 'SalesforceMobileSDK-iOS/SmartSync'
      salesforcereact.source_files = 'libs/SalesforceReact/SalesforceReact/Classes/**/*.{h,m}'
      salesforcereact.public_header_files = 'libs/SalesforceReact/SalesforceReact/Classes/SFNetReactBridge.h', 'libs/SalesforceReact/SalesforceReact/Classes/SFOauthReactBridge.h', 'libs/SalesforceReact/SalesforceReact/Classes/SFSmartStoreReactBridge.h', 'libs/SalesforceReact/SalesforceReact/Classes/SFSmartSyncReactBridge.h', 'libs/SalesforceReact/SalesforceReact/SalesforceReact.h'
      salesforcereact.header_dir = 'Headers/SalesforceReact'
      salesforcereact.prefix_header_contents = '#import <SalesforceSDKCore/SFLogger.h>'
      salesforcereact.xcconfig = { 'HEADER_SEARCH_PATHS' => "${PODS_ROOT}/Headers/Public/#{s.name}/Headers" }
      salesforcereact.requires_arc = true

  end


end
