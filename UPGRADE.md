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

- `[SFRestAPI sharedInstance].rkClient` no longer exists.
- `[SFRestAPI send:delegate:]` now returns the new `SFNetworkOperation` associated with the request.
- `SFRestRequest.networkOperation` points to the underlying `SFNetworkOperation` object associated with the request.

If your app was using any of the underlying RestKit members for networking, you'll need to look at the equivalent functionality in MKNetworkKit and the SalesforceNetworkSDK.


## 1.5 to 2.0 upgrade
As with all upgrades, for the upgrade to 2.0 you have essentially two choices for upgrading your existing app:

1. Start with the 2.0 version of the template app associated your app type (native, hybrid), and move your code and artifacts over into the new app.
2. Bring the new SDK artifacts into your existing app.

For 2.0, it's strongly recommended that you opt for the first approach.  Even if you opt for the second approach, you will likely want to create a sample app anyway, to see the change of work flow in the AppDelegate.  That's because for native and hybrid, the parent app delegate classes—`SFNativeRestAppDelegate` and `SFContainerAppDelegate`, respectively—have gone away, and the app's `AppDelegate` is now solely responsible for orchestrating the startup process.

For hybrid, processing of the hybrid configuration for the bootstrap process has moved to the native side as well, so you'll want to see how `SFHybridViewController` is now configured (also observable from AppDelegate for the hybrid template app).

The new app templates are now available through [the forceios npm package](https://npmjs.org/package/forceios).  To install the templates, you'll need to first install [node.js](http://nodejs.org/).  See the forceios README at npmjs.org for more information on installing the templates and creating apps from them.

### Hybrid 1.5 to 2.0 upgrade
- As mentioned above, even if you're not porting your previous contents into a 2.0 application shell, it's still advisable to create a new hybrid app from the template, to follow along.
- Remove `SalesforceHybridSDK.framework`, as it has been replaced.
- Update your Mobile SDK library and resource dependencies, from the [SalesforceMobileSDK-iOS-Package repo](https://github.com/forcedotcom/SalesforceMobileSDK-iOS-Package).  These will be net new additions to your application from the 1.5 release.
    - SalesforceHybridSDK (in the Dependencies/ folder)
    - SalesforceOAuth (in the Dependencies/ folder)
    - SalesforceSDKCore (in the Dependencies/ folder)
    - SalesforceSDKResources.bundle (in the Dependencies/ folder)
    - Cordova (in the Dependencies/Cordova/ folder)
    - SalesforceCommonUtils (in the Dependencies/ThirdParty/SalesforceCommonUtils folder)
    - openssl (libcrypto.a and libssl.a, in the Dependencies/ThirdParty/openssl folder)
    - sqlcipher (in the Dependencies/ThirdParty/sqlcipher folder)
    - libxml2.dylib (System library)
- Update your hybrid dependencies in your app's www/ folder.  **Note:** If your app is a Visualforce app, only the bootconfig change below is required.  The hybrid app will not use any of the other files.
    - Migrate your bootconfig.js configuration to the new bootconfig.json format
    - Remove SalesforceOAuthPlugin.js, SFHybridApp.js, SFSmartStorePlugin.js, and forcetk.js
    - If you're not using them, you can remove SFTestRunnerPlugin.js, qunit.css, and qunit.js
    - Add cordova.force.js (in the HybridShared/libs/ folder)
    - If using forceTk, add forcetk.mobilesdk.js (in the HybridShared/libs/ folder)
    - If using jQuery, update jQuery (in the HybridShared/external/ folder)
    - If you'd like to use the new entity framework:
        - Add force.entity.js (in the HybridShared/libs/ folder)
        - Add backbone-1.0.0.min.js and underscore-1.4.4.min.js (in the HybridShared/external/backbone/ folder)
        - Add jQuery (if you didn't already, in the HybridShared/external/jquery/ folder)
- Update your AppDelegate — Generally speaking, make your AppDelegate.h and AppDelegate.m files conform to the new design patterns, or copy the new template app's files over the old ones, if you've never made changes to your AppDelegate.  The following are some key points:
    - In AppDelegate.h, AppDelegate should no longer inherit from SFContainerAppDelegate.
    - There's a new SFHybridViewController "viewController" property.
    - In AppDelegate.m, AppDelegate now has primary responsibility for navigating the bootstrapping/auth flow, as well as boundary events when the user logs out, or switches login hosts.

### Native 1.5 to 2.0 upgrade
- As mentioned above, even if you're not porting your previous contents into a 2.0 application shell, it's still advisable to create a new native app from the template, to follow along.
- Update your Mobile SDK library and resource dependencies, from the [SalesforceMobileSDK-iOS-Package repo](https://github.com/forcedotcom/SalesforceMobileSDK-iOS-Package).
    - Remove SalesforceSDK
    - Add SalesforceNativeSDK (in the Dependencies/ folder)
    - Add SalesforceSDKCore (in the Dependencies/ folder)
    - Update SalesforceOAuth (in the Dependencies/ folder)
    - Update SalesforceSDKResources.bundle (in the Dependencies/ folder)
    - Update RestKit (in the Dependencies/ThirdParty/RestKit/ folder)
    - Update SalesforceCommonUtils (in the Dependencies/ThirdParty/SalesforceCommonUtils folder)
    - Update openssl (libcrypto.a and libssl.a, in the Dependencies/ThirdParty/openssl folder)
    - Update sqlcipher (in the Dependencies/ThirdParty/sqlcipher folder)
- Update your AppDelegate — Generally speaking, make your AppDelegate.h and AppDelegate.m files conform to the new design patterns.  The following are some key points:
    - In AppDelegate.h, AppDelegate should no longer inherit from SFNativeRestAppDelegate.
    - In AppDelegate.m, AppDelegate now has primary responsibility for navigating the auth flow and root view controller staging, as well as boundary events when the user logs out, or switches login hosts.  **Note:** The design patterns in the new AppDelegate are just suggestions.  There is no longer a requirement to follow a specific flow; use an authentication flow (with the updated `SFAuthenticationManager` singleton) that suits your needs, relative to your app startup and boundary use cases.
    - The only prerequisites for using authentication are the `SFAccountManager` configuration settings at the top of `[AppDelegate init]`.  Make sure to make those settings conform to the specifics of your Connected App.  The only requirement for this configuration is that it is set before the first call to `[SFAuthenticationManager loginWithCompletion:failure:]`.
