Pod::Spec.new do |s|

  s.name         = "MobileSync"
  s.version      = "11.1.0"
  s.summary      = "Salesforce Mobile SDK for iOS - MobileSync"
  s.homepage     = "https://github.com/forcedotcom/SalesforceMobileSDK-iOS"

  s.license      = { :type => "Salesforce.com Mobile SDK License", :file => "LICENSE.md" }
  s.author       = { "Kevin Hawkins" => "khawkins@salesforce.com" }

  s.platform     = :ios, "15.0"
  s.swift_versions = ['5.0']

  s.source       = { :git => "https://github.com/forcedotcom/SalesforceMobileSDK-iOS.git",
                     :tag => "v#{s.version}" }
  
  s.requires_arc = true
  s.default_subspec  = 'MobileSync'

  s.subspec 'MobileSync' do |mobilesync|

      mobilesync.dependency 'SmartStore', "~>#{s.version}"
      mobilesync.source_files = 'libs/MobileSync/MobileSync/Classes/**/*.{h,m,swift}', 'libs/MobileSync/MobileSync/MobileSync.h'
      mobilesync.public_header_files = 'libs/MobileSync/MobileSync/MobileSync.h', 'libs/MobileSync/MobileSync/Classes/Manager/MobileSyncSDKManager.h', 'libs/MobileSync/MobileSync/Classes/Target/SFAdvancedSyncUpTarget.h', 'libs/MobileSync/MobileSync/Classes/Target/SFBatchSyncUpTarget.h', 'libs/MobileSync/MobileSync/Classes/Util/SFChildrenInfo.h', 'libs/MobileSync/MobileSync/Classes/Model/SFLayout.h', 'libs/MobileSync/MobileSync/Classes/Target/SFLayoutSyncDownTarget.h', 'libs/MobileSync/MobileSync/Classes/Manager/SFLayoutSyncManager.h', 'libs/MobileSync/MobileSync/Classes/Model/SFMetadata.h', 'libs/MobileSync/MobileSync/Classes/Target/SFMetadataSyncDownTarget.h', 'libs/MobileSync/MobileSync/Classes/Manager/SFMetadataSyncManager.h', 'libs/MobileSync/MobileSync/Classes/Util/SFMobileSyncConstants.h', 'libs/MobileSync/MobileSync/Classes/Util/SFMobileSyncNetworkUtils.h', 'libs/MobileSync/MobileSync/Classes/Util/SFMobileSyncObjectUtils.h', 'libs/MobileSync/MobileSync/Classes/Model/SFMobileSyncPersistableObject.h', 'libs/MobileSync/MobileSync/Classes/Instrumentation/SFMobileSyncSyncManager+Instrumentation.h', 'libs/MobileSync/MobileSync/Classes/Manager/SFMobileSyncSyncManager.h', 'libs/MobileSync/MobileSync/Classes/Target/SFMruSyncDownTarget.h', 'libs/MobileSync/MobileSync/Classes/Model/SFObject.h', 'libs/MobileSync/MobileSync/Classes/Target/SFParentChildrenSyncDownTarget.h', 'libs/MobileSync/MobileSync/Classes/Util/SFParentChildrenSyncHelper.h', 'libs/MobileSync/MobileSync/Classes/Target/SFParentChildrenSyncUpTarget.h', 'libs/MobileSync/MobileSync/Classes/Util/SFParentInfo.h', 'libs/MobileSync/MobileSync/Classes/Target/SFRefreshSyncDownTarget.h', 'libs/MobileSync/MobileSync/Classes/Util/SFSDKMobileSyncLogger.h', 'libs/MobileSync/MobileSync/Classes/Config/SFSDKSyncsConfig.h', 'libs/MobileSync/MobileSync/Classes/Target/SFSoqlSyncDownTarget.h', 'libs/MobileSync/MobileSync/Classes/Target/SFSoslSyncDownTarget.h', 'libs/MobileSync/MobileSync/Classes/Target/SFSyncDownTarget.h', 'libs/MobileSync/MobileSync/Classes/Util/SFSyncOptions.h', 'libs/MobileSync/MobileSync/Classes/Util/SFSyncState.h', 'libs/MobileSync/MobileSync/Classes/Target/SFSyncTarget.h', 'libs/MobileSync/MobileSync/Classes/Target/SFSyncUpTarget.h'
      mobilesync.prefix_header_contents = '#import "SFSDKMobileSyncLogger.h"'
      mobilesync.resource = 'libs/MobileSync/MobileSync/PrivacyInfo.xcprivacy'
      mobilesync.requires_arc = true

  end

end
