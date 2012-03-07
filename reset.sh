#!/bin/bash
# The goal here is to clean all binaries so that they will be rebuilt

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


echo "Building and installing Hybrid SDK..."
cd $CURRENT_DIR/hybrid/sfdc_build
ant install

echo "Building and installing Native SDK..."
cd $CURRENT_DIR/native/sfdc_build
ant install

