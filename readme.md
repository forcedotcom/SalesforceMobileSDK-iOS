# Salesforce.com Mobile Container for iOS
Note: this is sample test page

Introduction
==
(todo)


Installation (Xcode 4 Project Template)
==

The easiest way to use the SalesforceSDK is to install the Xcode 4 project template: copy the directory `native/Force.com-based Application.xctemplate`
into `~/Library/Developer/Xcode/Templates/Project Templates/Application`

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

1. Open the Build Settings tab for the project.

  * Set __Other Linker Flags__ to `-ObjC -all_load`.

1. Open the Build Phases tab for the project main target and link against the following required frameworks:

	1. **CFNetwork.framework**
	1. **CoreData.framework**
	1. **MobileCoreServices.framework**
	1. **SystemConfiguration.framework**
	1. **Security.framework**
	1. **libxml2.dylib**

1. Import the SalesforceSDK header via ``#import "SFRestAPI.h"``.

1. Build the project to verify that the installation is successful.

1. Refer to the [SFRestAPI documentation](http://forcedotcom.github.com/MobileContainer-iOS/Documentation/SalesforceSDK/Classes/SFRestAPI.html) for some sample code to login into a salesforce instance and issue a REST API call.

Documentation
==

* [SalesforceSDK](http://forcedotcom.github.com/MobileContainer-iOS/Documentation/SalesforceSDK/index.html)
* [SalesforceOAuth](http://forcedotcom.github.com/MobileContainer-iOS/Documentation/SalesforceOAuth/index.html)
