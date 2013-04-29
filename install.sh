#!/bin/bash

#
# Run this script before working with the SalesforceMobileSDK Xcode workspace.
#

# Check for iOS SDK minimum version
IOS_MIN_VERSION_NUM=60
IOS_MIN_VERSION_STR="iOS 6.0"
ios_ver=`xcodebuild -version -sdk iphoneos | grep SDKVersion:`
if [[ "$ios_ver" == "" ]]
then
    echo "Could not determine iOS SDK version.  Is xcodebuild on your path?"
    exit 1
fi
ios_ver_num=`echo $ios_ver | sed 's/SDKVersion: \([0-9][0-9]*\)\.\([0-9][0-9]*\)/\1\2/'`
ios_ver_str=`echo $ios_ver | sed 's/SDKVersion: //'`
if [[ $ios_ver_num -lt $IOS_MIN_VERSION_NUM ]]
then
    echo "Current configured iOS version ($ios_ver_str) is less than the minimum required version ($IOS_MIN_VERSION_STR)."
    exit 2
fi

# Sync submodules
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"
git submodule init
git submodule sync
git submodule update 
