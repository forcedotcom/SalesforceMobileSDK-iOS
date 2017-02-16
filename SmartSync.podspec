Pod::Spec.new do |s|

  s.name         = "SmartSync"
  s.version      = "5.0.1"
  s.summary      = "Salesforce Mobile SDK for iOS - SmartSync"
  s.homepage     = "https://github.com/forcedotcom/SalesforceMobileSDK-iOS"

  s.license      = { :type => "Salesforce.com Mobile SDK License", :file => "LICENSE.md" }
  s.author       = { "Kevin Hawkins" => "khawkins@salesforce.com" }

  s.platform     = :ios, "9.0"

  s.source       = { :git => "https://github.com/forcedotcom/SalesforceMobileSDK-iOS.git",
                     :tag => "v#{s.version}",
                     :submodules => true }
  
  s.requires_arc = true
  s.default_subspec  = 'SmartSync'

  s.subspec 'SmartSync' do |smartsync|

      smartsync.dependency 'SmartStore'
      smartsync.dependency 'SalesforceSDKCore'
      smartsync.source_files = 'libs/SmartSync/SmartSync/Classes/**/*.{h,m}', 'libs/SmartSync/SmartSync/SmartSync.h'
      smartsync.public_header_files = 'libs/SmartSync/SmartSync/Classes/Util/SFMruSyncDownTarget.h', 'libs/SmartSync/SmartSync/Classes/Model/SFObject.h', 'libs/SmartSync/SmartSync/Classes/Model/SFObjectType.h', 'libs/SmartSync/SmartSync/Classes/Model/SFObjectTypeLayout.h', 'libs/SmartSync/SmartSync/Classes/Util/SFRefreshSyncDownTarget.h', 'libs/SmartSync/SmartSync/Classes/Manager/SFSmartSyncCacheManager.h', 'libs/SmartSync/SmartSync/Classes/Util/SFSmartSyncConstants.h', 'libs/SmartSync/SmartSync/Classes/Manager/SFSmartSyncMetadataManager.h', 'libs/SmartSync/SmartSync/Classes/Util/SFSmartSyncNetworkUtils.h', 'libs/SmartSync/SmartSync/Classes/Util/SFSmartSyncObjectUtils.h', 'libs/SmartSync/SmartSync/Classes/Model/SFSmartSyncPersistableObject.h', 'libs/SmartSync/SmartSync/Classes/Util/SFSmartSyncSoqlBuilder.h', 'libs/SmartSync/SmartSync/Classes/Util/SFSmartSyncSoslBuilder.h', 'libs/SmartSync/SmartSync/Classes/Util/SFSmartSyncSoslReturningBuilder.h', 'libs/SmartSync/SmartSync/Classes/Manager/SFSmartSyncSyncManager.h', 'libs/SmartSync/SmartSync/Classes/Util/SFSoqlSyncDownTarget.h', 'libs/SmartSync/SmartSync/Classes/Util/SFSoslSyncDownTarget.h', 'libs/SmartSync/SmartSync/Classes/Util/SFSyncDownTarget.h', 'libs/SmartSync/SmartSync/Classes/Util/SFSyncOptions.h', 'libs/SmartSync/SmartSync/Classes/Util/SFSyncState.h', 'libs/SmartSync/SmartSync/Classes/Util/SFSyncTarget.h', 'libs/SmartSync/SmartSync/Classes/Util/SFSyncUpTarget.h', 'libs/SmartSync/SmartSync/SmartSync.h'
      smartsync.prefix_header_contents = '#import <SalesforceSDKCore/SFLogger.h>'
      smartsync.requires_arc = true

  end

end
