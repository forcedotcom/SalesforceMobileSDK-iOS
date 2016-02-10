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
# Creates a native app based on the respective app template and user
# configuration.  See the usage() function (or run without arguments) for details.
#

# Command line option vars
OPT_APP_TYPE=""
OPT_APP_NAME=""
OPT_COMPANY_ID=""
OPT_ORG_NAME=""
OPT_APP_ID="3MVG9Iu66FKeHhINkB1l7xt7kR8czFcCTUhgoA8Ol2Ltf1eYHOU4SqQRSEitYFDUpqRWcoQ2.dBv_a1Dyu5xa"
OPT_REDIRECT_URI="testsfdc:///mobilesdk/detect/oauth/done"
OPT_OUTPUT_FOLDER=`pwd`

# Template substitution keys
SUB_NATIVE_APP_NAME="__NativeTemplateAppName__"
SUB_NATIVE_SWIFT_APP_NAME="__NativeSwiftTemplateAppName__"
SUB_REACT_NATIVE_APP_NAME="__ReactNativeTemplateAppName__"
SUB_COMPANY_ID="__CompanyIdentifier__"
SUB_ORG_NAME="__OrganizationName__"
SUB_APP_ID="__ConnectedAppIdentifier__"
SUB_REDIRECT_URI="__ConnectedAppRedirectUri__"

# Term color codes
TERM_COLOR_RED="\x1b[31;1m"
TERM_COLOR_GREEN="\x1b[32;1m"
TERM_COLOR_YELLOW="\x1b[33;1m"
TERM_COLOR_MAGENTA="\x1b[35;1m"
TERM_COLOR_CYAN="\x1b[36;1m"
TERM_COLOR_RESET="\x1b[0m"

function echoColor
{
  echo -e "$1$2$TERM_COLOR_RESET"
}

function usage()
{
  local appName=`basename $0`
  echoColor $TERM_COLOR_CYAN "Usage:"
  echoColor $TERM_COLOR_MAGENTA "$appName"
  echoColor $TERM_COLOR_MAGENTA "   -t <Application Type> (native, native_swift, react_native)"
  echoColor $TERM_COLOR_MAGENTA "   -n <Application Name>"
  echoColor $TERM_COLOR_MAGENTA "   -c <Company Identifier> (com.myCompany.myApp)"
  echoColor $TERM_COLOR_MAGENTA "   -g <Organization Name> (your company's/organization's name"
  echoColor $TERM_COLOR_MAGENTA "   [-o <Output directory> (defaults to this script's directory)]"
  echoColor $TERM_COLOR_MAGENTA "   [-a <Salesforce App Identifier>] (the Consumer Key for your app)]"
  echoColor $TERM_COLOR_MAGENTA "   [-u <Salesforce App Callback URL] (the Callback URL for your app)]"
}

