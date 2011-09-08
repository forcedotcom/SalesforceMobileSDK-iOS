#!/bin/bash
# This script copies the oauth files from p4 into our git repo

SRC_DIR=$P4ROOT/axm/clients/platform/iOS/SalesforceOAuth/main/src 

# git container dst dir
DST_DIR=`pwd`/native/SalesforceOAuth

# clean up dst dir
echo "## cleaning up $DST_DIR"
cd $DST_DIR
rm -rf SalesforceOAuth
rm -rf SalesforceOAuthTest
rm -rf SalesforceOAuthUnitTests
rm -rf SalesforceOAuth.xcodeproj

# copy files over
echo "## copying files over"
cd $SRC_DIR
cp -R SalesforceOAuth $DST_DIR
cp -R SalesforceOAuthTest $DST_DIR
cp -R SalesforceOAuthUnitTests $DST_DIR
cp -R SalesforceOAuth.xcodeproj $DST_DIR

# make sure everything is readwrite
cd $SRC_DIR
chmod -R u+w *

# change proj file
echo "## updating project file"
PROJ_FILE=SalesforceOAuth.xcodeproj/project.pbxproj
SRC_PROJ=$SRC_DIR/$PROJ_FILE
DST_PROJ=$DST_DIR/$PROJ_FILE

sed -i '' -e 's/IPHONEOS_DEPLOYMENT_TARGET = 5.0/IPHONEOS_DEPLOYMENT_TARGET = 4.3/' $DST_PROJ
sed -i '' -e 's/INSTALL_PATH = \/Libraries;/INSTALL_PATH = \/;/' $DST_PROJ
sed -i '' -e 's/PUBLIC_HEADERS_FOLDER_PATH = \.\.\/Headers\/SalesforceOAuth;/PUBLIC_HEADERS_FOLDER_PATH = include\/SalesforceOAuth;/' $DST_PROJ
echo "## diffs:"
diff $SRC_PROJ $DST_PROJ
