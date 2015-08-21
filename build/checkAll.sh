#!/usr/bin/ruby

require 'timeout'
require 'optparse'

# Constants
SCHEMES_TO_BUILD = [
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


SCHEMES_TO_TEST = [
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
  


# Helper methods
def printHeader(message)
  puts "---> #{message}"
end

def build(scheme, timeout) 
  printHeader("Building #{scheme}")
  exec_with_timeout("xcodebuild -workspace SalesforceMobileSDK.xcworkspace -scheme #{scheme} 2>&1 | grep '^\*\*\ BUILD'", timeout)
end

def test(scheme, timeout) 
  printHeader("Testing #{scheme}")
  exec_with_timeout("xcodebuild test -workspace SalesforceMobileSDK.xcworkspace -scheme #{scheme} -sdk iphonesimulator ONLY_ACTIVE_ARCH=NO 2>&1 | grep '^\t-' | sed 's/-/Failed\ /'", timeout)
end

def exec_with_timeout(command, timeout)
  pipe = IO.popen(command, 'r')
  output = ""
  begin
    status = Timeout::timeout(timeout) {
      Process.waitpid2(pipe.pid)
      print pipe.gets(nil)
    }
  rescue Timeout::Error
    Process.kill(15, pipe.pid)
    puts "** Killed - took to long"
  end
  pipe.close
end

# Build all schemes
def buildAll(timeout)
  for scheme in SCHEMES_TO_BUILD
    build(scheme, timeout)
  end
end

# Test all test schemes
def testAll(timeout)
  for scheme in SCHEMES_TO_TEST
    test(scheme, timeout)
  end
end

# Main method
def main(args)
  schemeToBuild = ""
  schemeToTest = ""
  timeout = 30
  
  parser = OptionParser.new do |opts|
    opts.banner = "Usage: ./build/checkAll.sh [options]"
    opts.on("-b", "--build scheme", "Build given scheme (pass all to build all the schemes)") do |scheme|
      schemeToBuild = scheme
    end

    opts.on("-t", "--test scheme", "Test given scheme (pass all to test all the schemes)") do |scheme|
      schemeToTest = scheme
    end

    opts.on("-m", "--max-time timeout", Integer, "Maximum time that build/test is allowed to run") do |maxtime|
      timeout = maxtime
    end
  end

  parser.parse(args)

  if (schemeToBuild != "") 
    if (schemeToBuild == "all")
      buildAll(timeout)
    else
      build(schemeToBuild, timeout)
    end
  end
    
  if (schemeToTest != "") 
    if (schemeToTest == "all")
      testAll(timeout)
    else
      test(schemeToTest, timeout)
    end
  end
end

#
main(ARGV)
