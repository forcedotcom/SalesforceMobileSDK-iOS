# Salesforce.com Mobile SDK for iOS
Installation (do this first - really)
==
After cloning the SalesforceMobileSDK-iOS project from github, run the install script from the Terminal command line:

`./install.sh`
This pulls submodule dependencies from github, and builds all the library files you will need.  It also installs Xcode project templates in the default Xcode template location.
See the setup.md file for additional instructions. Xcode 4.2 or greater is a prerequisite for building the Salesforce Mobile SDK.  install.sh will check for this, and exit if the installed version of Xcode is incorrect. In addition, the Salesforce Mobile SDK requires iOS 5.0 or greater.  Building from the command line has been tested using ant 1.8.  Older versions may work, but we recommend using the latest version of ant.

**Users of Xcode earlier than 4.5 (iOS 6):** The iOS 6 development environment introduces a new processor architecture (armv7s), while removing support for another (armv6).  This makes libraries built for iOS 6 incompatible with earlier Xcode dev environments, without some further steps on the developer's part.

We have updated our libraries to support iOS 6.  If you do not want to update your Xcode environment to 4.5 yet, you'll need to remove support for armv6 (if it exists) in the SalesforceHybridSDK project (hybrid/SalesforceHybridSDK/SalesforceHybridSDK.xcodeproj), as well as your app's project configuration:

1. In Xcode, click on the Project at the top of the Project Navigator view.
2. Under the Project header, click the project/app name.
3. Select the Build Settings tab.
4. In the Architectures section at the top, if **armv6** is not listed in Valid Architectures, there are no further actions on your part.  Otherwise, double-click the "armv6 armv7" option in Valid Architectures.
5. Click on the armv6 item in the list, then click the '-' button at the bottom of the list.

You should now be compatible with the iOS 6 library builds.  Note that you're not losing anything by removing support for armv6 anyway, as that class of devices was never compatible with iOS 5, our baseline supported iOS SDK in the Salesforce Mobile SDK.

**Xcode 4.3 Users:** If you have not used the `xcode-select` tool to choose your version of Xcode at the command line, you may encounter the following error when running the install script:

```
xcode-select: Error: No Xcode folder is set. Run xcode-select -switch <xcode_folder_path> to set the path to the Xcode folder.
```

If you run `sudo xcode-select -switch /Applications/Xcode.app/Contents/Developer` at the command line, you should be able to run the install script without issues.  This assumes you installed Xcode in the Applications folder.

**Note:** When using the app templates to create your application, **make sure the "Use Automatic Reference Counting checkbox is NOT selected.** 

If you have problems building any of the projects, take a look at the online [FAQ](https://github.com/forcedotcom/SalesforceMobileSDK-iOS/wiki/FAQ) for troubleshooting tips.

Introduction
==

__What's New in 1.3__

**Cordova Library Updates**
The Salesforce Hybrid SDK has updated its PhoneGap/Cordova support to Cordova 1.8.1.  All plugins and infrastructure have been updated to Cordova patterns.

**Default SmartStore Encryption**
If an app does not implement user passcodes, its SmartStore data will be protected with a default encryption scheme.

**Better Offline Support for Authentication in Native Apps**
Native apps can now function offline if the user has authenticated at some point.  Once the device comes back online, the app will reconnect with the user's existing credentials.  (Hybrid apps already have this capability.)

__Version 1.2__

**Connected Apps Pilot**
* Apps implemented with the Mobile SDK will now respect Connected Apps policies.  Rules defined by administrators for PIN code protection and session timeout intervals will now be enforced by native and hybrid app implementations. (This feature requires the Connected Apps Pilot be turned on.)

**SmartStore Enhancements**
* Upsert records based on external id. SmartStore can now determine record uniqueness and perform the proper updates based on an id defined by the developer. This design is reflects the Salesforce REST API, making it easier to implement data synchronization.
* Mock SmartStore Implementation. Developers can build and test SmartStore apps directly in the desktop browser.
* Option to self-encrypt the SmartStore databases, which can be securely backed-up.

__Version 1.1__ 

**Secure Offline API** 
Store sensitive business data directly on a device with enterprise-class encryption for offline access. The Salesforce SDK provides a robust API for storing, retrieving, and querying  data without internet connectivity. 

**Flexible OAuth2 authentication flow** 
For hybrid apps, you now have the flexibility to configure whether or not your app needs to authenticate immediately when the app starts, or whether you'd prefer to defer authentication to a more convenient time in your app's lifecycle. 

**Blocks APIs for iOS** 
For native iOS developers, the REST API libraries have been updated to support a blocks-based callback interface, to make responding to asynchronous REST calls much easier.

__Version 1.0__
This is the first generally available release of Salesforce Mobile SDK for iOS that can be used to develop native and hybrid applications. The public facing APIs have been finalized. Due to the rapid pace of innovation of mobile operating systems, some of the APIs and modules may change in their implementation details, but should not have a direct impact on the application logic. All updates will be clearly communicated in advanced using github.  
Check out [Developer Force](http://developer.force.com/mobilesdk) for additional articles and tutorials.

__Native Applications__
The Salesforce Mobile SDK provides the essential libraries for quickly building native mobile apps that interact with the Salesforce cloud platform. The OAuth2 library abstracts away the complexity of securely storing the refresh token or fetching a new session id when it expires. The SDK also provides Objective-C wrappers for the Salesforce REST API, making it easy to retrieve and manipulate data.

__Hybrid Applications__
HTML5 is quickly emerging as a powerful technology for developing cross-platform mobile applications. While developers can create sophisticated apps with HTML5 and JavaScript alone, some vital limitations remain, specifically: session management, access to native device functionality like the camera, calendar and address book. The Salesforce Mobile Container (based on the industry leading PhoneGap implementation) makes it possible to embed HTML5 apps stored on the device or delivered via Visualforce inside a thin native container, producing a hybrid application.

Application Templates
==
The Mobile SDK provides Xcode templates for quickly constructing the foundation of native and hybrid applications with configurable Settings bundles for allowing the user to log-out of the app or switch between production and Sandbox orgs.


__Native App Template__
For native apps that need to accesses the Salesforce REST API, use the native template that includes a default AppDelegate implementation that you can customize to perform any app-specific interaction. 

__Hybrid App Template__
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
