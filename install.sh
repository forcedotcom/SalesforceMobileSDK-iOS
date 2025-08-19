#!/bin/bash

# set -x

#
# Run this script before working with the SalesforceMobileSDK Xcode workspace.
#

# Check for iOS SDK minimum version
IOS_MIN_VERSION_NUM=170
IOS_MIN_VERSION_STR="iOS 17.0"
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
XCODE_MIN_VERSION=160
XCODE_MIN_VERSION_STR="Xcode 16.0"
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

# Create test_credentials.json if needed to avoid build errors
if [ ! -f "shared/test/test_credentials.json" ]
then
    cp shared/test/test_credentials.json.sample shared/test/test_credentials.json
fi
