!#!/bin/bash

#set -x

OPT_VERSION=""
OPT_IS_DEV="no"
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

usage ()
{
    echo "Use this script to set Mobile SDK version number in source files"
    echo "Usage: $0 -v <version> [-d <isDev>]"
    echo "  where: version is the version e.g. 7.1.0"
    echo "         isDev is yes or no (default) to indicate whether it is a dev build"
}

parse_opts ()
{
    while getopts v:d: command_line_opt
    do
        case ${command_line_opt} in
            v)  OPT_VERSION=${OPTARG};;
            d)  OPT_IS_DEV=${OPTARG};;
        esac
    done

    if [ "${OPT_VERSION}" == "" ]
    then
        echo -e "${RED}You must specify a value for the version.${NC}"
        usage
        exit 1
    fi
}

# Helper functions
update_version_xcconfig ()
{
    local file=$1
    local version=$2
    sed -i "s/CURRENT_PROJECT_VERSION.*=.*$/CURRENT_PROJECT_VERSION = ${version}/g" ${file}
}

update_package_json ()
{
    local file=$1
    local version=$2
    sed -i "s/\"version\":.*\"[^\"]*\"/\"version\": \"${version}\"/g" ${file}
}

update_podspec ()
{
    local file=$1
    local version=$2
    sed -i "s/s\.version.*=.*$/s.version      = \"${version}\"/g" ${file}
}

update_salesforce_sdk_constants ()
{
    local file=$1
    local isDev=$2
    local isProdBool="YES"

    if [ $isDev == "yes" ]
    then
        isProdBool="NO"
    fi

    sed -i "s/\#define\ SALESFORCE_SDK_IS_PRODUCTION_VERSION\ .*/#define SALESFORCE_SDK_IS_PRODUCTION_VERSION ${isProdBool}/g" ${file}

}

parse_opts "$@"

echo -e "${YELLOW}*** SETTING VERSION TO ${OPT_VERSION}, IS DEV = ${OPT_IS_DEV} ***${NC}"

echo "*** Updating Version.xcconfig ***"
update_version_xcconfig "./configuration/Version.xcconfig" "${OPT_VERSION}"

echo "*** Updating package.json ***"
update_package_json "./package.json" "${OPT_VERSION}"

echo "*** Updating podspecs ***"
update_podspec "./SalesforceSDKCommon.podspec" "${OPT_VERSION}"
update_podspec "./SalesforceAnalytics.podspec" "${OPT_VERSION}"
update_podspec "./SalesforceSDKCore.podspec" "${OPT_VERSION}"
update_podspec "./SmartStore.podspec" "${OPT_VERSION}"
update_podspec "./SmartSync.podspec" "${OPT_VERSION}"

echo "*** Updating SalesforceSDKConstants.h ***"
update_salesforce_sdk_constants "./libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Common/SalesforceSDKConstants.h" "${OPT_IS_DEV}"

echo -e "${RED}!!! You still need to update SALESFORCE_SDK_VERSION_MIN_REQUIRED in ./libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Common/SalesforceSDKConstants.h !!!${NC}"
