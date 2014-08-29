## 2.2 to 2.3 upgrade

To upgrade native and hybrid, we strongly recommend creating a new app from the app templates in [the forceios npm package](https://npmjs.org/package/forceios), then migrating the artifacts specific to your app into the new template.  Read on if you prefer to update the Mobile SDK artifacts in your existing app.

### Hybrid 2.2 to 2.3 upgrade

The 2.3 version of the Mobile SDK uses Cordova 3.5, which represents both a significant upgrade from the previous Cordova 2.3, and a signficant change in how you bootstrap your application.  Please follow the instructions below to migrate your hybrid app to the Cordova 3.5 paradigm.

#### Prerequisites
- You will need to install the `cordova` command line tool from [https://www.npmjs.org/package/cordova](https://www.npmjs.org/package/cordova).  The `forceios` package depends on the `cordova` tool to create hybrid apps.  Make sure you have version 3.5 or greater installed.
- You will also need to install the `forceios` npm package from [https://www.npmjs.org/package/forceios](https://www.npmjs.org/package/forceios), to create your new hybrid app.

#### Create your new hybrid app
Follow the instructions in the [forceios package](https://www.npmjs.org/package/forceios) to create your new hybrid app.  You'll choose either a `hybrid_remote` or `hybrid_local` app, depending on the type of hybrid app you've developed.

#### Migrate your old app artifacts to the new project
1. Once you've created your new app, `cd` into the top level folder of the new app you've created.
2. Run `cordova plugin add [Cordova plugin used in your app]` for every plugin that your app uses.  **Note:** You do not need to do this for the Mobile SDK plugins, as the `forceios` app creation process will automatically add those plugins to your app.
3. Remove everything from the `www/` folder, and replace its contents with all of your HTML, CSS, (non-Cordova) JS files, and `bootconfig.json` from your old app.  Basically, copy everything from your old `www/` folder except for the Cordova and Cordova plugin JS files.  Cordova is responsible for pushing all of the Cordova-specific JS files, plugin files, etc., into your www/ folder when the app is deployed (see below).
4. For any of your HTML pages that reference the Cordova JS file, make sure to change the declaration to `<script src="cordova.js"></script>`, i.e. the generic version of the Cordova JS file.  The Cordova framework now handles the versioning of this file.
5. Remove any `<script src="[Some Plugin JS File]"></script>` references in your HTML files.  Cordova is responsible for handling the inclusion of the proper plugin JS files in your app.
6. Make sure that any calls in your code to `cordova.require()` do not happen before Cordova's `deviceready` event has fired.
7. The naming convention for our Cordova plugins has changed, to reflect the new conventions used in Cordova 3.5.  Specifically, dot separation has replaced '/' separation for namespacing.  For example, if your app previously called `cordova.require('salesforce/util/logger')`, you would now call that via `cordova.require('com.salesforce.util.logger')`.  Generally:
    - Replace `salesforce` with `com.salesforce`.
    - Replace '/' with '.'
8. Run `cordova prepare`, to stage the changes into your app project(s).  Generally speaking, you'll run `cordova prepare` after any changes made to your app code, and Cordova will stage all of the appropriate changes into your app project(s).

You should now be able to access your new app project at `platforms/ios/[Project Name].xcodeproj`.

Please see the [Mobile SDK Development Guide](https://github.com/forcedotcom/SalesforceMobileSDK-Shared/blob/master/doc/mobile_sdk.pdf?raw=true) for more information about developing hybrid apps with the 2.3 SDK and Cordova 3.5.

## 2.1 to 2.2 upgrade

To upgrade native and hybrid, we strongly recommend creating a new app from the app templates in [the forceios npm package](https://npmjs.org/package/forceios), then migrating the artifacts specific to your app into the new template.  Read on if you prefer to update the Mobile SDK artifacts in your existing app.

### Hybrid 2.1 to 2.2 upgrade

#### Update the Mobile SDK library packages
The easiest way to do this is delete everything in the Dependencies folder of your app's Xcode project, and then add the new libraries.

1. In your Xcode project, in Project Navigator, locate the Dependencies folder.  Control-click the folder, choose Delete, and select "Move to Trash".
2. Download the following binary packages from [the distribution repo](https://github.com/forcedotcom/SalesforceMobileSDK-iOS-Distribution):
    - Cordova/Cordova-Release.zip
    - SalesforceHybridSDK-Release.zip
    - SalesforceOAuth-Release.zip
    - SalesforceSDKCore-Release.zip
    - SalesforceSecurity-Release.zip
3. Also, download the following folders from the ThirdParty folder link in the distribution repo, for placement in your Dependencies folder:
    - SalesforceCommonUtils
    - openssl
    - sqlcipher
4. Recreate the Dependencies folder, under your app folder.
5. Unzip the new packages from step 2, and copy the folders from step 3, into the Dependencies folder.
6. In Project Navigator, control-click your app folder and select 'Add Files to "*&lt;App Name&gt;*"...'.
7. Select the Dependencies folder, making sure that "Create groups for any added folder" is selected.
8. Click Add.

#### Add SalesforceSecurity header search path
1. Click your project in Project Navigator.
2. Select the Build Settings tab of your main target.
3. Scroll down to (or search/filter for) Header Search Paths.
4. Add the following search path:
    - $(SRCROOT)/*[App Name]*/Dependencies/SalesforceSecurity/Headers

#### Update hybrid local artifacts
For your hybrid "local" apps, replace the following files in the www/ folder of your app with the new versions from the libs folder of the [SalesforceMobileSDK-Shared repo](https://github.com/forcedotcom/SalesforceMobileSDK-Shared):

- cordova.force.js
- forcetk.mobilesdk.js
- smartsync.js

#### Update AppDelegate
Some of the APIs around user management have changed, as well as the patterns for handling logout and login host change events.  It is highly recommended that you consult the AppDelegate code from a new version of a forceios hybrid app, to see the changes.  At a high level, the changes are:

- Logout and login host change notifications have moved into delegate methods.  Your AppDelegate should implement the `SFAuthenticationManagerDelegate` and `SFUserAccountManagerDelegate` delegates, specifically:
    - `[SFAuthenticationManagerDelegate authManagerDidLogout:]` for user logout.
    - `[SFUserAccountManagerDelegate userAccountManager:didSwitchFromUser:toUser:]` for login host changes, which effectively changes users now.

### Native 2.1 to 2.2 upgrade

#### Update the Mobile SDK library packages
The easiest way to do this is to delete everything in the Dependencies folder of your app's Xcode project, and then add the new libraries.

1. In your Xcode project, in Project Navigator, locate the Dependencies folder.  Control-click the folder, choose Delete, and select "Move to Trash".
2. Download the following binary packages from [the distribution repo](https://github.com/forcedotcom/SalesforceMobileSDK-iOS-Distribution):
    - MKNetworkKit-iOS-Release.zip
    - SalesforceNativeSDK-Release.zip
    - SalesforceNetworkSDK-Release.zip
    - SalesforceOAuth-Release.zip
    - SalesforceSDKCore-Release.zip
    - SalesforceSecurity-Release.zip
3. Also, download the following folders from the ThirdParty folder link in the distribution repo, for placement in your Dependencies folder:
    - SalesforceCommonUtils
    - openssl
    - sqlcipher
4. Recreate the Dependencies folder, under your app folder.
5. Unzip the new packages from step 2, and copy the folders from step 3, into the Dependencies folder.
6. In Project Navigator, control-click your app folder and select 'Add Files to "*&lt;App Name&gt;*"...'.
7. Select the Dependencies folder, making sure that "Create groups for any added folder" is selected.
8. Click Add.

#### Add SalesforceSecurity header search path
1. Click your project in Project Navigator.
2. Select the Build Settings tab of your main target.
3. Scroll down to (or search/filter for) Header Search Paths.
4. Add the following search path:
    - $(SRCROOT)/*[App Name]*/Dependencies/SalesforceSecurity/Headers

#### Move to SalesforceSecurity class references
SalesforceSecurity is a new library in 2.2, and many of the security-related classes—particularly classes related to passcode management—have moved into this class from SalesforceSDKCore.  If you have code that referenced passcode-related functionality from SalesforceSDKCore, you'll want to update your references to their SalesforceSecurity counterparts.

#### Update AppDelegate
Some of the APIs around user management have changed, as well as the patterns for handling logout and login host change events.  It is highly recommended that you consult the AppDelegate code from a new version of a forceios native app, to see the changes.  At a high level, the changes are:

- Specifying your Connected App configuration is done through `SFUserAccountManager` now, where it was done through `SFAccountManager` in 2.1.  Make the following changes:
    - Instead of using `[SFAccountManager setClientId:]`, use `[SFUserAccountManager sharedInstance].oauthClientId`
    - `[SFAccountManager setRedirectUri:]` is set using `[SFUserAccountManager sharedInstance].oauthCompletionUrl`
    - Setting scopes goes from `[SFAccountManager setScopes:]` to `[SFUserAccountManager sharedInstance].scopes`
- Logout and login host change notifications have moved into delegate methods.  Your AppDelegate should implement the `SFAuthenticationManagerDelegate` and `SFUserAccountManagerDelegate` delegates, specifically:
    - `[SFAuthenticationManagerDelegate authManagerDidLogout:]` for user logout.
    - `[SFUserAccountManagerDelegate userAccountManager:didSwitchFromUser:toUser:]` for login host changes, which effectively changes users now.

## 2.0 to 2.1 upgrade

To upgrade native and hybrid, we strongly recommend creating a new app from the app templates in [the forceios npm package](https://npmjs.org/package/forceios), then migrating the artifacts specific to your app into the new template.  Read on if you prefer to update the Mobile SDK artifacts in your existing app.

### Hybrid 2.0 to 2.1 upgrade

#### Update the Mobile SDK library packages
The easiest way to do this is delete everything in the Dependencies folder of your app's Xcode project, and then add the new libraries.

1. In your Xcode project, in Project Navigator, locate the Dependencies folder.  Control-click the folder, choose Delete, and select "Move to Trash".
2. Download the following binary packages from [the distribution repo](https://github.com/forcedotcom/SalesforceMobileSDK-iOS-Distribution):
    - Cordova/Cordova-Release.zip
    - SalesforceHybridSDK-Release.zip
    - SalesforceOAuth-Release.zip
    - SalesforceSDKCore-Release.zip
3. Also, download the following folders from the ThirdParty folder link in the distribution repo, for placement in your Dependencies folder:
    - SalesforceCommonUtils
    - openssl
    - sqlcipher
4. Recreate the Dependencies folder, under your app folder.
5. Unzip the new packages from step 2, and copy the folders from step 3, into the Dependencies folder.
6. In Project Navigator, control-click your app folder and select 'Add Files to "*&lt;App Name&gt;*"...'.
7. Select the Dependencies folder, making sure that "Create groups for any added folder" is selected.
8. Click Add.

#### Update header search paths
Update the header search paths of your project in Xcode:

1. Click your project in Project Navigator.
2. Select the Build Settings tab of your main target.
3. Scroll down to (or search/filter for) Header Search Paths.
4. Add the following search paths:
    - $(SRCROOT)/*[App Name]*/Dependencies/SalesforceSDKCore/Headers
    - $(SRCROOT)/*[App Name]*/Dependencies/SalesforceOAuth/Headers
    - $(SRCROOT)/*[App Name]*/Dependencies/SalesforceCommonUtils/Headers
    - $(SRCROOT)/*[App Name]*/Dependencies/SalesforceHybridSDK/Headers

#### Update hybrid local artifacts
For your hybrid "local" apps, replace the following files in the www/ folder of your app with the new versions from the libs folder of the [SalesforceMobileSDK-Shared repo](https://github.com/forcedotcom/SalesforceMobileSDK-Shared):

- cordova.force.js
- forcetk.mobilesdk.js
- smartsync.js
    
### Native 2.0 to 2.1 upgrade

#### Update the Mobile SDK library packages
The easiest way to do this is to delete everything in the Dependencies folder of your app's Xcode project, and then add the new libraries.

1. In your Xcode project, in Project Navigator, locate the Dependencies folder.  Control-click the folder, choose Delete, and select "Move to Trash".
2. Download the following binary packages from [the distribution repo](https://github.com/forcedotcom/SalesforceMobileSDK-iOS-Distribution):
    - MKNetworkKit-iOS-Release.zip
    - SalesforceNativeSDK-Release.zip
    - SalesforceNetworkSDK-Release.zip
    - SalesforceOAuth-Release.zip
    - SalesforceSDKCore-Release.zip
3. Also, download the following folders from the ThirdParty folder link in the distribution repo, for placement in your Dependencies folder:
    - SalesforceCommonUtils
    - openssl
    - sqlcipher
4. Recreate the Dependencies folder, under your app folder.
5. Unzip the new packages from step 2, and copy the folders from step 3, into the Dependencies folder.
6. In Project Navigator, control-click your app folder and select 'Add Files to "*&lt;App Name&gt;*"...'.
7. Select the Dependencies folder, making sure that "Create groups for any added folder" is selected.
8. Click Add.

#### Update header search paths
Update the header search paths of your project in Xcode:

1. Click your project in Project Navigator.
2. Select the Build Settings tab of your main target.
3. Scroll down to (or search/filter for) Header Search Paths.
4. Add the following search paths:
    - $(SRCROOT)/*[App Name]*/Dependencies/SalesforceSDKCore/Headers
    - $(SRCROOT)/*[App Name]*/Dependencies/SalesforceOAuth/Headers
    - $(SRCROOT)/*[App Name]*/Dependencies/SalesforceNetworkSDK/Headers
    - $(SRCROOT)/*[App Name]*/Dependencies/SalesforceCommonUtils/Headers
    - $(SRCROOT)/*[App Name]*/Dependencies/SalesforceNativeSDK/Headers

#### Native SDK network library changes
In 2.1, the Mobile SDK has replaced RestKit with MKNetworkKit as the network library for native apps.  MKNetworkKit is wrapped by the new SalesforceNetworkSDK library, which in turn is wrapped by the `SFRestAPI` class and its supporting classes.  Most of the interfaces remain the same.  Some notable changes include:

- REST requests are now automatically initiated on background threads, and their responses will be returned to your delegate on the same thread as the request.  This means that if you plan to do UI-related updates from your delegate methods, you need to explicitly ensure that such code runs on the main thread, via `dispatch_async(dispatch_get_main_queue(), ^{ })` or a similar construct.
- `[SFRestAPI sharedInstance].rkClient` no longer exists.
- `[SFRestAPI send:delegate:]` now returns the new `SFNetworkOperation` associated with the request.
- `SFRestRequest.networkOperation` points to the underlying `SFNetworkOperation` object associated with the request.

If your app was using any of the underlying RestKit members for networking, you'll need to look at the equivalent functionality in MKNetworkKit and the SalesforceNetworkSDK.

