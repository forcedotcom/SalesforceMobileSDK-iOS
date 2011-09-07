#!/bin/bash
# This script will copy all the necessary files in the SalesforceMobileSDK-ios public repo. 
# After running this script all the .a, .h in all the dependencies directory
# in the SalesforceMobileSDK-iOS repo will be updated

function copy_subpath {
    SUBPATH=$1
    echo "copying $SUBPATH"
    rm -rf "$DST/$SUBPATH"
    cp -R "$SRC/$SUBPATH" "$DST/$SUBPATH"

}

SRC=`pwd`
DST=$SRC/../SalesforceMobileSDK-ios

# make sure dst dir exists
if [ ! -d "$DST" ]; then
    echo "Directory $DST doesn't exist. Exiting"
    exit
fi

# ask for confirmation
cd $DST
DST_BRANCH=`git br`
cd $SRC
SRC_BRANCH=`git br`

echo "This will copy files from the branch [$SRC_BRANCH] of $SRC"
echo "into the branch [$DST_BRANCH] of $DST"
echo ""

read -p "Ready to process (y|n)? " RESPONSE 

if [ "$RESPONSE" != "y" ]; then
    echo "Aborting"
    exit
fi

#copy_subpath native/SalesforceOAuth/SalesforceOAuth
#copy_subpath native/SalesforceOAuth/Documentation

copy_subpath native/SalesforceSDK/SalesforceSDK
copy_subpath native/SalesforceSDK/dependencies
copy_subpath native/SalesforceSDK/Documentation

copy_subpath "native/Force.com-based Application.xctemplate"

copy_subpath native/SampleApps/RestAPIExplorer/RestAPIExplorer.xcodeproj
copy_subpath native/SampleApps/RestAPIExplorer/RestAPIExplorer
copy_subpath native/SampleApps/RestAPIExplorer/dependencies

copy_subpath hybrid/SampleApps/ContactExplorer/ContactExplorer.xcodeproj
copy_subpath hybrid/SampleApps/ContactExplorer/ContactExplorer
copy_subpath hybrid/SampleApps/ContactExplorer/dependencies
copy_subpath hybrid/SampleApps/ContactExplorer/www

cp LICENSE.md $DST
cp readme.md $DST
