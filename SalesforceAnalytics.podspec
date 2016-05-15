Pod::Spec.new do |s|

  s.name         = "SalesforceAnalytics"
  s.version      = "4.2.0"
  s.summary      = "Salesforce Mobile SDK for iOS"
  s.homepage     = "https://github.com/forcedotcom/SalesforceMobileSDK-iOS"

  s.license      = { :type => "Salesforce.com Mobile SDK License", :file => "LICENSE.md" }
  s.author       = { "Bharath Hariharan" => "bhariharan@salesforce.com" }

  s.platform     = :ios, "8.0"

  s.source       = { :git => "https://github.com/forcedotcom/SalesforceMobileSDK-iOS.git",
                     :tag => "pod_v#{s.version}",
                     :submodules => true }
  
  s.requires_arc = true
  s.default_subspec  = 'SalesforceAnalytics'

  s.subspec 'SalesforceAnalytics' do |sdkanalytics|

      sdkanalytics.source_files = 'libs/SalesforceAnalytics/SalesforceAnalytics/Classes/**/*.{h,m}'
      sdkanalytics.public_header_files = 
      sdkanalytics.requires_arc = true

  end

end
