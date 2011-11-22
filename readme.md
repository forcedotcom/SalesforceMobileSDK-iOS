# Salesforce.com Mobile SDK for iOS
Installation
==
After cloning the SalesforceMobileSDK-iOS project from github, run the install script from the Terminal command line:

`./install.sh`

This pulls submodule dependencies from github, and builds all the library files you will need.  It also installs Xcode project templates in the default Xcode template location.
See the setup.md file for additional instructions. 


Introduction
==
__Version 1.0__
This is the first full-fledged general release of Salesforce Mobile SDK for iOS. The public APIs may change in their implementation details going forward, but are less likely to change in classes, method signatures, and so forth.

__Native Mobile Libraries__
The Salesforce Mobile SDK provides essential libraries for quickly building native or hybrid mobile apps that seamlessly integrate with the Salesforce cloud architecture.  Out of the box, we provide an implementation of OAuth2, abstracting away the complexity of securely storing refresh tokens or fetching a new session ID when a session expires. The SDK also provides Objective-C wrappers for the Salesforce REST API, making it easy to retrieve, store, and manipulate data.

__Salesforce Mobile Container__
HTML5 is quickly emerging as dominant technology for developing cross-platform mobile applications. While developers can create sophisticated apps with HTML5 and JavaScript, some limitations remain, specifically: session management, access to the camera and address book, and the inability to distribute apps inside public App Stores. The Salesforce Mobile Container makes possible to combine the ease of web app development with power of the iOS platform by wrapping a web app inside a thin native container, producing a hybrid application.

__Hybrid App Template__
The SDK provides an Xcode template for creating a new hybrid app (native+HTML5) that either accesses the Salesforce REST API or accesses a Visualforce page that you have previously set up in your org.  The hybrid app template also includes the SalesforceOAuthPlugin for PhoneGap, which provides access to OAuth directly from javascript in your hybrid apps.  In addition, the hybrid app template provides a Settings bundle that allows the user to initiate logout or switch between Production and Sandbox orgs from the system Settings app.

__Native App Template__
The SDK provides an Xcode template for creating a new native iOS app that accesses the Salesforce REST API.  This template includes a default AppDelegate implementation that you can customize to perform any app-specific interaction. In addition, the native app template provides a Settings bundle that allows the user to initiate logout or switch between Production and Sandbox orgs from the system Settings app.


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

4. Import the SalesforceSDK header via ``#import "SFRestAPI.h"``.

5. Build the project to verify that the installation is successful.

6. Refer to the [SFRestAPI documentation](http://forcedotcom.github.com/MobileContainer-iOS/Documentation/SalesforceSDK/Classes/SFRestAPI.html) for some sample code to login into a salesforce instance and issue a REST API call.


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

**Note:** The sample applications currently have SBJson as a dependency.  This is because this version of the SalesforceSDK supports iOS 4.3.
In the near future we intend to deprecate iOS 4.3 in favor of iOS 5.0, where we can eliminate the SBJson dependency in favor of builtin iOS 5.0
features. _You may also choose to eliminate the SBJson dependency if your app targets iOS 5.0+._

Documentation
==

* [SalesforceSDK](http://forcedotcom.github.com/SalesforceMobileSDK-iOS/Documentation/SalesforceSDK/index.html)
* [SalesforceOAuth](http://forcedotcom.github.com/SalesforceMobileSDK-iOS/Documentation/SalesforceOAuth/index.html)


Discussion
==

If you would like to make suggestions, have questions, or encounter any issues, we'd love to hear from you.  Post any feedback you have to the [Mobile Community Discussion Board](http://boards.developerforce.com/t5/Mobile/bd-p/mobile) on developerforce.com.
