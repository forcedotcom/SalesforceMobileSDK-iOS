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
