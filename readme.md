# Salesforce.com Mobile SDK for iOS
Installation (do this first - really)
==
Working with this repository requires working with git.  I.e. any workflow that leaves you with a functioning git clone of this repository should set you up for success.  Downloading the ZIP file from GitHub, on the other hand, is likely to put you at a dead end.

## Setting up the repo
First, clone the repo:

- Open the Terminal App
- `cd` to the parent directory where the repo directory will live
- `git clone https://github.com/forcedotcom/SalesforceMobileSDK-iOS.git`

After cloning the repo:

- `cd SalesforceMobileSDK-iOS`
- `./install.sh`

This script pulls the submodule dependencies from GitHub, to finalize setup of the workspace.  You can then work with the Mobile SDK by opening `SalesforceMobileSDK.xcworkspace` from Xcode.

See `build.md` for information on generating binary distributions and app templates.

The Salesforce Mobile SDK for iOS requires iOS 6.0 or greater.  The install.sh script checks for this, and aborts if the configured SDK version is incorrect.  Building from the command line has been tested using ant 1.8.  Older versions might work, but we recommend using the latest version of ant.

If you have problems building any of the projects, take a look at the online [FAQ](https://github.com/forcedotcom/SalesforceMobileSDK-iOS/wiki/FAQ) for troubleshooting tips.

Introduction
==

### What's New in 2.0

**Entity Framework**
- Introducing the entity framework (external/shared/libs/force.entity.js), a set of JavaScript tools to allow you to work with higher level data objects from Salesforce.
- New AccountEditor hybrid sample app with User and Group Search, demonstrating the entity framework functionality in action.

**SmartStore Enhancements**
- SmartStore now supports 'Smart SQL' queries, such as complex aggregate functions, JOINs, and any other SQL-type queries.
- NativeSQLAggregator is a new sample app to demonstrate usage of SmartStore within a native app to run Smart SQL queries, such as aggregate queries.
- SmartStore now supports three data types for index fields - 'string', 'integer', and 'floating'.

**OAuth Enhancements**
- Authentication can now be handled in an on-demand fashion.
- Refresh tokens are now explicitly revoked from the server upon logout.

**Other Technical Improvements**
- All projects and template apps have been converted to use ARC.
- All Xcode projects are now managed under a single workspace (`SalesforceMobileSDK.xcworkspace`).  This allows for a few benefits:
    - During development of the SDK, any changes to underlying libraries/projects will automatically be reflected in their consuming projects/applications.
    - You can now debug all the way through the stack of dependencies, from a sample app down through authentication and other core functionality.
    - No more "staging" of binary artifacts as a prerequisite to working with the projects.  `install.sh` now simply syncs the submodules of the repository, after which you're free to start working in the workspace.
- Native and mobile template apps no longer rely on parent app delegate classes to successfully leverage OAuth authentication.  This means that you the developer are free to form up your `AppDelegate` app flow however you choose, leveraging the updated `SFAuthenticationManager` component wherever it's practical to do so in your app.
- All hybrid dependencies are now decoupled from `SalesforceHybridSDK.framework` (which has been retired).  Which means you can now mix and match your own versions of Cordova, openssl, etc., in your app.  The core functionality of the framework itself has now been converted into a static library.
- Added support for community users to login.
- Consolidated our Cordova JS plugins and utility code into one file (cordova.force.js).
- Fixed session state rehydration for Visualforce apps, in the event of session timeouts during JavaScript Remoting calls in Visualforce.

### Native Applications
The Salesforce Mobile SDK provides the essential libraries for quickly building native mobile apps that interact with the Salesforce cloud platform. The OAuth2 library abstracts away the complexity of securely storing the refresh token or fetching a new session id when it expires. The SDK also provides Objective-C wrappers for the Salesforce REST API, making it easy to retrieve and manipulate data.

### Hybrid Applications
HTML5 is quickly emerging as a powerful technology for developing cross-platform mobile applications. While developers can create sophisticated apps with HTML5 and JavaScript alone, some vital limitations remain, specifically: session management, access to native device functionality like the camera, calendar and address book. The Salesforce Mobile Container (based on the industry leading PhoneGap implementation) makes it possible to embed HTML5 apps stored on the device or delivered via Visualforce inside a thin native container, producing a hybrid application.

### Application Templates
The Mobile SDK provides Xcode templates for quickly constructing the foundation of native and hybrid applications with configurable Settings bundles for allowing the user to log-out of the app or switch between production and Sandbox orgs.

**Native App Template**
For native apps that need to accesses the Salesforce REST API, use the native template that includes a default AppDelegate implementation that you can customize to perform any app-specific interaction. 

**Hybrid App Template**
To create hybrid apps that use the Salesforce REST API or access Visualforce pages, start with the hybrid app template. By providing a SalesforceOAuthPlugin for the container based on PhoneGap, HTML5 applications can quickly leverage OAuth tokens directly from JavaScript calls.


Using the Native REST SDK (in a _new_ project)
==

Create a new "Native Force.com REST App" project (Command-Shift-N in Xcode). These parameters are required:

1. **Consumer Public Key**: The consumer key from your remote access provider.
1. **OAuth Redirect URL**: The URL used by OAuth to handle the callback.
1. **Company Identifier**: Something like com.mycompany.foo -- should correspond with an App ID you created in your Apple iOS dev center account.


You should then be able to compile and run the sample project. It's a simple project which logs you into 
a salesforce instance via oauth, issues a 'select Name from Account' query and displays the result in a UITableView.

Note that the default native app template uses some default test values for the Consumer Public Key and the OAuth Redirect URL.  Before you publish your app to the iTunes App Store, you _MUST_ override these values with values from your own Remote Access object from a Production org. 

Using the Native REST SDK (in an _existing_ project)
==

You can also use the SDK in an existing project:

1. Drag the folder `native/dependencies` into your project (check `Create groups for any added folders`)

2. Open the Build Settings tab for the project.

  * Set __Other Linker Flags__ to `-ObjC -all_load`.

3. Open the Build Phases tab for the project main target and link against the following required frameworks:

	1. **CFNetwork.framework**
	1. **CoreData.framework**
	1. **MobileCoreServices.framework**
	1. **SystemConfiguration.framework**
	1. **Security.framework**
	1. **MessageUI.framework** 
	1. **QuartzCore.framework**
	1. **libxml2.dylib**
	1. **libsqlite3.dylib**
	1. **libz.dylib**	

4. Import the SalesforceSDK header via ``#import "SFRestAPI.h"``.

5. Build the project to verify that the installation is successful.

6. Refer to the [SFRestAPI documentation](http://forcedotcom.github.com/SalesforceMobileSDK-iOS/Documentation/SalesforceSDK/Classes/SFRestAPI.html) for some sample code to login into a salesforce instance and issue a REST API call.


Using the Hybrid app  SDK (in a _new_ project)
==

Create a new "Hybrid Force.com App" project (Command-Shift-N in Xcode). These parameters are required:

1. **Consumer Public Key**: The consumer key from your remote access provider.
1. **OAuth Redirect URL**: The URL used by OAuth to handle the callback.
1. **Company Identifier**: Something like com.mycompany.foo -- should correspond with an App ID you created in your Apple iOS dev center account.

You should then be able to compile and run the sample project, which is very similar to the ContactExplorer sample app.

Note that the default hybrid app template uses some default test values for the Consumer Public Key and the OAuth Redirect URL.  Before you publish your app to the iTunes App Store, you _MUST_ override these values with values from your own Remote Access object from a Production org. 

Working with the hybrid sample apps
==

The sample applications contained under the hybrid/ folder are designed around the [PhoneGap SDK](http://www.phonegap.com/), also known as [callback-ios](https://github.com/callback/callback-ios).  

Before you can work with those applications, you will need to ensure that you've updated the submodules for the SalesforceSDK project.  The default install.sh script sets up these submodules for you so that you need not install PhoneGap separately.

You can find more detailed documentation for working with the PhoneGap SDK in the [PhoneGap Getting Started Guide](http://www.phonegap.com/start).

**Note:** The hybrid sample applications are configured to look for the PhoneGap iOS Framework in their dependencies folder. To find out if the PhoneGap framework is properly linked in a sample project, take the following action:

1. Open the project in Xcode.
2. In Project Navigator, expand the dependencies folder.
3. If PhoneGap.framework is listed among the dependencies , your project should be fine, and no further action should be necessary. 

If you do not see the PhoneGap framework, or otherwise get compilation errors related to the PhoneGap Framework not being found (e.g. 'Undefined symbols for architecture i386: "\_OBJC\_METACLASS\_$\_PhoneGapDelegate"'), you will need to either re-run the install script or add the PhoneGap Framework to the sample project:

1. Open the Xcode project of the sample application.
2. In the Project Navigator, right-click or control-click the Frameworks folder, and select 'Add files to "_Project Name_..."'.
3. Navigate to the Phonegap.framework folder (the default location is project/dependencies/PhoneGap.framework), and click "Add".

The sample application project should now build and run cleanly.

**Note:** _The Salesforce Mobile SDK requires iOS version 5.0 or later and has eliminated the direct use of SBJson._  If your app relies on SBJson, you might consider using SFJsonUtils instead or using the NSJSONSerialization class provided in iOS 5.0 directly.  (SFJsonUtils simply provides a convenience API for those who are porting SBJson-based code to iOS 5.0+.)


Documentation
==

* [Salesforce Native SDK](http://forcedotcom.github.com/SalesforceMobileSDK-iOS/Documentation/SalesforceSDK/index.html)
* [Salesforce OAuth](http://forcedotcom.github.com/SalesforceMobileSDK-iOS/Documentation/SalesforceOAuth/index.html)
* [Salesforce Hybrid SDK](http://forcedotcom.github.com/SalesforceMobileSDK-iOS/Documentation/HybridContainer/index.html)


Discussion
==

If you would like to make suggestions, have questions, or encounter any issues, we'd love to hear from you. Post any feedback you have to the [Mobile Community Discussion Board](http://boards.developerforce.com/t5/Mobile/bd-p/mobile) on developerforce.com.
