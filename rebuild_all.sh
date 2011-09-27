#!/bin/bash
# This script will recompile everything and update all the dependencies of all the projects.
# After running this script all the .a, .h in all the dependencies directory will be updated
# with the latest and greatest.

CURRENT_DIR=`pwd`

# first, clean everything
cd $CURRENT_DIR/json-framework/sfdc_build
ant clean
cd $CURRENT_DIR/RestKit/sfdc_build
ant clean
cd $CURRENT_DIR/native/SalesforceOAuth/sfdc_build
ant clean

# now clean libraries with dependencies
cd $CURRENT_DIR/native/SalesforceSDK/sfdc_build
ant clean.full
cd $CURRENT_DIR/native/SampleApps/RestAPIExplorer/sfdc_build
ant clean.full
cd $CURRENT_DIR/hybrid/SampleApps/ContactExplorer/sfdc_build
ant clean.full

# now rebuild everything, starting from the low level libraries
cd $CURRENT_DIR/json-framework/sfdc_build
ant
cd $CURRENT_DIR/RestKit/sfdc_build
ant
cd $CURRENT_DIR/native/SalesforceOAuth/sfdc_build
ant

# now build libraries with dependencies
cd $CURRENT_DIR/native/SalesforceSDK/sfdc_build
ant
cd $CURRENT_DIR/native/SampleApps/RestAPIExplorer/sfdc_build
ant
cd $CURRENT_DIR/hybrid/SampleApps/ContactExplorer/sfdc_build
ant
