#!/bin/bash
# This script will recompile everything and update all the dependencies of all the projects.
# After running this script all the .a, .h in all the dependencies directory will be updated
# with the latest and greatest.

CURRENT_DIR=`pwd`

# first, clean libs
cd $CURRENT_DIR/external/json-framework/sfdc_build
ant clean
cd $CURRENT_DIR/external/RestKit/sfdc_build
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
cd $CURRENT_DIR/hybrid/SampleApps/VisualForceConnector/sfdc_build
ant clean.full


# build external libraries we depend upon
cd $CURRENT_DIR/external/json-framework/sfdc_build
ant
cd $CURRENT_DIR/external/RestKit/sfdc_build
ant

# build salesforce libraries
cd $CURRENT_DIR/native/SalesforceOAuth/sfdc_build
ant
cd $CURRENT_DIR/native/SampleApps/RestAPIExplorer/sfdc_build
ant

# build sample apps with dependencies
cd $CURRENT_DIR/native/SampleApps/RestAPIExplorer/sfdc_build
ant
cd $CURRENT_DIR/hybrid/SampleApps/ContactExplorer/sfdc_build
ant
cd $CURRENT_DIR/hybrid/SampleApps/VisualForceConnector/sfdc_build
ant

