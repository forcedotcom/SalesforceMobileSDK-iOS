## 2.3 to 3.0 upgrade

To upgrade native and hybrid, we strongly recommend creating a new app from the app templates in [the forceios npm package](https://npmjs.org/package/forceios), then migrating the artifacts specific to your app into the new template.  Read on if you prefer to update the Mobile SDK artifacts in your existing app.

### Hybrid 2.3 to 3.0 upgrade

The 3.0 version of the Mobile SDK still supports a minimum Cordova version of 3.5, has been tested through Cordova 3.6.3, and is expected to work with Cordova 3.7.

Upgrading your hybrid app from 2.3 to 3.0 should be a simple matter of upgrading the Salesforce Cordova plugins themselves.  This can be done by using the Cordova command-line tool to remove, then re-add the plugin:

        $ cd MyCordovaAppDir
        $ cordova plugin rm com.salesforce
        $ cordova plugin add https://github.com/forcedotcom/SalesforceMobileSDK-CordovaPlugin
        $ cordova prepare

See the [Mobile SDK Development Guide](https://github.com/forcedotcom/SalesforceMobileSDK-Shared/blob/master/doc/mobile_sdk.pdf?raw=true) for more information about developing hybrid apps with the 3.0 SDK.

### Native 2.3 to 3.0 upgrade

#### Update the Mobile SDK library packages
The easiest way to do this is to delete everything in the Dependencies folder of your app's Xcode project, and then add the new libraries.

1. In your Xcode project, in Project Navigator, locate the Dependencies folder.  Control-click the folder, choose Delete, and select "Move to Trash".
2. Download the following binary packages from [the distribution repo](https://github.com/forcedotcom/SalesforceMobileSDK-iOS-Distribution):
    - MKNetworkKit-iOS-Release.zip
    - SalesforceRestAPI-Release.zip
    - SalesforceNetworkSDK-Release.zip
    - SalesforceOAuth-Release.zip
    - SalesforceSDKCore-Release.zip
    - SalesforceSecurity-Release.zip
    - SmartSync-Release.zip
3. Also, download the following folders from the ThirdParty folder link in the distribution repo, for placement in your Dependencies folder:
    - SalesforceCommonUtils
    - openssl
    - sqlcipher
4. Recreate the Dependencies folder, under your app folder.
5. Unzip the new packages from step 2, and copy the folders from step 3, into the Dependencies folder.
6. In Project Navigator, control-click your app folder and select 'Add Files to "*&lt;App Name&gt;*"...'.
7. Select the Dependencies folder, making sure that "Create groups for any added folder" is selected.
8. Click Add.

#### Updating app bootstrap process to SalesforceSDKManager
Starting with the 3.0 version of the SDK, much of the SDK bootstrapping process has been consolidated into the `SalesforceSDKManager` singleton class.  See the [Mobile SDK Development Guide](https://github.com/forcedotcom/SalesforceMobileSDK-Shared/blob/master/doc/mobile_sdk.pdf?raw=true) for a detailed look at how `SalesforceSDKManager` impacts the SDK bootstrapping process of your app.  Essentially, while you can more or less reuse any custom code that handles launch events, you will have to move it to slightly different contexts. The following list outlines the main areas where bootstrapping and configuration code has moved or changed.

- The configuration of your app's Connected App settings and OAuth scopes has moved:
    - `[SFUserAccountManager sharedInstance].oauthClientId` should be replaced with `[SalesforceSDKManager sharedManager].connectedAppId`.
    - `[SFUserAccountManager sharedInstance].oauthCompletionUrl` should be replaced with `[SalesforceSDKManager sharedManager].connectedAppCallbackUri`.
    - `[SFUserAccountManager sharedInstance].scopes` should be replaced with `[SalesforceSDKManager sharedManager].authScopes`.
- If your app authenticates at the beginning of your app launch process (the default behavior), replace your call to `[[SFAuthenticationManager sharedManager] loginWithCompletion:failure:]` as follows:
    - Replace your completion block by setting `[SalesforceSDKManager sharedManager].postLaunchAction`.
    - Replace your failure block by setting `[SalesforceSDKManager sharedManager].launchErrorAction`.
    - Replace your call to `loginWithCompletion:failure:` with `[[SalesforceSDKManager sharedManager] launch]`.
- If your app does *not* authenticate as part of your app's launch process, do the the following:
    - Set `[SalesforceSDKManager sharedManager].authenticateAtLaunch` to `NO` somewhere before calling `launch`.
    - Continue to call `[[SFAuthenticationManager sharedManager] loginWithCompletion:failure:]` at the appropriate time in your app lifecycle.
- Regardless of whether your app authenticates at app startup or not, your `AppDelegate` *must* call `[[SalesforceSDKManager sharedManager] launch]` in `application:didFinishLaunchingWithOptions:`.
- Your `AppDelegate` no longer needs to implement the `SFAuthenticationManagerDelegate` or `SFUserAccountManagerDelegate` protocols for bootstrapping events.
    - `[SFAuthenticationManagerDelegate authManagerDidLogout:]` has been replaced by the `[SalesforceSDKManager sharedManager].postLogoutAction` block.
    - `[SFUserAccountManagerDelegate userAccountManager:didSwitchFromUser:toUser:]` has been replaced by the `[SalesforceSDKManager sharedManager].switchUserAction` block.
- If you subscribed to the `SFAuthenticationManagerDelegate` methods for app event boundaries (`authManagerWillResignActive:`, `authManagerDidBecomeActive:`, `authManagerWillEnterForeground:`, `authManagerDidEnterBackground:`), you must now subscribe to the equivalent delegate methods of `SalesforceSDKManagerDelegate`.
- If you customized the snapshot view functionality of `SFAuthenticationManager` (`useSnapshotView`, `snapshotView`), move those customizations to the equivalent functionality in `SalesforceSDKManager`.
- If you overrode the `preferredPasscodeProvider` of `SFAuthenticationManager` (uncommon), move your customizations to `SalesforceSDKManager`.

## Upgrading from a previous version of the SDK?

See the [Mobile SDK Development Guide](https://github.com/forcedotcom/SalesforceMobileSDK-Shared/blob/master/doc/mobile_sdk.pdf?raw=true) for notes on upgrading from prior versions of the SDK.

