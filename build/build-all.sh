#!/bin/bash

if [[ -z $WORKSPACE ]]; then
	WORKSPACE=`(cd $(dirname $0)/../; pwd)`
fi

SCRIPT_DIR=`(cd $(dirname $0)/; pwd)`

$SCRIPT_DIR/build-ios.sh -c Debug -b $WORKSPACE/derivedData -f CocoaLumberjack -g CocoaLumberjack-iOS
$SCRIPT_DIR/build-ios.sh -c Release -b $WORKSPACE/derivedData -f CocoaLumberjack -g CocoaLumberjack-iOS

$SCRIPT_DIR/build-ios.sh -c Debug -b $WORKSPACE/derivedData -f SalesforceAnalytics
$SCRIPT_DIR/build-ios.sh -c Release -b $WORKSPACE/derivedData -f SalesforceAnalytics

$SCRIPT_DIR/build-ios.sh -c Debug -b $WORKSPACE/derivedData -f SalesforceSDKCore
$SCRIPT_DIR/build-ios.sh -c Release -b $WORKSPACE/derivedData -f SalesforceSDKCore

$SCRIPT_DIR/build-ios.sh -c Debug -b $WORKSPACE/derivedData -f SmartStore
$SCRIPT_DIR/build-ios.sh -c Release -b $WORKSPACE/derivedData -f SmartStore

$SCRIPT_DIR/build-ios.sh -c Debug -b $WORKSPACE/derivedData -f SmartSync
$SCRIPT_DIR/build-ios.sh -c Release -b $WORKSPACE/derivedData -f SmartSync

$SCRIPT_DIR/build-ios.sh -c Debug -b $WORKSPACE/derivedData -f SalesforceHybridSDK
$SCRIPT_DIR/build-ios.sh -c Release -b $WORKSPACE/derivedData -f SalesforceHybridSDK

$SCRIPT_DIR/build-ios.sh -c Debug -b $WORKSPACE/derivedData -f SalesforceReact
$SCRIPT_DIR/build-ios.sh -c Release -b $WORKSPACE/derivedData -f SalesforceReact
