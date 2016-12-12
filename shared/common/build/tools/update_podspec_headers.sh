#!/bin/bash

# Copyright (c) 2015-present, salesforce.com, inc. All rights reserved.
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
# Script to update the podspec with the latest public header files.  Meant to be run as a post-build
# script in the Xcode projects.
#

# set -x
set -e

SUBSPEC_NAME=""

function usage()
{
	local appName=`basename $0`
	echo "Usage:"
	echo "$appName -s <Subspec Name>"
}

function parseOpts()
{
	while getopts :s: commandLineOpt; do
		case ${commandLineOpt} in
			s)
			    SUBSPEC_NAME=${OPTARG};;
			?)
			    echo "Unknown option '-${OPTARG}'."
			    usage
			    exit 1
		esac
	done

	# Validate that we got the required command line arg(s).
	if [ "${SUBSPEC_NAME}" == "" ]; then
		echo "No option specified for Subspec Name."
		usage
		exit 2
	fi
}

parseOpts "$@"

repoDir=$(cd "$(dirname ${BASH_SOURCE[0]})" && cd ../../../.. && pwd)
publicHeaderDirectory="${TARGET_BUILD_DIR}/${PUBLIC_HEADERS_FOLDER_PATH}"
podSpecFile="${repoDir}/${PROJECT_NAME}.podspec"
projectDir=`echo "${PROJECT_DIR}" | sed "s#${repoDir}/##g"`

cd "$repoDir"

# Create the public header file list out of the public headers in the build folder.
publicHeaderFileList=""
isFirstFile=1
for headerFile in `ls -1 "${publicHeaderDirectory}"`; do
	repoHeaderFile=`find ${projectDir} -name $headerFile`
	if [ "$repoHeaderFile" != "" ]; then
		if [ $isFirstFile -eq 1 ]; then
			publicHeaderFileList="'$repoHeaderFile'"
			isFirstFile=0
		else
			publicHeaderFileList=`echo "${publicHeaderFileList}, '$repoHeaderFile'"`
		fi
	fi
done

# Make sure none of the public header files are in the exclude files list
if grep -q "${SUBSPEC_NAME}.exclude_files" ${podSpecFile}
then
    echo "${publicHeaderFileList}" | sed 's/ *//g' | tr , '\n' | sort > "${podSpecFile}.public_header_files_list"
    cat "${podSpecFile}" | grep "${SUBSPEC_NAME}.exclude_files"  | sed 's/.*=//' | sed 's/ *//g' | tr , '\n' | sort > "${podSpecFile}.exclude_files_list"
    publicHeaderFileList=`comm -23 ${podSpecFile}.public_header_files_list ${podSpecFile}.exclude_files_list | tr '\n' , | sed 's/,$//'`
    rm "${podSpecFile}.public_header_files_list" "${podSpecFile}.exclude_files_list"
fi

# Replace the old headers with the new ones.
searchPattern='^( *'"${SUBSPEC_NAME}"'\.public_header_files = ).*$'
replacementPattern='\1'"${publicHeaderFileList}"
sed -E "s#$searchPattern#$replacementPattern#g" "$podSpecFile" > "${podSpecFile}.new"
mv "${podSpecFile}.new" "${podSpecFile}"
