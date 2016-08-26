## Upgrade steps from v. 4.2.x to v. 4.3 for native/hybrid apps

To upgrade native and hybrid, we strongly recommend creating a new app from the app templates in [the forceios npm package](https://npmjs.org/package/forceios), then migrating the artifacts specific to your app into the new template. The other recommended approach would be to upgrade using [Cocoapods](https://github.com/forcedotcom/SalesforceMobileSDK-iOS-Specs). Read on if you prefer to update the Mobile SDK artifacts in your existing hybrid app.

### Hybrid 4.2.x to 4.3 upgrade

Upgrading your hybrid app from 4.2.x to 4.3 should be a simple matter of upgrading the Salesforce Cordova plugins themselves. This can be done by using the Cordova command-line tool to remove, then re-add the plugin:

        $ cd MyCordovaAppDir
        $ cordova plugin rm com.salesforce
        $ cordova plugin add https://github.com/forcedotcom/SalesforceMobileSDK-CordovaPlugin
        $ cordova prepare

See the [Mobile SDK Development Guide](https://github.com/forcedotcom/SalesforceMobileSDK-Shared/blob/master/doc/mobile_sdk.pdf?raw=true) for more information about developing hybrid apps with the 4.3 SDK and Cordova 4.2.0.

If you have questions, or encounter any issues, we'd love to hear from you. Post any feedback you have on our [Google+ Community](https://plus.google.com/communities/114225252149514546445).