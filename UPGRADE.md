## Upgrade steps from v. 7.0 to v. 7.1 for Native apps

To upgrade native apps, we strongly recommend creating a new app from the app templates in [the forceios npm package](https://npmjs.org/package/forceios), then migrating the artifacts specific to your app into the new template.

For Swift, SmartSync Data Framework requires a few code changes. These changes result from enhanced error handling in some Objective-C methods. Because the Swift methods derive from these new Objective-C versions, they can now throw. Add try statements around calls to these sync methods:

```
open func syncDown(target: SyncDownTarget, options: SyncOptions, soupName: String, syncName: String?, onUpdate updateBlock: *@escaping* SyncUpdateBlock) throws -> SyncState

open func syncUp(target: SyncUpTarget, options: SyncOptions, soupName: String, syncName: String?, onUpdate updateBlock: *@escaping* SyncUpdateBlock) throws -> SyncState

open func reSync(id syncId: NSNumber, onUpdate updateBlock: @escaping SyncUpdateBlock) throws -> SyncState

open func reSync(named syncName: String, onUpdate updateBlock: @escaping SyncUpdateBlock) throws -> SyncState

open func cleanResyncGhosts(forId syncId: NSNumber, onComplete completionStatusBlock: @escaping SyncCompletionBlock) throws
```

See the [Mobile SDK Development Guide](https://github.com/forcedotcom/SalesforceMobileSDK-Shared/blob/master/doc/mobile_sdk.pdf?raw=true) for more information.

If you have questions, or encounter any issues, we'd love to hear from you. Post any feedback you have on [Salesforce StackExchange](https://salesforce.stackexchange.com/questions/tagged/mobilesdk).
