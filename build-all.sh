#!/bin/bash

if [[ -z $WORKSPACE ]]; then
	WORKSPACE=`(cd $(dirname $0)/; pwd)`
fi


./build-ios.sh -c Debug -b $WORKSPACE/derivedData -f CocoaLumberjack -g CocoaLumberjack-iOS
./build-ios.sh -c Release -b $WORKSPACE/derivedData -f CocoaLumberjack -g CocoaLumberjack-iOS

./build-ios.sh -c Debug -b $WORKSPACE/derivedData -f SalesforceAnalytics
./build-ios.sh -c Release -b $WORKSPACE/derivedData -f SalesforceAnalytics

./build-ios.sh -c Debug -b $WORKSPACE/derivedData -f SalesforceSDKCore
./build-ios.sh -c Release -b $WORKSPACE/derivedData -f SalesforceSDKCore

./build-ios.sh -c Debug -b $WORKSPACE/derivedData -f SmartStore
./build-ios.sh -c Release -b $WORKSPACE/derivedData -f SmartStore

./build-ios.sh -c Debug -b $WORKSPACE/derivedData -f SmartStore
./build-ios.sh -c Release -b $WORKSPACE/derivedData -f SmartStore

./build-ios.sh -c Debug -b $WORKSPACE/derivedData -f SmartSync
./build-ios.sh -c Release -b $WORKSPACE/derivedData -f SmartSync

./build-ios.sh -c Debug -b $WORKSPACE/derivedData -f SalesforceHybridSDK
./build-ios.sh -c Release -b $WORKSPACE/derivedData -f SalesforceHybridSDK

./build-ios.sh -c Debug -b $WORKSPACE/derivedData -f SalesforceReact
./build-ios.sh -c Release -b $WORKSPACE/derivedData -f SalesforceReact

