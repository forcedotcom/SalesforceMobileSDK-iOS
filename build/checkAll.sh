#!/usr/bin/ruby


schemesToBuild = ["SalesforceSDKCommon", "SalesforceSecurity", "SalesforceOAuth", "SalesforceSDKCore", "SalesforceNetworkiOS", "SalesforceRestAPI", "SmartSync", "SalesforceHybridSDK"];
schemesToTest = [ "SalesforceSDKCommon", "SalesforceSecurity", "SalesforceOAuthTest", "SalesforceSDKCoreUnitTestApp", "SalesforceNetworkiOS", "SalesforceRestAPIUnitTestApp", "SmartSync", "SalesforceHybridSDK", "OCMockLib", "HybridPluginTestApp", "SalesforceNetworkiOSTests"];

for scheme in schemesToBuild
  puts "\n***********************************\nBuilding #{scheme}\n***********************************"
  system "xcodebuild -workspace SalesforceMobileSDK.xcworkspace -scheme #{scheme} > /dev/null" 
end

for scheme in schemesToTest
  puts "\n***********************************\nTesting #{scheme}\n***********************************"
  system "xcodebuild test -workspace SalesforceMobileSDK.xcworkspace -scheme #{scheme} -sdk iphonesimulator ONLY_ACTIVE_ARCH=NO | grep Executed"
end

