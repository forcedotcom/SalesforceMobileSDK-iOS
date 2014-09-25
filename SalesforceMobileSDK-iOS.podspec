Pod::Spec.new do |s|

  s.name         = "SalesforceMobileSDK-iOS"
  s.version      = "3.0.0"
  s.summary      = "Salesforce Mobile SDK for iOS"
  s.homepage     = "https://github.com/forcedotcom/SalesforceMobileSDK-iOS"

  s.license      = { :type => "Salesforce.com Mobile SDK License", :file => "LICENSE.md" }
  s.author             = { "Kevin Hawkins" => "khawkins@salesforce.com" }

  s.platform     = :ios, "6.0"

  s.source       = { :git => "https://github.com/forcedotcom/SalesforceMobileSDK-iOS.git",
                     :branch => "cocoapods",
                     :submodules => true }

  s.prepare_command = <<-CMD
      sed -i -e 's/#import \\"Categories\\//#import \\"/g' external/MKNetworkKit/MKNetworkKit/MKNetworkKit.h
  CMD

  s.subspec 'OpenSSL' do |openssl|

      openssl.preserve_paths = 'external/ThirdPartyDependencies/openssl/openssl/*.h', 'external/ThirdPartyDependencies/openssl/openssl_license.txt'
      openssl.vendored_libraries = 'external/ThirdPartyDependencies/openssl/libcrypto.a', 'external/ThirdPartyDependencies/openssl/libssl.a'
      # openssl.libraries = 'ssl', 'crypto'

  end

  s.subspec 'SQLCipher' do |sqlcipher|

      sqlcipher.preserve_paths = 'external/ThirdPartyDependencies/sqlcipher/LICENSE'
      sqlcipher.vendored_libraries = 'external/ThirdPartyDependencies/sqlcipher/libsqlcipher.a'
      # sqlcipher.libraries = 'sqlcipher'

  end

  s.subspec 'SalesforceCommonUtils' do |commonutils|

      commonutils.source_files = 'external/ThirdPartyDependencies/SalesforceCommonUtils/Headers/SalesforceCommonUtils/*.h'
      commonutils.public_header_files = 'external/ThirdPartyDependencies/SalesforceCommonUtils/Headers/SalesforceCommonUtils/*.h'
      commonutils.header_dir = 'Headers/SalesforceCommonUtils'
      commonutils.prefix_header_contents = '#import <SalesforceCommonUtils/SFLogger.h>'
      commonutils.vendored_libraries = 'external/ThirdPartyDependencies/SalesforceCommonUtils/libSalesforceCommonUtils.a'
      # commonutils.libraries = 'SalesforceCommonUtils'
      commonutils.frameworks = 'MessageUI'
      commonutils.libraries = 'z'
      commonutils.xcconfig = { 'HEADER_SEARCH_PATHS' => "${PODS_ROOT}/Headers/#{s.name}/Headers" }

  end

  s.subspec 'MKNetworkKit' do |mknet|

      mknet.source_files = 'external/MKNetworkKit/MKNetworkKit/**/*.{h,m}'
      mknet.public_header_files = 'external/MKNetworkKit/MKNetworkKit/Categories/NSDictionary+RequestEncoding.h', 'external/MKNetworkKit/MKNetworkKit/Categories/NSString+MKNetworkKitAdditions.h', 'external/MKNetworkKit/MKNetworkKit/Categories/UIAlertView+MKNetworkKitAdditions.h', 'external/MKNetworkKit/MKNetworkKit/MKNetworkEngine.h', 'external/MKNetworkKit/MKNetworkKit/MKNetworkKit.h', 'external/MKNetworkKit/MKNetworkKit/MKNetworkOperation.h'
      mknet.header_dir = 'Headers/MKNetworkKit-iOS'
      mknet.prefix_header_contents = '#import "MKNetworkKit.h"'
      mknet.xcconfig = { 'HEADER_SEARCH_PATHS' => "${PODS_ROOT}/Headers/#{s.name}/Headers" }
      mknet.requires_arc = true

  end

  s.subspec 'SalesforceSecurity' do |salesforcesecurity|

      salesforcesecurity.dependency 'SalesforceMobileSDK-iOS/SalesforceCommonUtils'
      salesforcesecurity.source_files = 'shared/SalesforceSecurity/SalesforceSecurity/Classes/*.{h,m}'
      salesforcesecurity.public_header_files = 'shared/SalesforceSecurity/SalesforceSecurity/Classes/SFPasscodeManager.h', 'shared/SalesforceSecurity/SalesforceSecurity/Classes/SFSDKCryptoUtils.h', 'shared/SalesforceSecurity/SalesforceSecurity/Classes/SFEncryptionKey.h', 'shared/SalesforceSecurity/SalesforceSecurity/Classes/SFPasscodeProviderManager.h', 'shared/SalesforceSecurity/SalesforceSecurity/Classes/SFKeyStoreKey.h', 'shared/SalesforceSecurity/SalesforceSecurity/Classes/SFKeyStoreManager.h', 'shared/SalesforceSecurity/SalesforceSecurity/Classes/SFPasscodeManager+Internal.h'
      salesforcesecurity.header_dir = 'Headers/SalesforceSecurity'
      salesforcesecurity.prefix_header_contents = '#import <SalesforceCommonUtils/SFLogger.h>'
      salesforcesecurity.xcconfig = { 'HEADER_SEARCH_PATHS' => "${PODS_ROOT}/Headers/#{s.name}/Headers" }
      salesforcesecurity.requires_arc = true

  end

  s.subspec 'SalesforceOAuth' do |oauth|

      oauth.dependency 'SalesforceMobileSDK-iOS/SalesforceCommonUtils'
      oauth.dependency 'SalesforceMobileSDK-iOS/SalesforceSecurity'
      oauth.source_files = 'shared/SalesforceOAuth/SalesforceOAuth/Classes/**/*.{h,m}'
      oauth.public_header_files = 'shared/SalesforceOAuth/SalesforceOAuth/Classes/SFOAuthCoordinator.h', 'shared/SalesforceOAuth/SalesforceOAuth/Classes/SFOAuthCredentials.h', 'shared/SalesforceOAuth/SalesforceOAuth/Classes/SFOAuthInfo.h'
      oauth.header_dir = 'Headers/SalesforceOAuth'
      oauth.prefix_header_contents = '#import <SalesforceCommonUtils/SFLogger.h>'
      oauth.xcconfig = { 'HEADER_SEARCH_PATHS' => "${PODS_ROOT}/Headers/#{s.name}/Headers" }
      oauth.requires_arc = true

  end

  s.subspec 'SalesforceSDKCore' do |sdkcore|

      sdkcore.dependency 'SalesforceMobileSDK-iOS/SalesforceCommonUtils'
      sdkcore.dependency 'SalesforceMobileSDK-iOS/SalesforceSecurity'
      sdkcore.dependency 'SalesforceMobileSDK-iOS/SalesforceOAuth'
      sdkcore.dependency 'SalesforceMobileSDK-iOS/OpenSSL'
      sdkcore.dependency 'SalesforceMobileSDK-iOS/SQLCipher'
      sdkcore.source_files = 'shared/SalesforceSDKCore/SalesforceSDKCore/Classes/**/*.{h,m}'
      sdkcore.public_header_files = 'shared/SalesforceSDKCore/SalesforceSDKCore/Classes/Fmdb/FMDatabase.h', 'shared/SalesforceSDKCore/SalesforceSDKCore/Classes/Fmdb/FMResultSet.h', 'shared/SalesforceSDKCore/SalesforceSDKCore/Classes/Util/NSURL+SFStringUtils.h', 'shared/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFAbstractPasscodeViewController.h', 'shared/SalesforceSDKCore/SalesforceSDKCore/Classes/Common/SFApplication.h', 'shared/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFAuthErrorHandler.h', 'shared/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFAuthErrorHandlerList.h', 'shared/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFAuthenticationManager+Internal.h', 'shared/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFAuthenticationManager.h', 'shared/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFAuthenticationViewHandler.h', 'shared/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFAuthorizingViewController.h', 'shared/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFCommunityData.h', 'shared/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFDefaultUserManagementViewController.h', 'shared/SalesforceSDKCore/SalesforceSDKCore/Classes/Util/SFDirectoryManager.h', 'shared/SalesforceSDKCore/SalesforceSDKCore/Classes/Identity/SFIdentityCoordinator.h', 'shared/SalesforceSDKCore/SalesforceSDKCore/Classes/Identity/SFIdentityData.h', 'shared/SalesforceSDKCore/SalesforceSDKCore/Classes/Util/SFJsonUtils.h', 'shared/SalesforceSDKCore/SalesforceSDKCore/Classes/Util/SFPreferences.h', 'shared/SalesforceSDKCore/SalesforceSDKCore/Classes/PushNotification/SFPushNotificationManager.h', 'shared/SalesforceSDKCore/SalesforceSDKCore/Classes/SmartStore/SFQuerySpec.h', 'shared/SalesforceSDKCore/SalesforceSDKCore/Classes/Util/SFSDKResourceUtils.h', 'shared/SalesforceSDKCore/SalesforceSDKCore/Classes/Test/SFSDKTestCredentialsData.h', 'shared/SalesforceSDKCore/SalesforceSDKCore/Classes/Test/SFSDKTestRequestListener.h', 'shared/SalesforceSDKCore/SalesforceSDKCore/Classes/Util/SFSDKWebUtils.h', 'shared/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFSecurityLockout.h', 'shared/SalesforceSDKCore/SalesforceSDKCore/Classes/SmartStore/SFSmartStore.h', 'shared/SalesforceSDKCore/SalesforceSDKCore/Classes/SmartStore/SFSmartStoreDatabaseManager.h', 'shared/SalesforceSDKCore/SalesforceSDKCore/Classes/SmartStore/SFSmartStoreInspectorViewController.h', 'shared/SalesforceSDKCore/SalesforceSDKCore/Classes/SmartStore/SFSoupIndex.h', 'shared/SalesforceSDKCore/SalesforceSDKCore/Classes/SmartStore/SFStoreCursor.h', 'shared/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFUserAccount.h', 'shared/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFUserAccountConstants.h', 'shared/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/SFUserAccountManager.h', 'shared/SalesforceSDKCore/SalesforceSDKCore/Classes/Common/SFUserActivityMonitor.h', 'shared/SalesforceSDKCore/SalesforceSDKCore/Classes/Common/SalesforceSDKConstants.h', 'shared/SalesforceSDKCore/SalesforceSDKCore/Classes/Test/TestSetupUtils.h'
      sdkcore.header_dir = 'Headers/SalesforceSDKCore'
      sdkcore.prefix_header_contents = '#import <SalesforceCommonUtils/SFLogger.h>', '#import "SalesforceSDKConstants.h"'
      sdkcore.xcconfig = { 'HEADER_SEARCH_PATHS' => "${PODS_ROOT}/Headers/#{s.name}/Headers" }
      sdkcore.requires_arc = true

  end

end
