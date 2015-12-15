[![Build Status](https://travis-ci.org/forcedotcom/SalesforceMobileSDK-iOS.svg?branch=unstable)](https://travis-ci.org/forcedotcom/SalesforceMobileSDK-iOS)

# Salesforce.com Mobile SDK for iOS

You have arrived at the source repository for the Salesforce Mobile SDK for iOS.  Welcome!  Starting with our 2.0 release, there are now three ways you can choose to work with the Mobile SDK:

- If you'd like to work with the source code of the SDK itself, you've come to the right place!  You can browse sample app source code and debug down through the layers to get a feel for how everything works under the covers.  Read on for instructions on how to get started with the SDK in your development environment.
- If you're just eager to start developing your own new application, the quickest way is to use our npm binary distribution package, called [forceios](https://npmjs.org/package/forceios), which is hosted on [npmjs.org](https://npmjs.org/).  Getting started is as simple as installing the npm package and launching your template app.  You'll find more details on the forceios package page.
- If you would like to add the Mobile SDK components to your existing native application, check out the [SalesforceMobileSDK-iOS-Distribution repository](https://github.com/forcedotcom/SalesforceMobileSDK-iOS-Distribution), which contains our binary distributions as well as information on how to add them to your native app.

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

See [build.md](build.md) for information on generating binary distributions and app templates.

The Salesforce Mobile SDK for iOS requires iOS 8.0 or greater.  The install.sh script checks for this, and aborts if the configured SDK version is incorrect.  Building from the command line has been tested using ant 1.8.  Older versions might work, but we recommend using the latest version of ant.

If you have problems building any of the projects, take a look at the online [FAQ](https://github.com/forcedotcom/SalesforceMobileSDK-iOS/wiki/FAQ) for troubleshooting tips.

Introduction
==

### What's New in 4.0

**Library Upgrades**
- iOS 9 features are now fully supported, including bitcode.
- Raised the minimum iOS version required by Mobile SDK to `8.0`.
- Upgraded the `Cordova` library to `v3.9.2`.
- Upgraded the `CocoaLumberjack` library to `v2.2.0`.

**Library Enhancements**
- Mobile SDK libraries have been refactored to support better consumption. Our libraries are listed below.
	- SalesforceSDKCore
	- SalesforceNetwork
	- SalesforceRestAPI
	- SmartStore
	- SmartSync
	- SalesforceHybridSDK
	- SalesforceReact
- Cocoa Touch dynamic framework targets have been added to our libraries. Going forward, this will be the recommended way to consume Mobile SDK libraries.
- Removed the dependency on `SalesforceCommonUtils`. Mobile SDK for iOS is now fully open source.
- The SalesforceReact library now provides the ability to use React Native. Refer to the React Native chapter in the Mobile SDK Development Guide for details on how to use this feature.

**Other Technical Improvements**
- Raised the minimum XCode version required by Mobile SDK to `Xcode 7`.
- Improvements to sample apps.
- Various bug fixes.

Check http://developer.force.com/mobilesdk for additional articles and tutorials.

### Native Applications
The Salesforce Mobile SDK provides the essential libraries for quickly building native mobile apps that interact with the Salesforce cloud platform. The OAuth2 library abstracts away the complexity of securely storing the refresh token or fetching a new session ID when it expires. The SDK also provides Objective-C wrappers for the Salesforce REST API, making it easy to retrieve and manipulate data.

### Hybrid Applications
HTML5 is quickly emerging as a powerful technology for developing cross-platform mobile applications. While developers can create sophisticated apps with HTML5 and JavaScript alone, some vital limitations remain, specifically: session management and universal access to native device functionality like the camera, calendar and address book. The Salesforce Mobile Container (based on the industry-leading PhoneGap implementation) makes it possible to embed HTML5 apps stored on the device or delivered via Visualforce inside a thin native container, producing a hybrid application.

### Application Templates
The Mobile SDK provides the means to generate your new app from a template, to quickly construct the foundation of native and hybrid applications.  These apps come with a fully functioning demo app, as well as configurable Settings bundles that allow the user to log out of the app or switch between Production and Sandbox orgs.  See [build.md](build.md) for more information on how to generate and use the templates.

**Native App Template**
For native apps that need to access the Salesforce REST API, create your app using the native template.  The template includes a default AppDelegate implementation that you can customize to perform any app-specific interaction.

**Hybrid App Template**
To create hybrid apps that use the Salesforce REST API or access Visualforce pages, create your app using the hybrid app template. By providing the SalesforceOAuthPlugin for our PhoneGap-based container, HTML5 applications can quickly leverage OAuth tokens directly from JavaScript calls.  In addition, our SFSmartStorePlugin will allow you to store your app data securely on the device.

Documentation
==

* [Salesforce Mobile SDK Development Guide](https://github.com/forcedotcom/SalesforceMobileSDK-Shared/blob/master/doc/mobile_sdk.pdf?raw=true)
* [Salesforce Mobile SDK for iOS Reference](http://forcedotcom.github.io/SalesforceMobileSDK-iOS/Documentation/masterTOC.html)



Discussion
==

If you would like to make suggestions, have questions, or encounter any issues, we'd love to hear from you. Post any feedback you have on our [Google+ community](https://plus.google.com/communities/114225252149514546445).
