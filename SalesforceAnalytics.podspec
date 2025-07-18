Pod::Spec.new do |s|

  s.name         = "SalesforceAnalytics"
  s.version      = "12.2.0"
  s.summary      = "Salesforce Mobile SDK for iOS"
  s.homepage     = "https://github.com/forcedotcom/SalesforceMobileSDK-iOS"

  s.license      = { :type => "Salesforce.com Mobile SDK License", :file => "LICENSE.md" }
  s.author       = { "Bharath Hariharan" => "bhariharan@salesforce.com" }

  s.platforms    =  { :ios => "16.0", :visionos => "2.0" }

  s.source       = { :git => "https://github.com/forcedotcom/SalesforceMobileSDK-iOS.git",
                     :tag => "v#{s.version}" }

  s.xcconfig = { 'OTHER_LDFLAGS[sdk=iphoneos*]' => '$(inherited) -framework "CoreTelephony"',
                 'OTHER_LDFLAGS[sdk=iphonesimulator*]' => '$(inherited) -framework "CoreTelephony"' }

  s.requires_arc = true
  s.default_subspec  = 'SalesforceAnalytics'

  s.subspec 'SalesforceAnalytics' do |sdkanalytics|

      sdkanalytics.dependency 'SalesforceSDKCommon', "~>#{s.version}"
      sdkanalytics.source_files = 'libs/SalesforceAnalytics/SalesforceAnalytics/Classes/**/*.{h,m}', 'libs/SalesforceAnalytics/SalesforceAnalytics/SalesforceAnalytics.h'
      sdkanalytics.public_header_files = 'libs/SalesforceAnalytics/SalesforceAnalytics/Classes/Transform/SFSDKAILTNTransform.h', 'libs/SalesforceAnalytics/SalesforceAnalytics/Classes/Util/SFSDKAnalyticsLogger.h', 'libs/SalesforceAnalytics/SalesforceAnalytics/Classes/Manager/SFSDKAnalyticsManager.h', 'libs/SalesforceAnalytics/SalesforceAnalytics/Classes/Model/SFSDKDeviceAppAttributes.h', 'libs/SalesforceAnalytics/SalesforceAnalytics/Classes/Store/SFSDKEventStoreManager.h', 'libs/SalesforceAnalytics/SalesforceAnalytics/Classes/Model/SFSDKInstrumentationEvent.h', 'libs/SalesforceAnalytics/SalesforceAnalytics/Classes/Model/SFSDKInstrumentationEventBuilder.h', 'libs/SalesforceAnalytics/SalesforceAnalytics/Classes/Transform/SFSDKTransform.h', 'libs/SalesforceAnalytics/SalesforceAnalytics/SalesforceAnalytics.h'
      sdkanalytics.prefix_header_contents = '#import "SFSDKAnalyticsLogger.h"'
      sdkanalytics.resource_bundles = { 'SalesforceAnalytics' => [ 'libs/SalesforceAnalytics/SalesforceAnalytics/PrivacyInfo.xcprivacy' ] }
      sdkanalytics.requires_arc = true

  end

end
