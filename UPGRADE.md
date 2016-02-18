## Upgrade steps from v. 4.0.x to v. 4.1 for native/hybrid apps

To upgrade native and hybrid, we strongly recommend creating a new app from the app templates in [the forceios npm package](https://npmjs.org/package/forceios), then migrating the artifacts specific to your app into the new template. The other recommended approach would be to upgrade using [Cocoapods](https://cocoapods.org/pods/SalesforceMobileSDK-iOS). Read on if you prefer to update the Mobile SDK artifacts in your existing hybrid app.

### Hybrid 4.0.x to 4.1 upgrade

Upgrading your hybrid app from 4.0.x to 4.1 should be a simple matter of upgrading the Salesforce Cordova plugins themselves. This can be done by using the Cordova command-line tool to remove, then re-add the plugin:

        $ cd MyCordovaAppDir
        $ cordova plugin rm com.salesforce
        $ cordova plugin add https://github.com/forcedotcom/SalesforceMobileSDK-CordovaPlugin
        $ cordova prepare

See the [Mobile SDK Development Guide](https://github.com/forcedotcom/SalesforceMobileSDK-Shared/blob/master/doc/mobile_sdk.pdf?raw=true) for more information about developing hybrid apps with the 4.1 SDK and Cordova 3.9.2.

If you have questions, or encounter any issues, we'd love to hear from you. Post any feedback you have on our [Google+ Community](https://plus.google.com/communities/114225252149514546445).