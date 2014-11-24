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

### Native 2.2 to 2.3 upgrade

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

Please see the [Mobile SDK Development Guide](https://github.com/forcedotcom/SalesforceMobileSDK-Shared/blob/master/doc/mobile_sdk.pdf?raw=true) for notes on upgrading from prior versions of the SDK.

