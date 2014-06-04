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