function parseOpts()
{
  while getopts :t:n:c:g:o:a:u:s: commandLineOpt; do
    case ${commandLineOpt} in
      t)
        appType=`echo ${OPTARG} | sed -e 's/^ *//g' -e 's/ *$//g'`
        appType=`echo ${appType} | tr '[:upper:]' '[:lower:]'`
        if [[ "${appType}" != "native" && "${appType}" != "native_swift" && "${appType}" != "react_native" ]]; then
          echoColor $TERM_COLOR_RED "'${appType}' is not a valid application type.  Should be 'native' or 'native_swift' or 'react_native'."
          usage
          exit 3
        fi
        OPT_APP_TYPE=${appType};;
      n)
        appName=`echo ${OPTARG} | sed -e 's/^ *//g' -e 's/ *$//g'`
        if [[ -z ${appName} ]]; then
          echoColor $TERM_COLOR_RED "Application name must have a value."
          usage
          exit 4
        fi
        noSpecialCharsAppName=`echo "${appName}" | sed 's/[^a-zA-Z0-9\._ -]//g'`
        if [[ "${noSpecialCharsAppName}" != "${appName}" ]]; then
          echoColor $TERM_COLOR_RED "Application name (${appName}) cannot contain special characters.  Only letters, numbers, spaces, and the characters '.',  '-', and '_' are allowed."
          usage
          exit 5
        fi
        OPT_APP_NAME=${appName};;
      c)
        companyId=`echo ${OPTARG} | sed -e 's/^ *//g' -e 's/ *$//g'`
        if [[ -z ${companyId} ]]; then
          echoColor $TERM_COLOR_RED "Company identifier must have a value."
          usage
          exit 6
        fi
        # Like Apple's template, just convert non-standard Company Identifier characters to dashes, and cull leading periods.
        companyId=`echo ${companyId} | sed -e 's/^\.\.*//g' | sed -e 's/[^a-zA-Z0-9\.]/-/g'`
        OPT_COMPANY_ID=${companyId};;
      g)
        orgName=`echo ${OPTARG} | sed -e 's/^ *//g' -e 's/ *$//g'`
        if [[ -z ${orgName} ]]; then
          echoColor $TERM_COLOR_RED "Organization name must have a value."
          usage
          exit 7
        fi
        # Org name can be anything.
        OPT_ORG_NAME=${orgName};;
      o)
        outputFolder=`echo ${OPTARG} | sed -e 's/^ *//g' -e 's/ *$//g'`
        if [[ -z ${outputFolder} ]]; then
          echoColor $TERM_COLOR_RED "Output folder must have a value."
          usage
          exit 8
        fi
        OPT_OUTPUT_FOLDER=${outputFolder};;
      a)
        appId=`echo ${OPTARG} | sed -e 's/^ *//g' -e 's/ *$//g'`
        if [[ -z ${appId} ]]; then
          echoColor $TERM_COLOR_RED "App identifier must have a value."
          usage
          exit 9
        fi
        OPT_APP_ID=${appId};;
      u)
        redirectUri=`echo ${OPTARG} | sed -e 's/^ *//g' -e 's/ *$//g'`
        if [[ -z ${redirectUri} ]]; then
          echoColor $TERM_COLOR_RED "App callback URL must have a value."
          usage
          exit 10
        fi
        OPT_REDIRECT_URI=${redirectUri};;
      ?)
        echoColor $TERM_COLOR_RED "Unknown option '-${OPTARG}'."
        usage
        exit 2;;
    esac
  done
  
  # Validate that we got the required command line args.
  if [[ "${OPT_APP_TYPE}" == "" ]]; then
    echoColor $TERM_COLOR_RED "No option specified for Application Type.  Must be 'native' or 'native_swift' or 'react_native'."
    usage
    exit 12
  fi
  if [[ "${OPT_APP_NAME}" == "" ]]; then
    echoColor $TERM_COLOR_RED "No option specified for Application Name."
    usage
    exit 13
  fi
  if [[ "${OPT_COMPANY_ID}" == "" ]]; then
    echoColor $TERM_COLOR_RED "No option specified for Company Identifier."
    usage
    exit 14
  fi
  if [[ "${OPT_ORG_NAME}" == "" ]]; then
    echoColor $TERM_COLOR_RED "No option specified for Organization Name."
    usage
    exit 15
  fi
}

function tokenSubstituteInFile()
{
  local subFile=$1
  local token=$2
  local replacement=$3

  if [[ -e "${subFile}" ]]; then
      # Sanitize the replacement value for sed.  (Assume $token is fine—we control that value.)
      replacement=`echo "${replacement}" | sed 's/[\&/]/\\\&/g'`

      cat "${subFile}" | sed "s/${token}/${replacement}/g" > "${subFile}.new"
      mv "${subFile}.new" "${subFile}"
  fi
}

