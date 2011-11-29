#!/bin/bash
# Running this script will install all dependencies needed for all of the projects, 
# as well as generating the latest .h and template files.

# ensure that we have the correct version of all submodules
git submodule init
git submodule update

CURRENT_DIR=`pwd`


# keep anything existing in /dist

# clean our xcode templates for reinstallation
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


# build salesforce libraries and install templates
cd $CURRENT_DIR/hybrid/sfdc_build
ant install

cd $CURRENT_DIR/native/sfdc_build
ant install

# build sample apps with dependencies
cd $CURRENT_DIR/native/SampleApps/RestAPIExplorer/sfdc_build
ant
cd $CURRENT_DIR/hybrid/SampleApps/ContactExplorer/sfdc_build
ant
cd $CURRENT_DIR/hybrid/SampleApps/VFConnector/sfdc_build
ant

