# Salesforce.com Mobile SDK for iOS
__Developer Preview__
The code, sample applications, and documentation offered in this repository represent a preview of more full-fledged functionality to come.  In the lead-up to a general release, the public APIs may change from their current representation and implementation details.


Introduction
==
__Native Mobile Libraries__
The Salesforce Mobile SDK provides essential libraries for quickly building native or hybrid mobile apps that seamlessly integrate with the Salesforce cloud architecture.  Out of the box, we provide an implementation of the OAuth2 protocol, abstracting away the complexity of securely storing tokens or fetching refresh tokens when a session expires. The SDK also provides ObjectiveC REST API wrappers, making it easy to retrieve, store, and manipulate data.




__Salesforce Mobile Container__
HTML5 is quickly emerging as dominant technology for developing cross-platform mobile applications. While developers can create sophisticated apps with HTML5 and JavaScript, some limitations remain, specifically: session management, access to the camera and address book, and the inability to distribute apps inside public App Stores. The Salesforce Mobile Container makes possible to combine the ease of web app development with power of the iOS platform by wrapping a web app inside a thin native container, producing a hybrid application.





Installation (Xcode 4 Project Template)
==

The easiest way to use the SalesforceSDK is to install the Xcode 4 project template:

`cp -R native/Force.com-based\ Application.xctemplate ~/Library/Developer/Xcode/Templates/Project\ Templates/Application/`


This allows you to create new projects of type __Force.com-based Application__ directly from Xcode.


Using the SDK (in a Force.com project)
==

Create a new Force.com project. These 3 parameters are required:

1. **Consumer Public Key**: The consumer key from your remote access provider.
1. **OAuth Redirect URL**: The URL used by OAuth to handle the callback.
1. **Force.com Login URL**: The Force.com login domain URL. Typically `login.salesforce.com`.


After creating the project, you will need to:

1. Open the Build Settings tab for the project.

  * Set __Other Linker Flags__ to `-ObjC -all_load`

1. Open the Build Phases tab for the project main target and link against the following required framework:

  * **libxml2.dylib**

You should then be able to compile and run the sample project. It's a simple project which logs you into 
a salesforce instance via oauth, issues a 'select Name from Account' query and displays the result in a UITableView.


Using the SDK (in an existing project)
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


Working with the hybrid sample apps
==

The sample applications contained under the hybrid/ folder are designed around the [PhoneGap SDK](http://www.phonegap.com/), also known as [callback-ios](https://github.com/callback/callback-ios).  

Before you can work with those applications, you will need to ensure that you've updated the submodules for the SalesforceSDK project.  
See the setup.md file for instructions on using `git submodule` to grab the correct PhoneGap libraries.

You can find more detailed installation instructions, as well as documentation for working with the PhoneGap SDK, in the [Getting Started Guide](http://www.phonegap.com/start).

**Note:** The hybrid sample applications are configured to look for the PhoneGap iOS Framework in their dependencies folder. To find out if the PhoneGap framework is properly linked in a sample project, take the following action:

1. Open the project in Xcode.
2. In Project Navigator, expand the dependencies folder.
3. If PhoneGap.framework is listed among the dependencies , your project should be fine, and no further action should be necessary. 

If you do not see the PhoneGap framework, or otherwise get compilation errors related to the PhoneGap Framework not being found (e.g. 'Undefined symbols for architecture i386: "\_OBJC\_METACLASS\_$\_PhoneGapDelegate"'), you will need to add the PhoneGap Framework to the sample project:

1. Open the Xcode project of the sample application.
2. In the Project Navigator, right-click or control-click the Frameworks folder, and select 'Add files to "_Project Name_..."'.
3. Navigate to the Phonegap.framework folder (the default location is /Users/Shared/PhoneGap/Frameworks/PhoneGap.framework/), and click "Add".

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
