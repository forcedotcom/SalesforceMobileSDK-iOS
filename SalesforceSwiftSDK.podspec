Pod::Spec.new do |s|

  s.name         = "SalesforceSwiftSDK"
  s.version      = "6.2.0"
  s.summary      = "Salesforce Mobile SDK for iOS - Swift"
  s.homepage     = "https://github.com/forcedotcom/SalesforceMobileSDK-iOS"

  s.license      = { :type => "Salesforce.com Mobile SDK License", :file => "LICENSE.md" }
  s.author       = { "Raj Rao" => "rao.r@salesforce.com" }

  s.platform     = :ios, "10.0"

  s.source       = { :git => "https://github.com/forcedotcom/SalesforceMobileSDK-iOS.git",
                     :tag => "v#{s.version}",
                     :submodules => true }

  s.requires_arc = true
  s.default_subspec  = 'SalesforceSwiftSDK'

  s.subspec 'SalesforceSwiftSDK' do |salesforceswift|

      salesforceswift.dependency 'SmartSync'
      salesforceswift.dependency 'SmartStore'
      salesforceswift.dependency 'SalesforceSDKCore'
      salesforceswift.dependency 'SalesforceAnalytics'
      salesforceswift.dependency 'PromiseKit', '~> 5.0'
      salesforceswift.source_files = 'libs/SalesforceSwiftSDK/SalesforceSwiftSDK/**/*.{h,m,swift}'
      salesforceswift.requires_arc = true

  end

end
