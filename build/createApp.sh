#!/bin/bash

#
# Copyright (c) 2013, salesforce.com, inc. All rights reserved.
# 
# Redistribution and use of this software in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
# * Redistributions of source code must retain the above copyright notice, this list of conditions
# and the following disclaimer.
# * Redistributions in binary form must reproduce the above copyright notice, this list of
# conditions and the following disclaimer in the documentation and/or other materials provided
# with the distribution.
# * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
# endorse or promote products derived from this software without specific prior written
# permission of salesforce.com, inc.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
# FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
# WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
 
set -e
set -u
#set -x

#
# Creates a native or hybrid app, based on the respective app template and user
# configuration.  See the usage() function (or run without arguments) for details.
#

# Command line option vars
OPT_APP_TYPE=""
OPT_APP_NAME=""
OPT_COMPANY_ID=""
OPT_ORG_NAME=""
OPT_APP_ID="3MVG9Iu66FKeHhINkB1l7xt7kR8czFcCTUhgoA8Ol2Ltf1eYHOU4SqQRSEitYFDUpqRWcoQ2.dBv_a1Dyu5xa"
OPT_REDIRECT_URI="testsfdc:///mobilesdk/detect/oauth/done"

# Template substitution keys
SUB_NATIVE_APP_NAME="__NativeTemplateAppName__"
SUB_HYBRID_APP_NAME="__HybridTemplateAppName__"
SUB_COMPANY_ID="__CompanyIdentifier__"
SUB_ORG_NAME="__OrganizationName__"
SUB_APP_ID="__ConnectedAppIdentifier__"
SUB_REDIRECT_URI="__ConnectedAppRedirectUri__"

function usage()
{
    echo "Usage:"
    echo "$0"
    echo "   -t <Application Type> (native, hybrid)"
    echo "   -n <Application Name>"
    echo "   -c <Company Identifier> (com.myCompany.myApp)"
    echo "   -o <Organization Name> (your company's/organization's name"
    echo "   [-a <Salesforce App Identifier>] (the Consumer Key for your app)"
    echo "   [-u <Salesforce App Callback URL] (the Callback URL for your app)"
}

function parseOpts()
{
    while getopts :t:n:c:o:a:u: commandLineOpt
    do
        echo "$commandLineOpt is $OPTARG"
        case $commandLineOpt in
            t) appType=`echo $OPTARG | sed -e 's/^ *//g' -e 's/ *$//g'`
               appType=`echo $appType | tr '[:upper:]' '[:lower:]'`
               if [[ "$appType" != "native" && "$appType" != "hybrid" ]]
               then
                   echo "'$appType' is not a valid application type.  Should be 'native' or 'hybrid'."
                   usage
                   exit 3
               fi
               OPT_APP_TYPE=${appType};;
               
            n) appName=`echo $OPTARG | sed -e 's/^ *//g' -e 's/ *$//g'`
               if [[ -z $appName ]]
               then
                   echo "Application name must have a value."
                   usage
                   exit 4
               fi
               noSpecialCharsAppName=`echo "${appName}" | sed 's/[^a-zA-Z0-9\.\-_ ]//g'`
               if [[ "$noSpecialCharsAppName" != "$appName" ]]
               then
                   echo "Application name ($appName) cannot contain special characters.  Only letters, numbers, spaces, and the characters '.',  '-', and '_' are allowed."
                   usage
                   exit 5
               fi
               OPT_APP_NAME=${appName};;
               
            c) companyId=`echo $OPTARG | sed -e 's/^ *//g' -e 's/ *$//g'`
               if [[ -z $companyId ]]
               then
                   echo "Company identifier must have a value."
                   usage
                   exit 6
               fi
               # Like Apple's template, just convert non-standard Company Identifier characters to dashes, and cull leading periods.
               companyId=`echo $companyId | sed -e 's/^\.\.*//g' | sed -e 's/[^a-zA-Z0-9\.]/-/g'`
               OPT_COMPANY_ID=${companyId};;
               
            o) orgName=`echo $OPTARG | sed -e 's/^ *//g' -e 's/ *$//g'`
               if [[ -z $orgName ]]
               then
                   echo "Organization name must have a value."
                   usage
                   exit 7
               fi
               # Org name can be anything.  Just escape double quotes for the project.
               orgName=`echo $orgName | sed 's/\"/\\\"/g'`
               OPT_ORG_NAME=${orgName};;
               
            a) appId=`echo $OPTARG | sed -e 's/^ *//g' -e 's/ *$//g'`
               if [[ -z $appId ]]
               then
                   echo "App identifier must have a value."
                   usage
                   exit 8
               fi
               OPT_APP_ID=${appId};;
               
            u) redirectUri=`echo $OPTARG | sed -e 's/^ *//g' -e 's/ *$//g'`
               if [[ -z $redirectUri ]]
               then
                   echo "App callback URL must have a value."
                   usage
                   exit 9
               fi
               OPT_REDIRECT_URI=${redirectUri};;
               
            ?) echo "Unknown option '-${OPTARG}'."
               usage
               exit 2;;
        esac
    done
    
    # Validate that we got the required command line args.
    if [[ "$OPT_APP_TYPE" == "" ]]
    then
        echo "No option specified for Application Type.  Must be 'native' or 'hybrid'."
        usage
        exit 10
    fi
    if [[ "$OPT_APP_NAME" == "" ]]
    then
        echo "No option specified for Application Name."
        usage
        exit 11
    fi
    if [[ "$OPT_COMPANY_ID" == "" ]]
    then
        echo "No option specified for Company Identifier."
        usage
        exit 12
    fi
    if [[ "$OPT_ORG_NAME" == "" ]]
    then
        echo "No option specified for Organization Name."
        usage
        exit 13
    fi
}

