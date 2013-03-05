#!/bin/bash
# Running this script will install all dependencies needed for all of the projects, 
# as well as generating the latest .h and template files.

XCODE_MIN_VERSION=4.5

xcodebuild_version=`xcodebuild -version 2>&1`
if [ $? -ne 0 ]
then
    echo "The following error occurred while trying to determine your Xcode version:"
    echo "$xcodebuild_version"
    exit 2
fi

# The minimum Xcode version above is a requirement to build.
xcode_version_number=`echo "$xcodebuild_version" | grep 'Xcode' | sed 's/Xcode \([0-9][0-9]*\.[0-9][0-9]*\).*/\1/'`
has_minimum_version=`echo $xcode_version_number $XCODE_MIN_VERSION | awk '{ if ($1 < $2) print 0 ; else print 1 }'`
if [ $has_minimum_version -ne 1 ]
then
    echo "Xcode $XCODE_MIN_VERSION or greater is a prerequisite to build the iOS SDK."
    echo "Current installed version: $xcodebuild_version"
    exit 1
fi

echo "Ensuring that we have the correct version of all submodules..."
git submodule init
git submodule sync
git submodule update

CURRENT_DIR=`pwd`


# keep anything existing in /dist

echo "Cleaning Native and Hybrid app templates..."
cd "$CURRENT_DIR/hybrid/sfdc_build"
ant clean
cd "$CURRENT_DIR/native/sfdc_build"
ant clean

# build salesforce libraries and install templates
echo "Building and installing Hybrid app template..."
cd "$CURRENT_DIR/hybrid/sfdc_build"
ant install

echo "Building and installing Native app template..."
cd "$CURRENT_DIR/native/sfdc_build"
ant install

echo "Cleaning sample apps..."
cd "$CURRENT_DIR/native/SampleApps/RestAPIExplorer/sfdc_build"
ant clean
cd "$CURRENT_DIR/hybrid/SampleApps/ContactExplorer/sfdc_build"
ant clean
cd "$CURRENT_DIR/hybrid/SampleApps/VFConnector/sfdc_build"
ant clean

# build sample apps with dependencies
echo "Building sample apps..."
cd "$CURRENT_DIR/native/SampleApps/RestAPIExplorer/sfdc_build"
ant
cd "$CURRENT_DIR/hybrid/SampleApps/ContactExplorer/sfdc_build"
ant
cd "$CURRENT_DIR/hybrid/SampleApps/VFConnector/sfdc_build"
ant

