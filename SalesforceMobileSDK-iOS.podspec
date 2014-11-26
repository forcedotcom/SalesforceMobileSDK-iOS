Pod::Spec.new do |s|

  s.name         = "SalesforceMobileSDK-iOS"
  s.version      = "3.0.0"
  s.summary      = "Salesforce Mobile SDK for iOS"
  s.homepage     = "https://github.com/forcedotcom/SalesforceMobileSDK-iOS"

  s.license      = { :type => "Salesforce.com Mobile SDK License", :file => "LICENSE.md" }
  s.author       = { "Kevin Hawkins" => "khawkins@salesforce.com" }

  s.platform     = :ios, "6.0"

  s.source       = { :git => "https://github.com/forcedotcom/SalesforceMobileSDK-iOS.git",
                     :branch => "unstable",
                     :submodules => true }

  s.prepare_command = <<-CMD
      sed -i -e 's/#import \\"Categories\\//#import \\"/g' external/MKNetworkKit/MKNetworkKit/MKNetworkKit.h
  CMD

  s.subspec 'OpenSSL' do |openssl|

      openssl.preserve_paths = 'external/ThirdPartyDependencies/openssl/openssl/*.h', 'external/ThirdPartyDependencies/openssl/openssl_license.txt'
      openssl.vendored_libraries = 'external/ThirdPartyDependencies/openssl/libcrypto.a', 'external/ThirdPartyDependencies/openssl/libssl.a'

  end

  s.subspec 'SQLCipher' do |sqlcipher|

      sqlcipher.preserve_paths = 'external/ThirdPartyDependencies/sqlcipher/LICENSE'
      sqlcipher.vendored_libraries = 'external/ThirdPartyDependencies/sqlcipher/libsqlcipher.a'

  end

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

  s.subspec 'MKNetworkKit' do |mknet|

      mknet.source_files = 'external/MKNetworkKit/MKNetworkKit/**/*.{h,m}'
      mknet.public_header_files = 'external/MKNetworkKit/MKNetworkKit/Categories/NSDictionary+RequestEncoding.h', 'external/MKNetworkKit/MKNetworkKit/Categories/NSString+MKNetworkKitAdditions.h', 'external/MKNetworkKit/MKNetworkKit/Categories/UIAlertView+MKNetworkKitAdditions.h', 'external/MKNetworkKit/MKNetworkKit/MKNetworkEngine.h', 'external/MKNetworkKit/MKNetworkKit/MKNetworkKit.h', 'external/MKNetworkKit/MKNetworkKit/MKNetworkOperation.h'
      mknet.header_dir = 'Headers/MKNetworkKit-iOS'
      mknet.prefix_header_contents = '#import "MKNetworkKit.h"'
      mknet.xcconfig = { 'HEADER_SEARCH_PATHS' => "${PODS_ROOT}/Headers/Public/#{s.name}/Headers" }
      mknet.requires_arc = true

  end

  s.subspec 'SalesforceSecurity' do |salesforcesecurity|

      salesforcesecurity.dependency 'SalesforceMobileSDK-iOS/SalesforceCommonUtils'
      salesforcesecurity.source_files = 'libs/SalesforceSecurity/SalesforceSecurity/Classes/*.{h,m}'
      salesforcesecurity.public_header_files = 'libs/SalesforceSecurity/SalesforceSecurity/Classes/SFPasscodeManager.h', 'libs/SalesforceSecurity/SalesforceSecurity/Classes/SFSDKCryptoUtils.h', 'libs/SalesforceSecurity/SalesforceSecurity/Classes/SFEncryptionKey.h', 'libs/SalesforceSecurity/SalesforceSecurity/Classes/SFPasscodeProviderManager.h', 'libs/SalesforceSecurity/SalesforceSecurity/Classes/SFKeyStoreKey.h', 'libs/SalesforceSecurity/SalesforceSecurity/Classes/SFKeyStoreManager.h', 'libs/SalesforceSecurity/SalesforceSecurity/Classes/SFPasscodeManager+Internal.h'
      salesforcesecurity.header_dir = 'Headers/SalesforceSecurity'
      salesforcesecurity.prefix_header_contents = '#import <SalesforceCommonUtils/SFLogger.h>'
      salesforcesecurity.xcconfig = { 'HEADER_SEARCH_PATHS' => "${PODS_ROOT}/Headers/Public/#{s.name}/Headers" }
      salesforcesecurity.requires_arc = true

  end

  s.subspec 'SalesforceOAuth' do |oauth|

      oauth.dependency 'SalesforceMobileSDK-iOS/SalesforceCommonUtils'
      oauth.dependency 'SalesforceMobileSDK-iOS/SalesforceSecurity'
      oauth.source_files = 'libs/SalesforceOAuth/SalesforceOAuth/Classes/**/*.{h,m}'
      oauth.public_header_files = 'libs/SalesforceOAuth/SalesforceOAuth/Classes/SFOAuthCoordinator.h', 'libs/SalesforceOAuth/SalesforceOAuth/Classes/SFOAuthCredentials.h', 'libs/SalesforceOAuth/SalesforceOAuth/Classes/SFOAuthInfo.h'
      oauth.header_dir = 'Headers/SalesforceOAuth'
      oauth.prefix_header_contents = '#import <SalesforceCommonUtils/SFLogger.h>'
      oauth.xcconfig = { 'HEADER_SEARCH_PATHS' => "${PODS_ROOT}/Headers/Public/#{s.name}/Headers" }
      oauth.requires_arc = true

  end

  s.subspec 'SalesforceSDKCore' do |sdkcore|

      sdkcore.dependency 'SalesforceMobileSDK-iOS/SalesforceCommonUtils'
      sdkcore.dependency 'SalesforceMobileSDK-iOS/SalesforceSecurity'
      sdkcore.dependency 'SalesforceMobileSDK-iOS/SalesforceOAuth'
      sdkcore.dependency 'SalesforceMobileSDK-iOS/OpenSSL'
      sdkcore.dependency 'SalesforceMobileSDK-iOS/SQLCipher'
      sdkcore.source_files = 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/**/*.{h,m}'
      sdkcore.public_header_files = 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Fmdb/FMDatabase.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Fmdb/FMResultSet.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Util/NSURL+SFStringUtils.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFAbstractPasscodeViewController.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Common/SFApplication.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFAuthErrorHandler.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFAuthErrorHandlerList.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFAuthenticationManager+Internal.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFAuthenticationManager.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFAuthenticationViewHandler.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFAuthorizingViewController.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFCommunityData.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFDefaultUserManagementViewController.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Util/SFDirectoryManager.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Identity/SFIdentityCoordinator.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Identity/SFIdentityData.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Util/SFJsonUtils.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Util/SFPreferences.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/PushNotification/SFPushNotificationManager.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/SmartStore/SFQuerySpec.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Util/SFSDKResourceUtils.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Test/SFSDKTestCredentialsData.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Test/SFSDKTestRequestListener.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Util/SFSDKWebUtils.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFPasscodeViewControllerTypes.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFSecurityLockout.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/SmartStore/SFSmartStore.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/SmartStore/SFSmartStoreDatabaseManager.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Common/SalesforceSDKManager.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Common/SFSDKAppConfig.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/SmartStore/SFSmartStoreInspectorViewController.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/SmartStore/SFSoupIndex.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/SmartStore/SFStoreCursor.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFUserAccount.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFUserAccountConstants.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFUserAccountIdentity.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFUserAccountManager.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Common/SFUserActivityMonitor.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Common/SalesforceSDKConstants.h', 'libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Test/TestSetupUtils.h'
      sdkcore.header_dir = 'Headers/SalesforceSDKCore'
      sdkcore.prefix_header_contents = '#import <SalesforceCommonUtils/SFLogger.h>', '#import "SalesforceSDKConstants.h"'
      sdkcore.resource_bundles = { 'SalesforceSDKResources' => [ 'shared/resources/SalesforceSDKResources.bundle/**' ], 'Settings' => [ 'shared/resources/Settings.bundle/**' ] }
      sdkcore.xcconfig = { 'HEADER_SEARCH_PATHS' => "${PODS_ROOT}/Headers/Public/#{s.name}/Headers", 'OTHER_CFLAGS' => '-DSQLITE_HAS_CODEC' }
      sdkcore.requires_arc = true

  end

  s.subspec 'SalesforceNetworkSDK' do |networksdk|

      networksdk.dependency 'SalesforceMobileSDK-iOS/MKNetworkKit'
      networksdk.dependency 'SalesforceMobileSDK-iOS/SalesforceSDKCore'
      networksdk.dependency 'SalesforceMobileSDK-iOS/SalesforceOAuth'
      networksdk.dependency 'SalesforceMobileSDK-iOS/SalesforceSecurity'
      networksdk.dependency 'SalesforceMobileSDK-iOS/SalesforceSDKCore'
      networksdk.dependency 'SalesforceMobileSDK-iOS/SalesforceCommonUtils'
      networksdk.dependency 'SalesforceMobileSDK-iOS/OpenSSL'
      networksdk.dependency 'SalesforceMobileSDK-iOS/SQLCipher'
      networksdk.source_files = 'libs/SalesforceNetworkSDK/SalesforceNetworkSDK/*.{h,m}'
      networksdk.public_header_files = 'libs/SalesforceNetworkSDK/SalesforceNetworkSDK/SFNetworkEngine.h', 'libs/SalesforceNetworkSDK/SalesforceNetworkSDK/SFNetworkOperation.h', 'libs/SalesforceNetworkSDK/SalesforceNetworkSDK/SFNetworkUtils.h', 'libs/SalesforceNetworkSDK/SalesforceNetworkSDK/SFNetworkCoordinator.h'
      networksdk.header_dir = 'Headers/SalesforceNetworkSDK'
      networksdk.prefix_header_contents = '#import <SalesforceCommonUtils/SalesforceCommonUtils.h>'
      networksdk.xcconfig = { 'HEADER_SEARCH_PATHS' => "${PODS_ROOT}/Headers/Public/#{s.name}/Headers" }
      networksdk.requires_arc = true

  end

  s.subspec 'SalesforceRestAPI' do |restapi|

      restapi.dependency 'SalesforceMobileSDK-iOS/SalesforceNetworkSDK'
      restapi.dependency 'SalesforceMobileSDK-iOS/MKNetworkKit'
      restapi.dependency 'SalesforceMobileSDK-iOS/SalesforceSDKCore'
      restapi.dependency 'SalesforceMobileSDK-iOS/SalesforceOAuth'
      restapi.dependency 'SalesforceMobileSDK-iOS/SalesforceSecurity'
      restapi.dependency 'SalesforceMobileSDK-iOS/SalesforceSDKCore'
      restapi.dependency 'SalesforceMobileSDK-iOS/SalesforceCommonUtils'
      restapi.dependency 'SalesforceMobileSDK-iOS/OpenSSL'
      restapi.dependency 'SalesforceMobileSDK-iOS/SQLCipher'
      restapi.source_files = 'libs/SalesforceRestAPI/SalesforceRestAPI/Classes/*.{h,m}'
      restapi.public_header_files = 'libs/SalesforceRestAPI/SalesforceRestAPI/Classes/SFRestAPI+QueryBuilder.h', 'libs/SalesforceRestAPI/SalesforceRestAPI/Classes/SFRestRequest.h', 'libs/SalesforceRestAPI/SalesforceRestAPI/Classes/SFRestAPI+Files.h', 'libs/SalesforceRestAPI/SalesforceRestAPI/Classes/SFRestAPI+Blocks.h', 'libs/SalesforceRestAPI/SalesforceRestAPI/Classes/SFRestAPI.h'
      restapi.header_dir = 'Headers/SalesforceRestAPI'
      restapi.prefix_header_contents = '#import <SalesforceCommonUtils/SFLogger.h>'
      restapi.xcconfig = { 'HEADER_SEARCH_PATHS' => "${PODS_ROOT}/Headers/Public/#{s.name}/Headers" }
      restapi.requires_arc = true

  end

  s.subspec 'SmartSync' do |smartsync|

      smartsync.dependency 'SalesforceMobileSDK-iOS/SalesforceRestAPI'
      smartsync.dependency 'SalesforceMobileSDK-iOS/SalesforceNetworkSDK'
      smartsync.dependency 'SalesforceMobileSDK-iOS/MKNetworkKit'
      smartsync.dependency 'SalesforceMobileSDK-iOS/SalesforceSDKCore'
      smartsync.dependency 'SalesforceMobileSDK-iOS/SalesforceOAuth'
      smartsync.dependency 'SalesforceMobileSDK-iOS/SalesforceSecurity'
      smartsync.dependency 'SalesforceMobileSDK-iOS/SalesforceSDKCore'
      smartsync.dependency 'SalesforceMobileSDK-iOS/SalesforceCommonUtils'
      smartsync.dependency 'SalesforceMobileSDK-iOS/OpenSSL'
      smartsync.dependency 'SalesforceMobileSDK-iOS/SQLCipher'
      smartsync.source_files = 'libs/SmartSync/SmartSync/Classes/**/*.{h,m}'
      smartsync.public_header_files = 'libs/SmartSync/SmartSync/Classes/Manager/SFSmartSyncCacheManager.h', 'libs/SmartSync/SmartSync/Classes/Manager/SFSmartSyncMetadataManager.h', 'libs/SmartSync/SmartSync/Classes/Manager/SFSmartSyncNetworkManager.h', 'libs/SmartSync/SmartSync/Classes/Model/SFObject.h', 'libs/SmartSync/SmartSync/Classes/Model/SFObjectType.h', 'libs/SmartSync/SmartSync/Classes/Model/SFObjectTypeLayout.h', 'libs/SmartSync/SmartSync/Classes/Util/SFSmartSyncConstants.h', 'libs/SmartSync/SmartSync/Classes/Util/SFSmartSyncObjectUtils.h', 'libs/SmartSync/SmartSync/Classes/Util/SFSmartSyncSoqlBuilder.h', 'libs/SmartSync/SmartSync/Classes/Util/SFSmartSyncSoslBuilder.h', 'libs/SmartSync/SmartSync/Classes/Util/SFSmartSyncSoslReturningBuilder.h'
      smartsync.header_dir = 'Headers/SmartSync'
      smartsync.prefix_header_contents = '#import <SalesforceCommonUtils/SFLogger.h>'
      smartsync.xcconfig = { 'HEADER_SEARCH_PATHS' => "${PODS_ROOT}/Headers/Public/#{s.name}/Headers" }
      smartsync.requires_arc = true

  end

end
