Mobile SDK enhances its Swift offering with PromiseKit adaptations. You can now use promises for these SDK components:

* [SalesforceSwiftSDKManager](Classes/SalesforceSwiftSDKManager.html)
* [SFRestAPI](Extensions/SFRestAPI.html)
* [SFSmartStoreClient](Classes/SFSmartStoreClient.html)
* [SFSmartSyncSyncManager](Extensions/SFSmartSyncSyncManager.html)
* [SFUserAccountManager](Extensions/SFUserAccountManager.html)

Promises make coding asynchronous APIs simple and readable. Instead of jumping back into Objective-C to use nested block handlers, you simply define the callbacks as inline extensions of the main call. For example, to make a REST API call:

```swift
let restApi  = SFRestAPI.sharedInstance()
 restApi.Promises.query(soql: "SELECT Id,FirstName,LastName FROM User")
 .then { request in
    restApi.Promises.send(request: request)
 }
 .done { sfRestResponse in
    restResonse = sfRestResponse.asJsonDictionary()
    ...
 }
 .catch { error in
    //handle error
 }
```

Or, to perform a SmartSync `syncDown()` operation:

```swift
firstly {
     let syncDownTarget = SFSoqlSyncDownTarget.newSyncTarget(soqlQuery)
     let syncOptions    = SFSyncOptions.newSyncOptions(forSyncDown: SFSyncStateMergeMode.overwrite)
     return (self.syncManager.Promises.syncDown(target: syncDownTarget, options: syncOptions, soupName: CONTACTS_SOUP))
}
.then { syncState -> Promise<UInt> in
     let querySpec =  SFQuerySpec.Builder(soupName: CONTACTS_SOUP)
     .queryType(value: "range")
     .build()
     return (store.Promises.count(querySpec: querySpec))!
}
.then { count -> Promise<Void>  in
     return new Promise(())
}
.done { syncStateStatus in
}
.catch { error in
}
```

To learn more about promises and the PromiseKit SDK, see the [PromiseKit Readme](https://github.com/mxcl/PromiseKit/blob/master/README.md).
