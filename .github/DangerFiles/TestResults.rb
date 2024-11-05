xcode_summary.ignores_warnings = true
xcode_summary.inline_mode = true

if File.exist?('../../test.xcresult')
    xcode_summary.report '../../test.xcresult'
else
    fail "No test results found."
end