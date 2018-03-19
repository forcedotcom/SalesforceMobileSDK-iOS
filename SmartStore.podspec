Pod::Spec.new do |s|

  s.name         = "SmartStore"
  s.version      = "6.2.0"
  s.summary      = "Salesforce Mobile SDK for iOS - SmartStore"
  s.homepage     = "https://github.com/forcedotcom/SalesforceMobileSDK-iOS"

  s.license      = { :type => "Salesforce.com Mobile SDK License", :file => "LICENSE.md" }
  s.author       = { "Kevin Hawkins" => "khawkins@salesforce.com" }

  s.platform     = :ios, "10.0"

  s.source       = { :git => "https://github.com/forcedotcom/SalesforceMobileSDK-iOS.git",
                     :tag => "v#{s.version}",
                     :submodules => true }
  
  s.requires_arc = true
  s.default_subspec  = 'SmartStore'

  s.subspec 'SmartStore' do |smartstore|

      smartstore.dependency 'SalesforceSDKCore'
      smartstore.dependency 'FMDB/SQLCipher', '~> 2.7.2'
      smartstore.dependency 'SQLCipher/fts', '~> 3.4.1'
      smartstore.source_files = 'libs/SmartStore/SmartStore/Classes/**/*.{h,m}', 'libs/SmartStore/SmartStore/SmartStore.h'
      smartstore.public_header_files = 'libs/SmartStore/SmartStore/Classes/SFAlterSoupLongOperation.h', 'libs/SmartStore/SmartStore/Classes/SFQuerySpec.h', 'libs/SmartStore/SmartStore/Classes/SFSDKSmartStoreLogger.h', 'libs/SmartStore/SmartStore/Classes/SFSDKStoreConfig.h', 'libs/SmartStore/SmartStore/Classes/SFSmartSqlHelper.h', 'libs/SmartStore/SmartStore/Classes/SFSmartStore.h', 'libs/SmartStore/SmartStore/Classes/SFSmartStoreDatabaseManager.h', 'libs/SmartStore/SmartStore/Classes/SFSmartStoreInspectorViewController.h', 'libs/SmartStore/SmartStore/Classes/SFSmartStoreUpgrade.h', 'libs/SmartStore/SmartStore/Classes/SFSmartStoreUtils.h', 'libs/SmartStore/SmartStore/Classes/SFSoupIndex.h', 'libs/SmartStore/SmartStore/Classes/SFSoupSpec.h', 'libs/SmartStore/SmartStore/Classes/SFStoreCursor.h', 'libs/SmartStore/SmartStore/SmartStore.h', 'libs/SmartStore/SmartStore/Classes/SmartStoreSDKManager.h'
      smartstore.prefix_header_contents = '#import "SFSDKSmartStoreLogger.h"', '#import <SalesforceSDKCore/SalesforceSDKConstants.h>'
      smartstore.requires_arc = true

  end

end