function replaceTokens()
{
  local appNameToken
  local inputConnectedAppFile
  local inputPodfile
  local inputPrefixFile
  local inputInfoFile
  local inputIndexiosFile
  local inputPackageJsonFile
  
  if [[ "$1" == "native" ]]; then
      appNameToken=${SUB_NATIVE_APP_NAME}
      inputConnectedAppFile="${appNameToken}/${appNameToken}/AppDelegate.m"
  elif [[ "$1" == "native_swift" ]]; then
      appNameToken=${SUB_NATIVE_SWIFT_APP_NAME}
      inputConnectedAppFile="${appNameToken}/${appNameToken}/AppDelegate.swift"
  elif [[ "$1" == "react_native" ]]; then
      appNameToken=${SUB_REACT_NATIVE_APP_NAME}
      inputConnectedAppFile="${appNameToken}/${appNameToken}/AppDelegate.m"
      inputIndexiosFile="${appNameToken}/js/index.ios.js"
      inputPackageJsonFile="${appNameToken}/package.json"
  else
      echoColor $TERM_COLOR_RED "replaceTokens(): Unknown app type argument '$1'."
      exit 16
  fi

  inputPodfile="${appNameToken}/Podfile"
  inputPrefixFile="${appNameToken}/${appNameToken}/Prefix.pch"
  inputInfoFile="${appNameToken}/${appNameToken}/Info.plist"
  inputProjectFile="${appNameToken}/${appNameToken}.xcodeproj/project.pbxproj"
  inputSharedSchemeFile="${appNameToken}/${appNameToken}.xcodeproj/xcshareddata/xcschemes/${appNameToken}.xcscheme"


  # Make the output folder.
  if [[ -e "${OPT_OUTPUT_FOLDER}" ]]; then
    if [[ ! -d "${OPT_OUTPUT_FOLDER}" ]]; then
      echoColor $TERM_COLOR_RED "'${OPT_OUTPUT_FOLDER}' already exists, and is not a directory."
      exit 17
    elif [[ -e "${OPT_OUTPUT_FOLDER}/${OPT_APP_NAME}" ]]; then
      echoColor $TERM_COLOR_RED "'${OPT_OUTPUT_FOLDER}/${OPT_APP_NAME}' already exists.  Cannot continue."
      exit 18
    fi
  else
    echoColor $TERM_COLOR_YELLOW "Creating output folder ${OPT_OUTPUT_FOLDER}"
    mkdir -p "${OPT_OUTPUT_FOLDER}"
  fi
  local outputFolderAbsPath=`cd "${OPT_OUTPUT_FOLDER}" && pwd`

  # Copy the app template folder to a new working folder, and change to that folder.
  local origWorkingFolder=`pwd`
  local workingFolderPrefix=`basename ${BASH_SOURCE[0]}`
  local workingFolderTemplate="/tmp/${workingFolderPrefix}.XXXXXX"
  local workingFolder=`mktemp -d ${workingFolderTemplate}`
  local resourcesFolder=`dirname "${BASH_SOURCE[0]}"`
  cp -RL "${resourcesFolder}/${appNameToken}" "${workingFolder}"
  cd "${workingFolder}"

  # App name
  tokenSubstituteInFile "${inputPodfile}" "${appNameToken}" "${OPT_APP_NAME}"
  tokenSubstituteInFile "${inputProjectFile}" "${appNameToken}" "${OPT_APP_NAME}"
  tokenSubstituteInFile "${inputSharedSchemeFile}" "${appNameToken}" "${OPT_APP_NAME}"
  tokenSubstituteInFile "${inputPrefixFile}" "${appNameToken}" "${OPT_APP_NAME}"
  tokenSubstituteInFile "${inputIndexiosFile}" "${appNameToken}" "${OPT_APP_NAME}"
  tokenSubstituteInFile "${inputConnectedAppFile}" "${appNameToken}" "${OPT_APP_NAME}"
  tokenSubstituteInFile "${inputPackageJsonFile}" "${appNameToken}" "${OPT_APP_NAME}"
  
  # Company identifier
  tokenSubstituteInFile "${inputInfoFile}" "${SUB_COMPANY_ID}" "${OPT_COMPANY_ID}"
  
  # Org name
  tokenSubstituteInFile "${inputProjectFile}" "${SUB_ORG_NAME}" "${OPT_ORG_NAME}"
  
  # Connected app ID
  tokenSubstituteInFile "${inputConnectedAppFile}" "${SUB_APP_ID}" "${OPT_APP_ID}"
  
  # Redirect URI
  tokenSubstituteInFile "${inputConnectedAppFile}" "${SUB_REDIRECT_URI}" "${OPT_REDIRECT_URI}"
  
  # Rename files, move to destination folder.
  echoColor $TERM_COLOR_YELLOW "Creating app in ${outputFolderAbsPath}/${OPT_APP_NAME}"
  mv "${appNameToken}/${appNameToken}.xcodeproj/xcshareddata/xcschemes/${appNameToken}.xcscheme" "${appNameToken}/${appNameToken}.xcodeproj/xcshareddata/xcschemes/${OPT_APP_NAME}.xcscheme"
  mv "${appNameToken}/${appNameToken}.xcodeproj" "${appNameToken}/${OPT_APP_NAME}.xcodeproj"
  mv "${appNameToken}/${appNameToken}" "${appNameToken}/${OPT_APP_NAME}"
  mv "${appNameToken}" "${outputFolderAbsPath}/${OPT_APP_NAME}"
      
  # Remove working artifacts
  cd "${origWorkingFolder}"
  rm -rf "${workingFolder}"
}

function runNpmInstall()
{
  local origWorkingFolder=`pwd`
  
  # Run npm install
  echoColor $TERM_COLOR_YELLOW "Getting npm dependencies"
  cd "${OPT_OUTPUT_FOLDER}/${OPT_APP_NAME}"
  npm install
  cd "${origWorkingFolder}"
}

function runPodInstall()
{
  local origWorkingFolder=`pwd`
  
  # Run pod install
  echoColor $TERM_COLOR_YELLOW "Getting cocoapods dependencies"
  cd "${OPT_OUTPUT_FOLDER}/${OPT_APP_NAME}"
  pod install
  cd "${origWorkingFolder}"
}

if [[ "$@" == "" ]]; then
  usage
  exit 1
fi

parseOpts "$@"
replaceTokens ${OPT_APP_TYPE}

if [[ "${OPT_APP_TYPE}" == "react_native" ]]; then
  runNpmInstall
  runPodInstall
else
  runPodInstall 
fi

echoColor $TERM_COLOR_GREEN "Successfully created ${OPT_APP_TYPE} app '${OPT_APP_NAME}'."
