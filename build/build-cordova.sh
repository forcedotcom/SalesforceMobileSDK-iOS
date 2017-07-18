#!/bin/bash

if [[ -z $WORKSPACE ]]; then
	WORKSPACE=`(cd $(dirname $0)/../; pwd)`
fi

SCRIPT_DIR=`(cd $(dirname $0)/; pwd)`

$SCRIPT_DIR/build-ios.sh -c Debug -f CocoaLumberjack -g CocoaLumberjack-iOS
$SCRIPT_DIR/build-ios.sh -c Release -f CocoaLumberjack -g CocoaLumberjack-iOS

$SCRIPT_DIR/build-ios.sh -c Debug -f SalesforceAnalytics
$SCRIPT_DIR/build-ios.sh -c Release -f SalesforceAnalytics

$SCRIPT_DIR/build-ios.sh -c Debug -f SalesforceSDKCore
$SCRIPT_DIR/build-ios.sh -c Release -f SalesforceSDKCore

$SCRIPT_DIR/build-ios.sh -c Debug -f SmartStore
$SCRIPT_DIR/build-ios.sh -c Release -f SmartStore

$SCRIPT_DIR/build-ios.sh -c Debug -f SmartSync
$SCRIPT_DIR/build-ios.sh -c Release -f SmartSync

$SCRIPT_DIR/build-ios.sh -c Debug -f SalesforceHybridSDK -g SalesforceHybridSDKCordovaPlugin
$SCRIPT_DIR/build-ios.sh -c Release -f SalesforceHybridSDK -g SalesforceHybridSDKCordovaPlugin