function replaceTokens()
{
    if [[ "$1" == "native" ]]
    then
        appNameToken=${SUB_NATIVE_APP_NAME}
        inputConnectedAppFile="${appNameToken}/${appNameToken}/Classes/AppDelegate.m"
    elif [[ "$1" == "hybrid" ]]
    then
        appNameToken=${SUB_HYBRID_APP_NAME}
        inputConnectedAppFile="${appNameToken}/${appNameToken}/www/bootconfig.json"
    else
        echo "replaceTokens(): Unknown app type argument '$1'."
        exit 14
    fi
    
    inputPrefixFile="${appNameToken}/${appNameToken}/${appNameToken}-Prefix.pch"
    inputInfoFile="${appNameToken}/${appNameToken}/${appNameToken}-Info.plist"
    inputProjectFile="${appNameToken}/${appNameToken}.xcodeproj/project.pbxproj"
    
    # App name
    cat "${inputPrefixFile}" | sed "s/${appNameToken}/${OPT_APP_NAME}/g" > "${inputPrefixFile}.new"
    mv "${inputPrefixFile}.new" "${inputPrefixFile}"
    cat "${inputProjectFile}" | sed "s/${appNameToken}/${OPT_APP_NAME}/g" > "${inputProjectFile}.new"
    mv "${inputProjectFile}.new" "${inputProjectFile}"
    
    # Company identifier
    cat "${inputInfoFile}" | sed "s/${SUB_COMPANY_ID}/${OPT_COMPANY_ID}/g" > "${inputInfoFile}.new"
    mv "${inputInfoFile}.new" "${inputInfoFile}"
    
    # Org name
    escapedOrgName=`echo $OPT_ORG_NAME | sed 's/\\"/\\\\"/g'`
    cat "${inputProjectFile}" | sed "s/${SUB_ORG_NAME}/${escapedOrgName}/g" > "${inputProjectFile}.new"
    mv "${inputProjectFile}.new" "${inputProjectFile}"
    
    # Connected app ID
    cat "${inputConnectedAppFile}" | sed "s#${SUB_APP_ID}#${OPT_APP_ID}#g" > "${inputConnectedAppFile}.new"
    mv "${inputConnectedAppFile}.new" "${inputConnectedAppFile}"
    
    # Redirect URI
    cat "${inputConnectedAppFile}" | sed "s#${SUB_REDIRECT_URI}#${OPT_REDIRECT_URI}#g" > "${inputConnectedAppFile}.new"
    mv "${inputConnectedAppFile}.new" "${inputConnectedAppFile}"
    
    # Rename files
    mv "${inputPrefixFile}" "${appNameToken}/${appNameToken}/${OPT_APP_NAME}-Prefix.pch"
    mv "${inputInfoFile}" "${appNameToken}/${appNameToken}/${OPT_APP_NAME}-Info.plist"
    mv "${appNameToken}/${appNameToken}.xcodeproj" "${appNameToken}/${OPT_APP_NAME}.xcodeproj"
    mv "${appNameToken}/${appNameToken}" "${appNameToken}/${OPT_APP_NAME}"
    mv "${appNameToken}" "${OPT_APP_NAME}"
}

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

if [[ "$@" == "" ]]
then
    usage
    exit 1
fi

parseOpts "$@"
replaceTokens $OPT_APP_TYPE

echo "Successfully created $OPT_APP_TYPE app '$OPT_APP_NAME'."
