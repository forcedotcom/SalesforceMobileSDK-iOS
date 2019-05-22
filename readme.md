[![CircleCI](https://circleci.com/gh/forcedotcom/SalesforceMobileSDK-iOS/tree/dev.svg?style=svg)](https://circleci.com/gh/forcedotcom/SalesforceMobileSDK-iOS/tree/dev)
[![codecov](https://codecov.io/gh/forcedotcom/SalesforceMobileSDK-iOS/branch/dev/graph/badge.svg)](https://codecov.io/gh/forcedotcom/SalesforceMobileSDK-iOS/branch/dev)

# Salesforce.com Mobile SDK for iOS

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

### What's New in 7.1

**SmartSync Data Framework Updates**
- SmartSync Data Framework now supports a batch sync up target that uses the Salesforce Composite API for uploading groups of up to 25 records per call.
- New methods allow native apps to stop and restart in-flight sync operations. To reflect the new sync state, we’ve added a stopped sync status.
- Swift `syncUp` and `syncDown` methods that take a sync name, both `reSync` methods, and the legacy `cleanResyncGhosts` method now can throw exceptions.
- We’ve updated iOS methods to make error handling more consistent between platforms.
- You can now call `cleanResyncGhosts` with a sync name.

**Security Updates**
- Mobile SDK for iOS raises its master key security to use Secure Enclave on devices that support it. We’ve also strengthened our master key encryption to use a 256-bit elliptic curve cryptography (ECC) private key.

**Miscellaneous Changes**
- We’ve improved support for using biometric input to supply application passcodes.
- We’ve improved support for sending unauthenticated REST requests to external endpoints. Mobile SDK now provides a shared global instance of its REST client. This REST client doesn’t require OAuth authentication and is unaware of the concept of user. Native apps can use it to send custom unauthenticated requests to non-Salesforce endpoints before or after the user logs in to Salesforce.
- For profiling how Mobile SDK operations affect an app’s runtime performance, we’ve added signposts to Mobile SDK libraries.

**Tool and Version Updates**
- We’ve updated our Swift template app to Swift version 5.0 and Xcode version 10.2.
- We've updated SQLCipher to version 4.0.1

**Deprecation**
- For a list of deprecated methods, see “About Sync Task Errors” in the [*Mobile SDK Development Guide*](https://developer.salesforce.com/docs/atlas.en-us.mobile_sdk.meta/mobile_sdk/)

Check http://developer.force.com/mobilesdk for additional articles and tutorials.

### Native Applications
The Salesforce Mobile SDK provides the essential libraries for quickly building native mobile apps that interact with the Salesforce cloud platform. The OAuth2 library abstracts away the complexity of securely storing the refresh token or fetching a new session ID when it expires. The SDK also provides wrappers for the Salesforce REST API that you can use from both Swift and Objective-C.

Documentation
==

* [SalesforceSDKCommon Library Reference](http://forcedotcom.github.io/SalesforceMobileSDK-iOS/Documentation/SalesforceSDKCommon/html/index.html)
* [SalesforceAnalytics Library Reference](http://forcedotcom.github.io/SalesforceMobileSDK-iOS/Documentation/SalesforceAnalytics/html/index.html)
* [SalesforceSDKCore Library Reference](http://forcedotcom.github.io/SalesforceMobileSDK-iOS/Documentation/SalesforceSDKCore/html/index.html)
* [SmartStore Library Reference](http://forcedotcom.github.io/SalesforceMobileSDK-iOS/Documentation/SmartStore/html/index.html)
* [SmartSync Library Reference](http://forcedotcom.github.io/SalesforceMobileSDK-iOS/Documentation/SmartSync/html/index.html)
* Salesforce Mobile SDK Development Guide -- [PDF](https://github.com/forcedotcom/SalesforceMobileSDK-Shared/blob/master/doc/mobile_sdk.pdf) | [HTML](https://developer.salesforce.com/docs/atlas.en-us.mobile_sdk.meta/mobile_sdk/preface_intro.htm)
* [Mobile SDK Trail](https://trailhead.salesforce.com/en/content/learn/trails/start-ios-appdev)

Discussion
==

If you would like to make suggestions, have questions, or encounter any issues, we'd love to hear from you. Post any feedback you have on [Salesforce StackExchange](https://salesforce.stackexchange.com/questions/tagged/mobilesdk).
