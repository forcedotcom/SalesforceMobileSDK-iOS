# Salesforce.com Mobile SDK for iOS
[![CircleCI](https://circleci.com/gh/forcedotcom/SalesforceMobileSDK-iOS/tree/dev.svg?style=svg)](https://circleci.com/gh/forcedotcom/SalesforceMobileSDK-iOS/tree/dev)
[![Known Vulnerabilities](https://snyk.io/test/github/forcedotcom/SalesforceMobileSDK-iOS/badge.svg)](https://snyk.io/test/github/forcedotcom/SalesforceMobileSDK-iOS)
![GitHub release (latest SemVer)](https://img.shields.io/github/v/release/forcedotcom/SalesforceMobileSDK-iOS?sort=semver)


You have arrived at the source repository for the Salesforce Mobile SDK for iOS.  Welcome!  There are two ways you can choose to work with the Mobile SDK:

- If you'd like to work with the source code of the SDK itself, you've come to the right place!  You can browse sample app source code and debug down through the layers to get a feel for how everything works under the covers.  Read on for instructions on how to get started with the SDK in your development environment.
- If you're just eager to start developing your own new application, the quickest way is to use our npm distribution package, called [forceios](https://npmjs.org/package/forceios), which is hosted on [npmjs.org](https://npmjs.org/).  Getting started is as simple as installing the npm package and launching your template app.  You'll find more details on the forceios package page.

Installation (do this first - really)
==
Working with this repository requires working with git.  Any workflow that leaves you with a functioning git clone of this repository should set you up for success.  Downloading the ZIP file from GitHub, on the other hand, is likely to put you at a dead end.

## Setting up the repo
First, clone the repo:

- Open the Terminal App
- `cd` to the parent directory where the repo directory will live
- `git clone https://github.com/forcedotcom/SalesforceMobileSDK-iOS.git`

After cloning the repo:

- `cd SalesforceMobileSDK-iOS`
- `./install.sh`

This script pulls the submodule dependencies from GitHub, to finalize setup of the workspace.  You can then work with the Mobile SDK by opening `SalesforceMobileSDK.xcworkspace` from Xcode.

The Salesforce Mobile SDK for iOS requires iOS 11.0 or greater.  The install.sh script checks for this, and aborts if the configured SDK version is incorrect.

Introduction
==

### What's New in 10.2.0
See [release notes](https://github.com/forcedotcom/SalesforceMobileSDK-iOS/releases).

### Native Applications
The Salesforce Mobile SDK provides the essential libraries for quickly building native mobile apps that interact with the Salesforce cloud platform. The OAuth2 library abstracts away the complexity of securely storing the refresh token or fetching a new session ID when it expires. The SDK also provides wrappers for the Salesforce REST API that you can use from both Swift and Objective-C.

Documentation
==

* [SalesforceSDKCommon Library Reference](http://forcedotcom.github.io/SalesforceMobileSDK-iOS/Documentation/SalesforceSDKCommon/html/index.html)
* [SalesforceAnalytics Library Reference](http://forcedotcom.github.io/SalesforceMobileSDK-iOS/Documentation/SalesforceAnalytics/html/index.html)
* [SalesforceSDKCore Library Reference](http://forcedotcom.github.io/SalesforceMobileSDK-iOS/Documentation/SalesforceSDKCore/html/index.html)
* [SmartStore Library Reference](http://forcedotcom.github.io/SalesforceMobileSDK-iOS/Documentation/SmartStore/html/index.html)
* [MobileSync Library Reference](http://forcedotcom.github.io/SalesforceMobileSDK-iOS/Documentation/MobileSync/html/index.html)
* Salesforce Mobile SDK Development Guide -- [HTML](https://developer.salesforce.com/docs/atlas.en-us.mobile_sdk.meta/mobile_sdk/preface_intro.htm)
* [Mobile SDK Trail](https://trailhead.salesforce.com/en/content/learn/trails/start-ios-appdev)

Discussion
==

If you would like to make suggestions, have questions, or encounter any issues, we'd love to hear from you. Post any feedback you have on the [Mobile SDK Trailblazer Community](https://trailhead.salesforce.com/en/trailblazer-community/groups/0F94S000000kH0HSAU?tab=discussion&sort=LAST_MODIFIED_DATE_DESC).
