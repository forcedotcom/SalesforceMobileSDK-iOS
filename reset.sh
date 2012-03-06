#!/bin/bash
# The goal here is to reset the mobile SDK to the pre-install state,
# to the extent possible

CURRENT_DIR=`pwd`

# clean external libs
cd $CURRENT_DIR/external/RestKit/sfdc_build
ant clean
cd $CURRENT_DIR/external/callback-ios/sfdc_build
ant clean

#preserve dist

# clean xcode templates etc
cd $CURRENT_DIR/hybrid/sfdc_build
ant clean
cd $CURRENT_DIR/native/sfdc_build
ant clean

# clean sample apps
cd $CURRENT_DIR/native/SampleApps/RestAPIExplorer/sfdc_build
ant clean
cd $CURRENT_DIR/hybrid/SampleApps/ContactExplorer/sfdc_build
ant clean
cd $CURRENT_DIR/hybrid/SampleApps/VFConnector/sfdc_build
ant clean