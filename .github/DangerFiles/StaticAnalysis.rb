#!/usr/bin/env ruby

require 'plist'

# Markdown table character length without any issues
MAKRDOWN_LENGTH = 138
LIBS = ['SalesforceSDKCommon', 'SalesforceAnalytics', 'SalesforceSDKCore', 'SmartStore', 'MobileSync']

files = Set[]
for lib in LIBS;
    files.merge(Dir["libs/#{lib}/clangReport/StaticAnalyzer/#{lib}/#{lib}/normal/**/*.plist"])
end
print "Found #{files.count} classes with static analysis files.\n"

modified_file_names = git.modified_files.map { |file| File.basename(file, File.extname(file)) }
added_file_names = git.added_files.map { |file| File.basename(file, File.extname(file)) }

# Github PR comment header
message = "### Clang Static Analysis Issues\n\n"
message << "File | Type | Category | Description | Line | Col |\n"
message << " --- | ---- | -------- | ----------- | ---- | --- |\n"

# Parse Clang Plist files and report issues associated with files modified or added in this PR.
for file in files;
    report = Plist.parse_xml(file)
    report_file_name = File.basename(file, File.extname(file))
    print "File with clang report: #{report_file_name}\n"

    if modified_file_names.include?(report_file_name) || added_file_names.include?(report_file_name)
        issues = report['diagnostics']
        print "File modified in PR: #{file}, has #{issues.count} issues.\n"
        for i in 0..issues.count-1
            unless issues[i].nil?
                message << "#{report_file_name} | #{issues[i]['type']} | #{issues[i]['category']} | #{issues[i]['description']} | #{issues[i]['location']['line']} | #{issues[i]['location']['col']}\n"
            end
        end
    end
end

# Only print Static Analysis table if there are issues
if message.length > MAKRDOWN_LENGTH
  warn('Static Analysis found an issue with one or more files you modified.  Please fix the issue(s).')
  markdown message
end