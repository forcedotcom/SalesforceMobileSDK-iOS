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

### What's New in 7.0

For iOS, Mobile SDK 7.0 marks the beginning of an ongoing collaboration with Apple Inc., to enhance the usability and standardization
of our Swift APIs. As a result of this partnership, our Swift offerings have undergone extensive changes. The revised APIs are “Swiftified”
aliases for the Mobile SDK Objective-C APIs.

**Swift API Updates**
- For improved readability, we’ve applied “Swifty” restyling to many class names, method names, and parameter names. The Xcode
editor provides excellent support for these API names, so it’s easy to find what you want. If you don’t see what you’re looking for,
you can search the Objective-C header files as follows:
  - Look for customized Swift names in `NS_SWIFT_NAME()` macros next to their Objective-C counterparts.
  - A few Objective-C APIs aren’t available in Swift. These APIs are marked with the `NS_SWIFT_UNAVAILABLE("")` macro.
  - If an Objective-C API isn’t marked with either the `NS_SWIFT_NAME()` or `NS_SWIFT_UNAVAILABLE("")` macro, you
call it in Swift using its Objective-C naming.
- We've redesigned our Swift APIs to use closures and/or delegates for asynchronous calls.
- Mobile SDK no longer requires the `Cocoa Lumberjack` logging framework. For compiler-level logging, use the `os_log()` function
from Apple’s unified logging system. See [iOS Compiler-Level Logging](https://developer.salesforce.com/docs/atlas.en-us.noversion.mobile_sdk.meta/mobile_sdk/analytics_logging_ios.htm).

**Miscellaneous Changes**
- We’ve simplified `AppDelegate` initialization logic by decoupling login from SDK initialization. You’re no longer required to listen to
and handle Mobile SDK launch events.
- Advanced authentication is now allowed by default. The type of authentication used by a Mobile SDK app can be configured only
through My Domain settings.
- As recommended by Apple, we’ve updated iOS advanced authentication to use `SFAuthenticationSession` instead of
`SFSafariViewController`. This notice is informational only and does not require any action on your part.
- Mobile SDK apps now support both Face ID and Touch ID.
- We’ve updated and improved the app passcode dialog box.
  
**iOS Version Updates**
- iOS minimum version (deployment target): iOS 11
- iOS base SDK version: iOS 12
- Xcode minimum version: 10
  
**Deprecation**
- `PromiseKit` is no longer a dependency of Mobile SDK. Instead, you can use standard delegates or blocks to handle asynchronous calls.
- `SFSDKLogger` is now deprecated in Mobile SDK apps. Use `os_log()` instead.
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

If you would like to make suggestions, have questions, or encounter any issues, we'd love to hear from you. Post any feedback you have on our [Google+ community](https://plus.google.com/communities/114225252149514546445).
