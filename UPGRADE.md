## Upgrade steps from v. 5.2.x to v. 5.3 for native/hybrid/react native apps

To upgrade native, hybrid and react native apps, we strongly recommend creating a new app from the app templates in [the forceios npm package](https://npmjs.org/package/forceios), then migrating the artifacts specific to your app into the new template. The other recommended approach would be to upgrade using [Cocoapods](https://github.com/forcedotcom/SalesforceMobileSDK-iOS-Specs).

See the [Mobile SDK Development Guide](https://github.com/forcedotcom/SalesforceMobileSDK-Shared/blob/master/doc/mobile_sdk.pdf?raw=true) for more information about developing hybrid apps with the Mobile SDK and Cordova.

If you have questions, or encounter any issues, we'd love to hear from you. Post any feedback you have on our [Google+ Community](https://plus.google.com/communities/114225252149514546445).

Note: If you're upgrading from a previous version through CocoaPods, add the following line to your podfile.

pod 'FMDB', :git => 'https://github.com/forcedotcom/fmdb', :branch => '2.7.2_xcode9'

This is a temporary workaround until FMDB fully supports Xcode 9 and iOS 11 at which point this line will go away.
