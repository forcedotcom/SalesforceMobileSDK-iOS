#!/usr/bin/ruby

#
# Copyright (c) 2015, salesforce.com, inc. All rights reserved.
# 
# Redistribution and use of this software in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
# * Redistributions of source code must retain the above copyright notice, this list of conditions
# and the following disclaimer.
# * Redistributions in binary form must reproduce the above copyright notice, this list of
# conditions and the following disclaimer in the documentation and/or other materials provided
# with the distribution.
# * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
# endorse or promote products derived from this software without specific prior written
# permission of salesforce.com, inc.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
# FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
# WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
 

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
