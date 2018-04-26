gem 'plist'
require 'plist'

# Markdown table character length without any issues
MAKRDOWN_LENGTH = 138

test_results = 'test_output/report.junit'
if File.file?(test_results)
  junit.parse test_results
  junit.show_skipped_tests = true
  junit.report
end

message = "### Clang Static Analysis Issues\n\n"
message << "File | Type | Category | Description | Line | Col |\n"
message << " --- | ---- | -------- | ----------- | ---- | --- |\n"

# Parse Clang Plist files and report issues associated with files modified in this PR.
clang_libs = Dir['clangReport/StaticAnalyzer/*'].map { | x | x.split('/').last }
for lib in clang_libs;
  files = Dir["clangReport/StaticAnalyzer/#{lib}/#{lib}/normal/x86_64/*.plist"].map { | x | x.split('/').last }
  for file in files;
    report = Plist.parse_xml("clangReport/StaticAnalyzer/#{lib}/#{lib}/normal/x86_64/#{file}")
    absolute_file_path = report['files'][0]
    unless absolute_file_path.nil?
      file_path = (ENV.has_key?('JENKINS_HOME')) ? absolute_file_path.split('SalesforceMobileSDK-iOS-PR/').last : absolute_file_path.split('SalesforceMobileSDK-iOS/').last
      if git.modified_files.include?(file_path) || git.added_files.include?(file_path)
        issues = report['diagnostics']
        for i in 0..issues.count-1
          unless issues[i].nil?
            message << "#{file_path.split('/').last} | #{issues[i]['type']} | #{issues[i]['category']} | #{issues[i]['description']} | #{issues[i]['location']['line']} | #{issues[i]['location']['col']}\n"
          end
        end
      end
    end
  end
end

# Only print Static Analysis table if there are issues
if message.length > MAKRDOWN_LENGTH
  warn('Static Analysis found an issue with one or more files you modified.  Please fix the issue(s).')
  markdown message
end

# State what Library the test failures are for (or don't post at all).
markdown "# Tests results for #{ENV['LIB']}" unless status_report[:errors].empty? && status_report[:warnings].empty?