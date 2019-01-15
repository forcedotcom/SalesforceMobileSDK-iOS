#!/bin/bash

#set -x

OPT_VERSION=""
OPT_IS_DEV=""
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

usage ()
{
    echo "Use this script to set Mobile SDK version number in source files"
    echo "Usage: $0 -v <versionName e.g. 7.1.0> [-d <isDev e.g. yes>]"
}

parse_opts ()
{
    while getopts v:d: command_line_opt
    do
        case ${command_line_opt} in
            v)
                OPT_VERSION=${OPTARG};;
            d)
                OPT_IS_DEV=${OPTARG};;
            ?)
                echo "Unknown option '-${OPTARG}'."
                usage
                exit 1;;
        esac
    done

    if [ "${OPT_VERSION}" == "" ]
    then
        echo "You must specify a value for the version."
        usage
        exit 1
    fi

    valid_version_regex='^[0-9]+\.[0-9]+\.[0-9]+$'
    if [[ "${OPT_VERSION}" =~ $valid_version_regex ]]
     then
         # No action
            :
     else
        echo "${OPT_VERSION} is not a valid version name.  Should be in the format <integer.integer.interger>"
        exit 2
    fi

    if [ "${OPT_IS_DEV}" == "yes" ]
    then
       OPT_IS_DEV=1
    else
       OPT_IS_DEV=0
    fi

}

# Helper functions
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

parse_opts "$@"

echo -e "${YELLOW}*** SETTING VERSION TO ${OPT_VERSION}, IS DEV = ${OPT_IS_DEV} ***${NC}"

echo "*** Updating package.json ***"
update_package_json "./package.json" "${OPT_VERSION}"

echo "*** Updating podspecs ***"
update_podspec "./SalesforceSDKCommon.podspec" "${OPT_VERSION}"
update_podspec "./SalesforceAnalytics.podspec" "${OPT_VERSION}"
update_podspec "./SalesforceSDKCore.podspec" "${OPT_VERSION}"
update_podspec "./SmartStore.podspec" "${OPT_VERSION}"
update_podspec "./SmartSync.podspec" "${OPT_VERSION}"

echo -e "${RED}!!! You still need to update ./libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Common/SalesforceSDKConstants.h !!!${NC}"
