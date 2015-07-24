## 3.2 to 3.3 upgrade

To upgrade native and hybrid, we strongly recommend creating a new app from the app templates in [the forceios npm package](https://npmjs.org/package/forceios), then migrating the artifacts specific to your app into the new template.  The other recommended approach would be to upgrade using [Cocoapods](https://cocoapods.org/pods/SalesforceMobileSDK-iOS).  Read on if you prefer to update the Mobile SDK artifacts in your existing app.

NOTE: Starting with our 3.2 release, we don't use MKNetworkKit and SalesforceNetworkSDK as our networking libraries.  Instead, we use SalesforceNetwork as our library for networking.  If you use MKNetworkKit APIs directly, you will need to replace those calls with equivalent API calls in our new library.

### Hybrid 3.2 to 3.3 upgrade

The 3.3 version of the Mobile SDK still supports a minimum Cordova version of 3.5, has been tested through Cordova 3.6.3, and is expected to work with Cordova 3.7.

Upgrading your hybrid app from 3.2 to 3.3 should be a simple matter of upgrading the Salesforce Cordova plugins themselves.  This can be done by using the Cordova command-line tool to remove, then re-add the plugin:

        $ cd MyCordovaAppDir
        $ cordova plugin rm com.salesforce
        $ cordova plugin add https://github.com/forcedotcom/SalesforceMobileSDK-CordovaPlugin
        $ cordova prepare

See the [Mobile SDK Development Guide](https://github.com/forcedotcom/SalesforceMobileSDK-Shared/blob/master/doc/mobile_sdk.pdf?raw=true) for more information about developing hybrid apps with the 3.2 SDK.

### Native 3.2 to 3.3 upgrade

#### Apple prerequisites for Mobile SDK 3.3
- iOS 7.0 is a requirement for using the 3.3 version of the SDK.  Your app is not guaranteed to work with earlier versions of iOS.
- Xcode 6 is the minimum version of Xcode required to work with the SDK.  Backward compatibility is not guaranteed for earlier versions of Xcode.

#### Update the Mobile SDK library packages
The easiest way to do this is to delete everything in the Dependencies folder of your app's Xcode project, and then add the new libraries.

1. In your Xcode project, in Project Navigator, locate the Dependencies folder.  Control-click the folder, choose Delete, and select "Move to Trash".
2. Download the following binary packages from [the distribution repo](https://github.com/forcedotcom/SalesforceMobileSDK-iOS-Distribution):
    - SalesforceRestAPI-Release.zip
    - SalesforceNetwork-Release.zip
    - SalesforceOAuth-Release.zip
    - SalesforceSDKCore-Release.zip
    - SalesforceSecurity-Release.zip
    - SmartSync-Release.zip
    - SalesforceSDKCommon-Release.zip
3. Also, download the following folders from the ThirdParty folder link in the distribution repo, for placement in your Dependencies folder:
    - SalesforceCommonUtils
    - openssl
    - sqlcipher
4. Recreate the Dependencies folder, under your app folder.
5. Unzip the new packages from step 2, and copy the folders from step 3, into the Dependencies folder.
6. In Project Navigator, control-click your app folder and select 'Add Files to "*&lt;App Name&gt;*"...'.
7. Select the Dependencies folder, making sure that "Create groups for any added folder" is selected.
8. Click Add.

## Upgrading from a previous version of the SDK?

See the [Mobile SDK Development Guide](https://github.com/forcedotcom/SalesforceMobileSDK-Shared/blob/master/doc/mobile_sdk.pdf?raw=true) for notes on upgrading from prior versions of the SDK.
