#!/usr/bin/env ruby

# Warn when there is a big PR
warn("Big PR, try to keep changes smaller if you can.", sticky: true) if git.lines_of_code > 1000

# Redirect contributors to PR to dev.
fail("Please re-submit this PR to the dev branch, we may have already fixed your issue.", sticky: true) if github.branch_for_base != "dev"

# List of supported xcode schemes for testing
SCHEMES = ['SalesforceSDKCommon', 'SalesforceAnalytics', 'SalesforceSDKCore', 'SmartStore', 'MobileSync']

modifed_libs = Set[]

for file in (git.modified_files + git.added_files);
    scheme = file.split("libs/").last.split("/").first
    if SCHEMES.include?(scheme)
        modifed_libs.add(scheme)
    end
end

# Matrix must have at least one value; run SalesforceSDKCore when no libs are modified
modifed_libs.add(SCHEMES[2]) if modifed_libs.empty?

# Set Github Job output so we know which tests to run
json_libs = modifed_libs.map { |l| "'#{l}'"}.join(", ")
`echo "libs=[#{json_libs}]" >> $GITHUB_OUTPUT`

# Detect AuthFlowTester changes — if any, run the full UI suite instead of the fixed PR test
authflowtester_changed = (git.modified_files + git.added_files).any? { |f|
  f.start_with?("native/SampleApps/AuthFlowTester/")
}
`echo "run_all_ui_tests=#{authflowtester_changed}" >> $GITHUB_OUTPUT`