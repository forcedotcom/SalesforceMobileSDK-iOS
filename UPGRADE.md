## Hybrid 1.4.5 to 1.5 upgrade
- Use the latest `SalesforceHybridSDK.framework`
- Update your Mobile SDK plugins and artifacts:
    - `SFHybridApp.js`
    - `SFSmartStorePlugin.js`
    - `SFTestRunnerPlugin.js`
    - `SalesforceOAuthPlugin.js`
    - `bootstrap.html` (The only change is the cordova.js reference)
- Add the `SalesforceSDKResources.bundle`, and make sure it's deployed with your app.  These are the localized resources that the Mobile SDK uses.  You can add your own localizations here as well, depending on what languages you choose to support.
- Cordova: Update your cordova.js to `cordova-2.3.0.js`
- Cordova: `Cordova.plist` has changed to `config.xml`, along with format changes.  You'll need to migrate to the new format.


## Native 1.4.5 to 1.5 upgrade
- Get the latest libSalesforceSDK from the dist/ folder
- Get the latest SalesforceCommonUtils from the dist/ folder
- Get the latest SalesforceOAuth from the dist/ folder
- Add the `SalesforceSDKResources.bundle`, and make sure it's deployed with your app.  These are the localized resources that the Mobile SDK uses.  You can add your own localizations here as well, depending on what languages you choose to support.
- `SFNativeRestAppDelegate.authViewController` has been deprecated.  You should override `[SFAuthenticationManager sharedManager].authViewController` instead.
- `SFNativeRestAppDelegate` no longer handles OAuth delegation directly.  Instead, it leverages the new `SFAuthenticationManager` class for managing authentication.  This may have an impact on your app, if you were overriding the OAuth or Identity delegate methods to do your own processing.  See SFAuthenticationManager for more details.
- You can now override `[SFNativeRestAppDelegate createSnapshotView]` to create a `UIView` that will be used as the screenshot that will be taken by iOS when the app is backgrounded.  By default, it's a white opaque view.  This view is for security purposes, so that sensitive data is not stored in the clear on the device when the app is backgrounded.