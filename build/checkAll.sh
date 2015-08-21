#!/usr/bin/ruby

require 'timeout'

def printHeader(message)
  puts "---> #{message}"
end

def build(scheme) 
  printHeader("Building #{scheme}")
  exec_with_timeout("xcodebuild -workspace SalesforceMobileSDK.xcworkspace -scheme #{scheme} 2>&1 | grep '^\*\*\ BUILD'", 20)
end

def test(scheme) 
  printHeader("Testing #{scheme}")
  exec_with_timeout("xcodebuild test -workspace SalesforceMobileSDK.xcworkspace -scheme #{scheme} -sdk iphonesimulator ONLY_ACTIVE_ARCH=NO 2>&1 | grep '^\t-' | sed 's/-/Failed\ /'", 20)
end

def exec_with_timeout(command, timeout)
  pipe = IO.popen(command, 'r')
  output = ""
  begin
    status = Timeout::timeout(timeout) {
      Process.waitpid2(pipe.pid)
      output = pipe.gets(nil)
    }
  rescue Timeout::Error
    Process.kill(15, pipe.pid)
  end
  pipe.close
  print output
end

def buildAll()
  schemesToBuild = [
    "OCMock",
    "OCMockLib",
    "React",
    "AccountEditor",
    "ContactExplorer",
    "FileExplorer",
    "HybridFileExplorer",
    "NativeSqlAggregator",
    "NoteSync",
    "RestAPIExplorer",
    "SalesforceHybridSDK",
    "SalesforceNetworkiOS",    
    "SalesforceOAuth",
    "SalesforceReact",
    "SalesforceRestAPI",
    "SalesforceSDKCommon",
    "SalesforceSDKCore",
    "SalesforceSecurity",
    "SimpleSync",
    "SmartStoreExplorer",
    "SmartSync",
    "SmartSyncExplorer",
    "UserList",
    "VFConnector"
  ];
  
  for scheme in schemesToBuild
    build(scheme)
  end
end

def testAll()
  schemesToTest = [
    "HybridPluginTestApp",
    "OCMockLib", 
    "SalesforceNetworkiOS",
    "SalesforceOAuthTest",
    "SalesforceRestAPIUnitTestApp",
    "SalesforceSDKCommon",
    "SalesforceSDKCoreUnitTestApp",
    "SalesforceSecurity",
    "SmartSync", 
  ];
  
  for scheme in schemesToTest
    test(scheme)
  end
end

def main()
  buildAll()
  testAll()
end

#
main()
