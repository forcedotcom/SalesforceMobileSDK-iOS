#!/bin/bash
# Running this script will rebuild main Salesforce Mobile SDK components
# as well as generating the latest .h and template files.
# This assumes that install.sh has already been run at least once.


CURRENT_DIR=`pwd`

# we intentionally do NOT clean libs as it's assumed these do not change

# preserve RestKit
# preserve callback-ios (phonegap)
# preserve SalesforceOAuth

# clean SDK components with dependencies
cd $CURRENT_DIR/native/SalesforceSDK/sfdc_build
ant clean

cd $CURRENT_DIR/hybrid/sfdc_build
ant clean

# clean sample apps with a known dependency on SDK
cd $CURRENT_DIR/native/SampleApps/RestAPIExplorer/sfdc_build
ant clean
cd $CURRENT_DIR/hybrid/SampleApps/ContactExplorer/sfdc_build
ant clean
cd $CURRENT_DIR/hybrid/SampleApps/VFConnector/sfdc_build
ant clean


# build SDK components

cd $CURRENT_DIR/native/SalesforceSDK/sfdc_build
ant build
 
cd $CURRENT_DIR/hybrid/sfdc_build
ant build

# build sample apps with dependencies
cd $CURRENT_DIR/native/SampleApps/RestAPIExplorer/sfdc_build
ant
cd $CURRENT_DIR/hybrid/SampleApps/ContactExplorer/sfdc_build
ant
cd $CURRENT_DIR/hybrid/SampleApps/VFConnector/sfdc_build
ant

