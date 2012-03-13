#!/bin/bash
# The goal here is to clean all binaries
# and to rebuild the main SDK binaries and dependencies

CURRENT_DIR=`pwd`


echo "Clean OAuth library..."
cd $CURRENT_DIR/native/SalesforceOAuth/sfdc_build
ant clean

echo "Clean external libs..."
cd $CURRENT_DIR/external/RestKit/sfdc_build
ant clean
cd $CURRENT_DIR/external/callback-ios/sfdc_build
ant clean

echo "Clean Native and Hybrid SDK..."
cd $CURRENT_DIR/hybrid/sfdc_build
ant clean.full
cd $CURRENT_DIR/native/sfdc_build
ant clean.full

echo "Clean sample apps..."
cd $CURRENT_DIR/native/SampleApps/RestAPIExplorer/sfdc_build
ant clean
cd $CURRENT_DIR/hybrid/SampleApps/ContactExplorer/sfdc_build
ant clean
cd $CURRENT_DIR/hybrid/SampleApps/VFConnector/sfdc_build
ant clean

echo "Rebuilding OAuth library..."
cd $CURRENT_DIR/native/SalesforceOAuth/sfdc_build
ant clean all

echo "Rebuilding SalesforceSDK..."
cd $CURRENT_DIR/native/SalesforceSDK/sfdc_build
ant clean buildDist

echo "Building and installing Hybrid SDK..."
cd $CURRENT_DIR/hybrid/sfdc_build
ant install

echo "Building and installing Native SDK..."
cd $CURRENT_DIR/native/sfdc_build
ant install

# build sample apps with dependencies
echo "Building sample apps with dependencies..."
cd $CURRENT_DIR/native/SampleApps/RestAPIExplorer/sfdc_build
ant
cd $CURRENT_DIR/hybrid/SampleApps/ContactExplorer/sfdc_build
ant
cd $CURRENT_DIR/hybrid/SampleApps/VFConnector/sfdc_build
ant
