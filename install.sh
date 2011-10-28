#!/bin/bash
# Running this script will install all dependencies needed for all of the projects, 
# as well as generating the latest .h and template files.
# This assumes you have already setup submodules in the /external directory.

CURRENT_DIR=`pwd`

# first, clean libs
cd $CURRENT_DIR/external/json-framework/sfdc_build
ant clean
cd $CURRENT_DIR/external/RestKit/sfdc_build
ant clean
cd $CURRENT_DIR/external/callback-ios/sfdc_build
ant clean
cd $CURRENT_DIR/native/SalesforceOAuth/sfdc_build
ant clean

# clean libraries with dependencies
cd $CURRENT_DIR/native/SalesforceSDK/sfdc_build
ant clean.full
# clean sample apps
cd $CURRENT_DIR/native/SampleApps/RestAPIExplorer/sfdc_build
ant clean.full
cd $CURRENT_DIR/hybrid/SampleApps/ContactExplorer/sfdc_build
ant clean.full
cd $CURRENT_DIR/hybrid/SampleApps/VFConnector/sfdc_build
ant clean.full


# build external libraries we depend upon
cd $CURRENT_DIR/external/json-framework/sfdc_build
ant
cd $CURRENT_DIR/external/RestKit/sfdc_build
ant
cd $CURRENT_DIR/external/callback-ios/sfdc_build
ant 

# build salesforce libraries
cd $CURRENT_DIR/native/SalesforceOAuth/sfdc_build
ant

cd $CURRENT_DIR/native/SalesforceSDK/sfdc_build
ant install

# build sample apps with dependencies
cd $CURRENT_DIR/native/SampleApps/RestAPIExplorer/sfdc_build
ant
cd $CURRENT_DIR/hybrid/SampleApps/ContactExplorer/sfdc_build
ant
cd $CURRENT_DIR/hybrid/SampleApps/VFConnector/sfdc_build
ant

