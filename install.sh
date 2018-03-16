#!/bin/bash

# set -x

#
# Run this script before working with the SalesforceMobileSDK Xcode workspace.
#

# Check for iOS SDK minimum version
IOS_MIN_VERSION_NUM=100
IOS_MIN_VERSION_STR="iOS 10.0"
ios_ver=`xcodebuild -version -sdk iphoneos | grep SDKVersion:`
if [[ "$ios_ver" == "" ]]
then
    echo "Could not determine iOS SDK version.  Is xcodebuild on your path?"
    exit 1
fi
ios_ver_num=`echo $ios_ver | sed 's/SDKVersion: \([0-9][0-9]*\)\.\([0-9][0-9]*\).*$/\1\2/'`
ios_ver_str=`echo $ios_ver | sed 's/SDKVersion: //'`
if [[ $ios_ver_num -lt $IOS_MIN_VERSION_NUM ]]
then
    echo "Current configured iOS version ($ios_ver_str) is less than the minimum required version ($IOS_MIN_VERSION_STR)."
    exit 2
fi

# Check for Xcode minimum version
XCODE_MIN_VERSION=90
XCODE_MIN_VERSION_STR="Xcode 9.0"
xcode_ver=`xcodebuild -version | grep ^Xcode`
if [[ "$xcode_ver" == "" ]]
then
    echo "Could not determine Xcode version.  Is xcodebuild on your path?"
    exit 3
fi
xcode_ver_num=`echo $xcode_ver | sed 's/^Xcode \([0-9][0-9]*\)\.\([0-9][0-9]*\).*$/\1\2/'`
xcode_ver_str=`echo $xcode_ver | sed 's/^Xcode //'`
if [[ $xcode_ver_num -lt $XCODE_MIN_VERSION ]]
then
    echo "Current configured Xcode version ($xcode_ver_str) is less than the minimum required version ($XCODE_MIN_VERSION_STR)."
    exit 4
fi

# Sync submodules
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"
git submodule init
git submodule sync
git submodule update --init --recursive

# Get react native
pushd "libs/SalesforceReact"
rm -rf node_modules
npm install
popd


# Remove the old Xcode templates, if they still exist.
hybrid_template_dir="${HOME}/Library/Developer/Xcode/Templates/Project Templates/Application/Hybrid Force.com App.xctemplate"
native_template_dir="${HOME}/Library/Developer/Xcode/Templates/Project Templates/Application/Native Force.com REST App.xctemplate"
if [[ -d "${hybrid_template_dir}" ]]
then
    echo 'Removing old hybrid template from Xcode.'
    rm -rf "${hybrid_template_dir}"
fi
if [[ -d "${native_template_dir}" ]]
then
    echo 'Removing old native template from Xcode.'
    rm -rf "${native_template_dir}"
fi

# Create test_credentials.json to avoid build errors
cp shared/test/test_credentials.json.sample shared/test/test_credentials.json
