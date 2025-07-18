Pod::Spec.new do |s|

  s.name         = "SmartStore"
  s.version      = "12.2.0"
  s.summary      = "Salesforce Mobile SDK for iOS - SmartStore"
  s.homepage     = "https://github.com/forcedotcom/SalesforceMobileSDK-iOS"

  s.license      = { :type => "Salesforce.com Mobile SDK License", :file => "LICENSE.md" }
  s.author       = { "Kevin Hawkins" => "khawkins@salesforce.com" }

  s.platforms    =  { :ios => "16.0", :visionos => "2.0" }
  s.swift_versions = ['5.0']

  s.source       = { :git => "https://github.com/forcedotcom/SalesforceMobileSDK-iOS.git",
                     :tag => "v#{s.version}" }
  
  s.requires_arc = true
  s.default_subspec  = 'SmartStore'

  s.subspec 'SmartStore' do |smartstore|

      smartstore.dependency 'SalesforceSDKCore', "~>#{s.version}"
      smartstore.dependency 'FMDB/SQLCipher', '~> 2.7.12'
      smartstore.dependency 'SQLCipher', '~> 4.6.1'
      smartstore.source_files = 'libs/SmartStore/SmartStore/Classes/**/*.{h,m,swift}', 'libs/SmartStore/SmartStore/SmartStore.h'
      smartstore.public_header_files = 'libs/SmartStore/SmartStore/Classes/SFAlterSoupLongOperation.h', 'libs/SmartStore/SmartStore/Classes/SFQuerySpec.h', 'libs/SmartStore/SmartStore/Classes/SFSDKSmartStoreLogger.h', 'libs/SmartStore/SmartStore/Classes/SFSDKStoreConfig.h', 'libs/SmartStore/SmartStore/Classes/SFSmartSqlHelper.h', 'libs/SmartStore/SmartStore/Classes/SFSmartStore.h', 'libs/SmartStore/SmartStore/Classes/SFSmartStoreDatabaseManager.h', 'libs/SmartStore/SmartStore/Classes/SFSmartStoreInspectorViewController.h', 'libs/SmartStore/SmartStore/Classes/SFSmartStoreUtils.h', 'libs/SmartStore/SmartStore/Classes/SFSoupIndex.h', 'libs/SmartStore/SmartStore/Classes/SFStoreCursor.h', 'libs/SmartStore/SmartStore/SmartStore.h', 'libs/SmartStore/SmartStore/Classes/SmartStoreSDKManager.h'
      smartstore.prefix_header_contents = '#import "SFSDKSmartStoreLogger.h"', '#import <SalesforceSDKCore/SalesforceSDKConstants.h>'
      smartstore.resource_bundles = { 'SmartStore' => [ 'libs/Smartstore/Smartstore/PrivacyInfo.xcprivacy' ] }
      smartstore.requires_arc = true

  end

end
