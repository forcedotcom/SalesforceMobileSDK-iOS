Pod::Spec.new do |s|

  s.name         = "SalesforceMobileSDK-iOS"
  s.version      = "3.3.1"
  s.summary      = "Salesforce Mobile SDK for iOS"
  s.homepage     = "https://github.com/forcedotcom/SalesforceMobileSDK-iOS"

  s.license      = { :type => "Salesforce.com Mobile SDK License", :file => "LICENSE.md" }
  s.author       = { "Kevin Hawkins" => "khawkins@salesforce.com" }

  s.platform     = :ios, "7.0"

  s.source       = { :git => "https://github.com/forcedotcom/SalesforceMobileSDK-iOS.git",
                     :tag => "pod_v#{s.version}",
                     :submodules => true }
  
  s.requires_arc = true

  s.subspec 'SalesforceCommonUtils' do |commonutils|

      commonutils.source_files = 'external/ThirdPartyDependencies/SalesforceCommonUtils/Headers/SalesforceCommonUtils/*.h'
      commonutils.public_header_files = 'external/ThirdPartyDependencies/SalesforceCommonUtils/Headers/SalesforceCommonUtils/*.h'
      commonutils.header_dir = 'Headers/SalesforceCommonUtils'
      commonutils.prefix_header_contents = '#import <SalesforceCommonUtils/SFLogger.h>'
      commonutils.vendored_libraries = 'external/ThirdPartyDependencies/SalesforceCommonUtils/libSalesforceCommonUtils.a'
      commonutils.frameworks = 'MessageUI'
      commonutils.libraries = 'z'
      commonutils.xcconfig = { 'HEADER_SEARCH_PATHS' => "${PODS_ROOT}/Headers/Public/#{s.name}/Headers" }

  end

  s.subspec 'SalesforceSDKCommon' do |salesforcesdkcommon|

      salesforcesdkcommon.source_files = 'libs/SalesforceSDKCommon/SalesforceSDKCommon/Classes/*.{h,m}', 'libs/SalesforceSDKCommon/SalesforceSDKCommon/SalesforceSDKCommon.h'
      salesforcesdkcommon.public_header_files = 'libs/SalesforceSDKCommon/SalesforceSDKCommon/Classes/NSData+SFSDKUtils.h', 'libs/SalesforceSDKCommon/SalesforceSDKCommon/Classes/Test/SFSDKAsyncProcessListener.h', 'libs/SalesforceSDKCommon/SalesforceSDKCommon/Classes/SFSDKReachability.h', 'libs/SalesforceSDKCommon/SalesforceSDKCommon/SalesforceSDKCommon.h'
      salesforcesdkcommon.header_dir = 'Headers/SalesforceSDKCommon'
      salesforcesdkcommon.xcconfig = { 'HEADER_SEARCH_PATHS' => "${PODS_ROOT}/Headers/Public/#{s.name}/Headers" }
      salesforcesdkcommon.requires_arc = true

  end

  s.subspec 'SalesforceSecurity' do |salesforcesecurity|

      salesforcesecurity.dependency 'SalesforceMobileSDK-iOS/SalesforceCommonUtils'
      salesforcesecurity.dependency 'SalesforceMobileSDK-iOS/SalesforceSDKCommon'
      salesforcesecurity.source_files = 'libs/SalesforceSecurity/SalesforceSecurity/Classes/*.{h,m}', 'libs/SalesforceSecurity/SalesforceSecurity/SalesforceSecurity.h'
      salesforcesecurity.public_header_files = 'libs/SalesforceSecurity/SalesforceSecurity/Classes/SFEncryptionKey.h', 'libs/SalesforceSecurity/SalesforceSecurity/Classes/SFKeyStoreKey.h', 'libs/SalesforceSecurity/SalesforceSecurity/Classes/SFKeyStoreManager.h', 'libs/SalesforceSecurity/SalesforceSecurity/Classes/SFPasscodeManager+Internal.h', 'libs/SalesforceSecurity/SalesforceSecurity/Classes/SFPasscodeManager.h', 'libs/SalesforceSecurity/SalesforceSecurity/Classes/SFPasscodeProviderManager.h', 'libs/SalesforceSecurity/SalesforceSecurity/Classes/SFSDKCryptoUtils.h', 'libs/SalesforceSecurity/SalesforceSecurity/SalesforceSecurity.h'
      salesforcesecurity.header_dir = 'Headers/SalesforceSecurity'
      salesforcesecurity.prefix_header_contents = '#import <SalesforceCommonUtils/SFLogger.h>'
      salesforcesecurity.xcconfig = { 'HEADER_SEARCH_PATHS' => "${PODS_ROOT}/Headers/Public/#{s.name}/Headers" }
      salesforcesecurity.requires_arc = true

  end

  s.subspec 'SalesforceOAuth' do |oauth|

      oauth.dependency 'SalesforceMobileSDK-iOS/SalesforceCommonUtils'
      oauth.dependency 'SalesforceMobileSDK-iOS/SalesforceSDKCommon'
      oauth.dependency 'SalesforceMobileSDK-iOS/SalesforceSecurity'
      oauth.source_files = 'libs/SalesforceOAuth/SalesforceOAuth/Classes/**/*.{h,m}', 'libs/SalesforceOAuth/SalesforceOAuth/SalesforceOAuth.h'
      oauth.public_header_files = 'libs/SalesforceOAuth/SalesforceOAuth/Classes/SFOAuthCoordinator.h', 'libs/SalesforceOAuth/SalesforceOAuth/Classes/SFOAuthCredentials.h', 'libs/SalesforceOAuth/SalesforceOAuth/Classes/SFOAuthInfo.h', 'libs/SalesforceOAuth/SalesforceOAuth/SalesforceOAuth.h'
      oauth.header_dir = 'Headers/SalesforceOAuth'
      oauth.prefix_header_contents = '#import <SalesforceCommonUtils/SFLogger.h>'
      oauth.xcconfig = { 'HEADER_SEARCH_PATHS' => "${PODS_ROOT}/Headers/Public/#{s.name}/Headers" }
      oauth.requires_arc = true

  end

  s.subspec 'SalesforceSDKCore' do |sdkcore|

      sdkcore.dependency 'SalesforceMobileSDK-iOS/SalesforceCommonUtils'
      sdkcore.dependency 'SalesforceMobileSDK-iOS/SalesforceSDKCommon'
      sdkcore.dependency 'SalesforceMobileSDK-iOS/SalesforceSecurity'
      sdkcore.dependency 'SalesforceMobileSDK-iOS/SalesforceOAuth'
      sdkcore.dependency 'SQLCipher', '~> 3.1'
      sdkcore.dependency 'SQLCipher/fts', '~> 3.1'
      sdkcore.source_files = 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/**/*.{h,m}', 'libs/SalesforceSDKCore/SalesforceSDKCore/SalesforceSDKCore.h', 'external/fmdb/src/fmdb/*.{h,m}'
      sdkcore.public_header_files = 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Util/NSURL+SFStringUtils.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFAbstractPasscodeViewController.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Common/SFApplication.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFAuthErrorHandler.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFAuthErrorHandlerList.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFAuthenticationManager+Internal.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFAuthenticationManager.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFAuthenticationViewHandler.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFAuthorizingViewController.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFCommunityData.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFDefaultUserManagementViewController.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Util/SFDirectoryManager.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Identity/SFIdentityCoordinator.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Identity/SFIdentityData.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Util/SFJsonUtils.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Util/SFManagedPreferences.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFPasscodeViewControllerTypes.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Util/SFPreferences.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/PushNotification/SFPushNotificationManager.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/SmartStore/SFQuerySpec.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Common/SFSDKAppConfig.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Protocols/SFSDKAppDelegate.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Util/SFSDKResourceUtils.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Test/SFSDKTestCredentialsData.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Test/SFSDKTestRequestListener.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Util/SFSDKWebUtils.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFSecurityLockout.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/SmartStore/SFSmartStore.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/SmartStore/SFSmartStoreDatabaseManager.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/SmartStore/SFSmartStoreInspectorViewController.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/SmartStore/SFSoupIndex.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/SmartStore/SFStoreCursor.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFUserAccount.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFUserAccountConstants.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFUserAccountIdentity.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFUserAccountManager.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Common/SFUserActivityMonitor.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Common/SalesforceSDKConstants.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/SalesforceSDKCore.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Util/SalesforceSDKCoreDefines.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Common/SalesforceSDKManager.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Test/TestSetupUtils.h'
      sdkcore.header_dir = 'Headers/SalesforceSDKCore'
      sdkcore.prefix_header_contents = '#import <SalesforceCommonUtils/SFLogger.h>', '#import "SalesforceSDKConstants.h"'
      sdkcore.resource_bundles = { 'SalesforceSDKResources' => [ 'shared/resources/SalesforceSDKResources.bundle/**' ], 'Settings' => [ 'shared/resources/Settings.bundle/**' ] }
      sdkcore.xcconfig = { 'HEADER_SEARCH_PATHS' => "${PODS_ROOT}/Headers/Public/#{s.name}/Headers", 'OTHER_CFLAGS' => '-DSQLITE_HAS_CODEC -DFMDatabase=SF_FMDatabase -DFMStatement=SF_FMStatement -DFMDatabasePool=SF_FMDatabasePool -DFMDatabaseQueue=SF_FMDatabaseQueue -DFMResultSet=SF_FMResultSet -DFMDBBlockSQLiteCallBackFunction=SF_FMDBBlockSQLiteCallBackFunction' }
      sdkcore.requires_arc = true

  end

  s.subspec 'SalesforceNetwork' do |networksdk|

      networksdk.dependency 'SalesforceMobileSDK-iOS/SalesforceSDKCore'
      networksdk.dependency 'SalesforceMobileSDK-iOS/SalesforceOAuth'
      networksdk.dependency 'SalesforceMobileSDK-iOS/SalesforceSecurity'
      networksdk.dependency 'SalesforceMobileSDK-iOS/SalesforceCommonUtils'
      networksdk.dependency 'SalesforceMobileSDK-iOS/SalesforceSDKCommon'
      networksdk.dependency 'SQLCipher', '~> 3.1'
      networksdk.dependency 'SQLCipher/fts', '~> 3.1'
      networksdk.source_files = 'libs/SalesforceNetwork/SalesforceNetwork/SalesforceNetwork/Classes/**/*.{h,m}', 'libs/SalesforceNetwork/SalesforceNetwork/SalesforceNetworkiOS/*.{h,m}', 'libs/SalesforceNetwork/SalesforceNetwork.h'
      networksdk.public_header_files = 'libs/SalesforceNetwork/SalesforceNetwork/SalesforceNetwork/Classes/Network/Action/CSFAction.h', 'libs/SalesforceNetwork/SalesforceNetwork/SalesforceNetwork/Classes/Protocols/CSFActionInput.h', 'libs/SalesforceNetwork/SalesforceNetwork/SalesforceNetwork/Classes/Protocols/CSFActionModel.h', 'libs/SalesforceNetwork/SalesforceNetwork/SalesforceNetwork/Classes/Protocols/CSFActionValue.h', 'libs/SalesforceNetwork/SalesforceNetwork/SalesforceNetwork/Classes/Network/OAuth/CSFAuthRefresh.h', 'libs/SalesforceNetwork/SalesforceNetwork/SalesforceNetwork/Classes/Utilities/CSFAvailability.h', 'libs/SalesforceNetwork/SalesforceNetwork/SalesforceNetwork/Classes/Utilities/CSFDefines.h', 'libs/SalesforceNetwork/SalesforceNetwork/SalesforceNetwork/Classes/Utilities/CSFForceDefines.h', 'libs/SalesforceNetwork/SalesforceNetwork/SalesforceNetwork/Classes/Protocols/CSFIndexedEntity.h', 'libs/SalesforceNetwork/SalesforceNetwork/SalesforceNetwork/Classes/Network/Model/CSFInput.h', 'libs/SalesforceNetwork/SalesforceNetwork/SalesforceNetwork/Classes/Network/Queue/CSFNetwork.h', 'libs/SalesforceNetwork/SalesforceNetwork/SalesforceNetwork/Classes/Protocols/CSFNetworkOutputCache.h', 'libs/SalesforceNetwork/SalesforceNetwork/SalesforceNetwork/Classes/Network/Model/CSFOutput.h', 'libs/SalesforceNetwork/SalesforceNetwork/SalesforceNetwork/Classes/Network/Support/CSFParameterStorage.h', 'libs/SalesforceNetwork/SalesforceNetwork/SalesforceNetwork/Classes/Network/Action/CSFSalesforceAction.h', 'libs/SalesforceNetwork/SalesforceNetwork/SalesforceNetwork/Classes/Additions/SFUserAccount+SalesforceNetwork.h', 'libs/SalesforceNetwork/SalesforceNetwork.h'
      networksdk.header_dir = 'Headers/SalesforceNetwork'
      networksdk.xcconfig = { 'HEADER_SEARCH_PATHS' => "${PODS_ROOT}/Headers/Public/#{s.name}/Headers" }
      networksdk.requires_arc = true
      networksdk.frameworks = 'MobileCoreServices'

  end

  s.subspec 'SalesforceRestAPI' do |restapi|

      restapi.dependency 'SalesforceMobileSDK-iOS/SalesforceNetwork'
      restapi.dependency 'SalesforceMobileSDK-iOS/SalesforceSDKCore'
      restapi.dependency 'SalesforceMobileSDK-iOS/SalesforceOAuth'
      restapi.dependency 'SalesforceMobileSDK-iOS/SalesforceSecurity'
      restapi.dependency 'SalesforceMobileSDK-iOS/SalesforceSDKCore'
      restapi.dependency 'SalesforceMobileSDK-iOS/SalesforceCommonUtils'
      restapi.dependency 'SalesforceMobileSDK-iOS/SalesforceSDKCommon'
      restapi.dependency 'SQLCipher', '~> 3.1'
      restapi.dependency 'SQLCipher/fts', '~> 3.1'
      restapi.source_files = 'libs/SalesforceRestAPI/SalesforceRestAPI/Classes/*.{h,m}', 'libs/SalesforceRestAPI/SalesforceRestAPI/SalesforceRestAPI.h'
      restapi.public_header_files = 'libs/SalesforceRestAPI/SalesforceRestAPI/Classes/SFRestAPI+Blocks.h', 'libs/SalesforceRestAPI/SalesforceRestAPI/Classes/SFRestAPI+Files.h', 'libs/SalesforceRestAPI/SalesforceRestAPI/Classes/SFRestAPI+QueryBuilder.h', 'libs/SalesforceRestAPI/SalesforceRestAPI/Classes/SFRestAPI.h', 'libs/SalesforceRestAPI/SalesforceRestAPI/Classes/SFRestAPISalesforceAction.h', 'libs/SalesforceRestAPI/SalesforceRestAPI/Classes/SFRestRequest.h', 'libs/SalesforceRestAPI/SalesforceRestAPI/SalesforceRestAPI.h'
      restapi.header_dir = 'Headers/SalesforceRestAPI'
      restapi.prefix_header_contents = '#import <SalesforceCommonUtils/SFLogger.h>'
      restapi.xcconfig = { 'HEADER_SEARCH_PATHS' => "${PODS_ROOT}/Headers/Public/#{s.name}/Headers" }
      restapi.requires_arc = true

  end

  s.subspec 'SmartSync' do |smartsync|

      smartsync.dependency 'SalesforceMobileSDK-iOS/SalesforceRestAPI'
      smartsync.dependency 'SalesforceMobileSDK-iOS/SalesforceNetwork'
      smartsync.dependency 'SalesforceMobileSDK-iOS/SalesforceSDKCore'
      smartsync.dependency 'SalesforceMobileSDK-iOS/SalesforceOAuth'
      smartsync.dependency 'SalesforceMobileSDK-iOS/SalesforceSecurity'
      smartsync.dependency 'SalesforceMobileSDK-iOS/SalesforceSDKCore'
      smartsync.dependency 'SalesforceMobileSDK-iOS/SalesforceCommonUtils'
      smartsync.dependency 'SalesforceMobileSDK-iOS/SalesforceSDKCommon'
      smartsync.dependency 'SQLCipher', '~> 3.1'
      smartsync.dependency 'SQLCipher/fts', '~> 3.1'
      smartsync.source_files = 'libs/SmartSync/SmartSync/Classes/**/*.{h,m}', 'libs/SmartSync/SmartSync/SmartSync.h'
      smartsync.public_header_files = 'libs/SmartSync/SmartSync/Classes/Util/SFMruSyncDownTarget.h', 'libs/SmartSync/SmartSync/Classes/Model/SFObject.h', 'libs/SmartSync/SmartSync/Classes/Model/SFObjectType.h', 'libs/SmartSync/SmartSync/Classes/Model/SFObjectTypeLayout.h', 'libs/SmartSync/SmartSync/Classes/Manager/SFSmartSyncCacheManager.h', 'libs/SmartSync/SmartSync/Classes/Util/SFSmartSyncConstants.h', 'libs/SmartSync/SmartSync/Classes/Manager/SFSmartSyncMetadataManager.h', 'libs/SmartSync/SmartSync/Classes/Util/SFSmartSyncNetworkUtils.h', 'libs/SmartSync/SmartSync/Classes/Util/SFSmartSyncObjectUtils.h', 'libs/SmartSync/SmartSync/Classes/Model/SFSmartSyncPersistableObject.h', 'libs/SmartSync/SmartSync/Classes/Util/SFSmartSyncSoqlBuilder.h', 'libs/SmartSync/SmartSync/Classes/Util/SFSmartSyncSoslBuilder.h', 'libs/SmartSync/SmartSync/Classes/Util/SFSmartSyncSoslReturningBuilder.h', 'libs/SmartSync/SmartSync/Classes/Manager/SFSmartSyncSyncManager.h', 'libs/SmartSync/SmartSync/Classes/Util/SFSoqlSyncDownTarget.h', 'libs/SmartSync/SmartSync/Classes/Util/SFSoslSyncDownTarget.h', 'libs/SmartSync/SmartSync/Classes/Util/SFSyncDownTarget.h', 'libs/SmartSync/SmartSync/Classes/Util/SFSyncOptions.h', 'libs/SmartSync/SmartSync/Classes/Util/SFSyncState.h', 'libs/SmartSync/SmartSync/Classes/Util/SFSyncTarget.h', 'libs/SmartSync/SmartSync/Classes/Util/SFSyncUpTarget.h', 'libs/SmartSync/SmartSync/SmartSync.h'
      smartsync.header_dir = 'Headers/SmartSync'
      smartsync.prefix_header_contents = '#import <SalesforceCommonUtils/SFLogger.h>'
      smartsync.xcconfig = { 'HEADER_SEARCH_PATHS' => "${PODS_ROOT}/Headers/Public/#{s.name}/Headers" }
      smartsync.requires_arc = true

  end

end
