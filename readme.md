# Salesforce.com Mobile SDK for iOS

You have arrived at the **source repository** for the Salesforce Mobile SDK for iOS. ** Welcome!  **
Starting with our 2.0 release, there are couple different ways to get started.

## Different SDK flavors
- If you would like to create a brand new native or hybrid Mobile SDK app for iOS, take a look at our [forceios npm package](https://npmjs.org/package/forceios) tool. Checkout this video for a demo:
[![Alt text for your video](http://img.youtube.com/vi/zNw59KEUF24/0.jpg)](http://www.youtube.com/watch?v=zNw59KEUF24)


- If you have an existing app and/or want to manually add Salesforce Authentication, you should use [SalesforceMobileSDK-iOS-Distribution repository](https://github.com/forcedotcom/SalesforceMobileSDK-iOS-Distribution). Check out this video for a demo:
[![Alt text for your video](http://img.youtube.com/vi/X4jhhmnvjAI/0.jpg)](http://www.youtube.com/watch?v=X4jhhmnvjAI)

- If you want to configure Salesforce communities login page, check out this video for a demo:
[![Alt text for your video](http://img.youtube.com/vi/USFPo2u7jpU/0.jpg)](http://www.youtube.com/watch?v=USFPo2u7jpU)


- If you'd like to **work with the 'source code' of the SDK itself (i.e. perhaps for open-source contribution)**, you should use this repo.  You can browse sample app source code and debug down through the layers to get a feel for how everything works under the covers.  Read on for instructions on how to get started with the SDK in your development environment.

Installation (do this first - really)
==
Working with this repository requires working with git.  Any workflow that leaves you with a functioning git clone of this repository should set you up for success.  Downloading the ZIP file from GitHub, on the other hand, is likely to put you at a dead end.

## Setting up the repo for SDK-development
First, clone the repo:

- Open the Terminal App
- `cd` to the parent directory where the repo directory will live
- `git clone https://github.com/forcedotcom/SalesforceMobileSDK-iOS.git`

After cloning the repo:

- `cd SalesforceMobileSDK-iOS`
- `./install.sh`

This script pulls the submodule dependencies from GitHub, to finalize setup of the workspace.  You can then work with the Mobile SDK by opening `SalesforceMobileSDK.xcworkspace` from Xcode.

See [build.md](build.md) for information on generating binary distributions and app templates.

The Salesforce Mobile SDK for iOS requires iOS 6.0 or greater.  The install.sh script checks for this, and aborts if the configured SDK version is incorrect.  Building from the command line has been tested using ant 1.8.  Older versions might work, but we recommend using the latest version of ant.

If you have problems building any of the projects, take a look at the online [FAQ](https://github.com/forcedotcom/SalesforceMobileSDK-iOS/wiki/FAQ) for troubleshooting tips.

Introduction
==

### What's New in 2.1

**Push Notifications**
- Registration and delivery of push notifications are now supported from a Salesforce org that enables push notifications.

**Networking Enhancements**
- The underlying networking library has been replaced with MKNetworkKit. MKNetworkKit provides the ability to configure advanced features, such as managing the network queue and cancelation of requests.

**Files API Support**
- The Salesforce Mobile SDK now provides convenience methods that build specialized REST requests for file upload/download and sharing operations.
- A native sample app, `FileExplorer`, and a hybrid sample app, `HybridFileExplorer`, have been added to demonstrate these features.

**SmartSync Enhancements**
- You can now access custom endpoints using the `Force.RemoteObject` and `Force.RemoteObjectCollection` classes.
- You can now access Apex REST endpoints using the `Force.ApexRestObject` and `Force.ApexRestObjectCollection` classes.
- NOTE:
	- This feature is only available on hybrid apps.

**Other Technical Improvements**
- OAuth error handling is now configurable.
- Upgraded the `openssl` library to `v1.0.1e` to fix possible security concerns with older versions of `openssl`.
- You can now add one or more delegates to SFAuthenticationManager. This gives you more granular access to the authentication process.
- Various bug fixes.

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
* [Salesforce Hybrid SDK](http://forcedotcom.github.io/SalesforceMobileSDK-iOS/Documentation/SalesforceHybridSDK/html/index.html)
* [Salesforce Native SDK](http://forcedotcom.github.io/SalesforceMobileSDK-iOS/Documentation/SalesforceNativeSDK/html/index.html)
* [Salesforce Network SDK](http://forcedotcom.github.io/SalesforceMobileSDK-iOS/Documentation/SalesforceNetworkSDK/html/index.html)
* [Salesforce OAuth](http://forcedotcom.github.io/SalesforceMobileSDK-iOS/Documentation/SalesforceOAuth/html/index.html)
* [Salesforce SDK Core](http://forcedotcom.github.io/SalesforceMobileSDK-iOS/Documentation/SalesforceSDKCore/html/index.html)


Discussion
==

If you would like to make suggestions, have questions, or encounter any issues, we'd love to hear from you. Post any feedback you have to the [Mobile Community Discussion Board](http://boards.developerforce.com/t5/Mobile/bd-p/mobile) on developerforce.com.
