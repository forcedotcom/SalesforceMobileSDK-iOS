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

  s.subspec 'OpenSSL' do |openssl|

      openssl.preserve_paths = 'external/ThirdPartyDependencies/openssl/openssl/*.h', 'external/ThirdPartyDependencies/openssl/openssl_license.txt'
      openssl.vendored_libraries = 'external/ThirdPartyDependencies/openssl/libcrypto.a', 'external/ThirdPartyDependencies/openssl/libssl.a'
      openssl.libraries = 'ssl', 'crypto'

  end

  s.subspec 'SQLCipher' do |sqlcipher|

      sqlcipher.preserve_paths = 'external/ThirdPartyDependencies/sqlcipher/LICENSE'
      sqlcipher.vendored_libraries = 'external/ThirdPartyDependencies/sqlcipher/libsqlcipher.a'
      sqlcipher.libraries = 'sqlcipher'

  end

  s.subspec 'SalesforceCommonUtils' do |commonutils|

      commonutils.preserve_paths = 'external/ThirdPartyDependencies/SalesforceCommonUtils/Headers/SalesforceCommonUtils/*.h'
      commonutils.vendored_libraries = 'external/ThirdPartyDependencies/SalesforceCommonUtils/libSalesforceCommonUtils.a'
      commonutils.libraries = 'SalesforceCommonUtils'
      commonutils.frameworks = 'MessageUI'
      commonutils.libraries = 'z'
      commonutils.xcconfig = { 'HEADER_SEARCH_PATHS' => "${PODS_ROOT}/#{s.name}/external/ThirdPartyDependencies/SalesforceCommonUtils/Headers" }

  end

end
