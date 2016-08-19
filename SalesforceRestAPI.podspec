Pod::Spec.new do |s|

  s.name         = "SalesforceRestAPI"
  s.version      = "4.3.0"
  s.summary      = "Salesforce Mobile SDK for iOS - SalesforceRestAPI"
  s.homepage     = "https://github.com/forcedotcom/SalesforceMobileSDK-iOS"

  s.license      = { :type => "Salesforce.com Mobile SDK License", :file => "LICENSE.md" }
  s.author       = { "Kevin Hawkins" => "khawkins@salesforce.com" }

  s.platform     = :ios, "8.0"

  s.source       = { :git => "https://github.com/forcedotcom/SalesforceMobileSDK-iOS.git",
                     :tag => "pod_v#{s.version}",
                     :submodules => true }
  
  s.requires_arc = true
  s.default_subspec  = 'SalesforceRestAPI'


  s.subspec 'SalesforceRestAPI' do |restapi|

      restapi.dependency 'SalesforceNetwork'
      restapi.dependency 'SalesforceSDKCore'
      restapi.source_files = 'libs/SalesforceRestAPI/SalesforceRestAPI/Classes/*.{h,m}', 'libs/SalesforceRestAPI/SalesforceRestAPI/SalesforceRestAPI.h'
      restapi.public_header_files = 'libs/SalesforceRestAPI/SalesforceRestAPI/Classes/SFRestAPI+Blocks.h', 'libs/SalesforceRestAPI/SalesforceRestAPI/Classes/SFRestAPI+Files.h', 'libs/SalesforceRestAPI/SalesforceRestAPI/Classes/SFRestAPI+QueryBuilder.h', 'libs/SalesforceRestAPI/SalesforceRestAPI/Classes/SFRestAPI.h', 'libs/SalesforceRestAPI/SalesforceRestAPI/Classes/SFRestAPISalesforceAction.h', 'libs/SalesforceRestAPI/SalesforceRestAPI/Classes/SFRestRequest.h', 'libs/SalesforceRestAPI/SalesforceRestAPI/SalesforceRestAPI.h'
      restapi.prefix_header_contents = '#import <SalesforceSDKCore/SFLogger.h>'
      restapi.requires_arc = true

  end

end
