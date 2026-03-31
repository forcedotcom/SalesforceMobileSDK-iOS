# Salesforce.com Mobile SDK for iOS
[![Tests](https://github.com/forcedotcom/SalesforceMobileSDK-iOS/actions/workflows/nightly.yaml/badge.svg)](https://github.com/forcedotcom/SalesforceMobileSDK-iOS/actions/workflows/nightly.yaml)
[![Known Vulnerabilities](https://snyk.io/test/github/forcedotcom/SalesforceMobileSDK-iOS/badge.svg)](https://snyk.io/test/github/forcedotcom/SalesforceMobileSDK-iOS)
![GitHub release (latest SemVer)](https://img.shields.io/github/v/release/forcedotcom/SalesforceMobileSDK-iOS?sort=semver)


You have arrived at the source repository for the Salesforce Mobile SDK for iOS.  Welcome!  There are two ways you can choose to work with the Mobile SDK:

- If you'd like to work with the source code of the SDK itself, you've come to the right place!  You can browse sample app source code and debug down through the layers to get a feel for how everything works under the covers.  Read on for instructions on how to get started with the SDK in your development environment.
- If you're just eager to start developing your own new application, the quickest way is to use our npm distribution package, called [forceios](https://npmjs.org/package/forceios), which is hosted on [npmjs.org](https://npmjs.org/).  Getting started is as simple as installing the npm package and launching your template app.  You'll find more details on the forceios package page.

Installation (do this first - really)
==
Working with this repository requires working with git.  Any workflow that leaves you with a functioning git clone of this repository should set you up for success.  Downloading the ZIP file from GitHub, on the other hand, is likely to put you at a dead end.

## Setting up the repo
First, clone the repo:

- Open the Terminal App
- `cd` to the parent directory where the repo directory will live
- `git clone https://github.com/forcedotcom/SalesforceMobileSDK-iOS.git`

After cloning the repo:

- `cd SalesforceMobileSDK-iOS`
- `./install.sh`

This script pulls the submodule dependencies from GitHub, to finalize setup of the workspace.  You can then work with the Mobile SDK by opening `SalesforceMobileSDK.xcworkspace` from Xcode.

The Salesforce Mobile SDK for iOS requires iOS 17.0 or greater.  The install.sh script checks for this, and aborts if the configured SDK version is incorrect.

Introduction
==

### What's New in 13.2.0
See [release notes](https://github.com/forcedotcom/SalesforceMobileSDK-iOS/releases).

### Native Applications
The Salesforce Mobile SDK provides the essential libraries for quickly building native mobile apps that interact with the Salesforce cloud platform. The OAuth2 library abstracts away the complexity of securely storing the refresh token or fetching a new session ID when it expires. The SDK also provides wrappers for the Salesforce REST API that you can use from both Swift and Objective-C.

## Libraries

| Library | Purpose |
|---------|---------|
| **SalesforceSDKCommon** | Shared utilities and base protocols |
| **SalesforceAnalytics** | Telemetry and event tracking |
| **SalesforceSDKCore** | OAuth2 authentication, REST API, account management |
| **SmartStore** | Encrypted local storage (SQLCipher) |
| **MobileSync** | Data synchronization framework |

## Getting Started

### Using the SDK (via forceios)

```bash
# Install CLI
npm install -g forceios

# Create app from template
forceios create --appname MyApp --packagename com.mycompany.myapp --organization "My Company"
```

See templates for complete usage examples.

### Building from Source

```bash
# Clone and setup
git clone https://github.com/forcedotcom/SalesforceMobileSDK-iOS.git
cd SalesforceMobileSDK-iOS
./install.sh

# Open in Xcode
open SalesforceMobileSDK.xcworkspace
```

## Usage

### Authentication (OAuth2)

```swift
import SalesforceSDKCore

// Configure SDK in AppDelegate
SalesforceManager.shared.configure { (config: SalesforceSDKManager.Configuration) in
    config.oauthConfig.consumerKey = "YOUR_CONSUMER_KEY"
    config.oauthConfig.callbackUri = "YOUR_CALLBACK_URL"
    config.oauthConfig.scopes = ["web", "api", "refresh_token"]

    // Optional: customize login host
    config.oauthConfig.loginHost = "https://login.salesforce.com"
}

// Get current user
if let user = UserAccountManager.shared.currentUserAccount {
    print("Logged in as: \(user.userName)")
    print("Organization: \(user.accountIdentity.orgId)")
}

// Logout
UserAccountManager.shared.logout()
```

### REST API

```swift
import SalesforceSDKCore

// Query records
let request = RestClient.shared.request(
    forQuery: "SELECT Id, Name FROM Account LIMIT 10"
)

RestClient.shared.send(request: request) { result in
    switch result {
    case .success(let response):
        if let records = response.asJsonDictionary()?["records"] as? [[String: Any]] {
            for record in records {
                print("Account: \(record["Name"] ?? "")")
            }
        }
    case .failure(let error):
        print("Error: \(error)")
    }
}

// Create a record
let fields = ["Name": "Acme Corp", "Industry": "Technology"]
let request = RestClient.shared.request(
    forCreate(withObjectType: "Account", fields: fields)
)

RestClient.shared.send(request: request) { result in
    switch result {
    case .success(let response):
        if let id = response.asJsonDictionary()?["id"] as? String {
            print("Created account with ID: \(id)")
        }
    case .failure(let error):
        print("Error: \(error)")
    }
}

// Update a record
let fields = ["Name": "Updated Name"]
let request = RestClient.shared.request(
    forUpdate(withObjectType: "Account", objectId: recordId, fields: fields)
)

// Delete a record
let request = RestClient.shared.request(
    forDelete(withObjectType: "Account", objectId: recordId)
)
```

### SmartStore (Encrypted Storage)

```swift
import SmartStore

// Get store instance
let store = SmartStore.shared(withName: SmartStore.defaultStoreName)

// Register a soup (table)
let indexSpecs = [
    SoupIndex(path: "Name", indexType: .string, columnName: "Name"),
    SoupIndex(path: "LastModifiedDate", indexType: .string, columnName: "LastModifiedDate")
]

store.registerSoup(withName: "accounts", withIndexSpecs: indexSpecs, error: nil)

// Insert/update entries
let entry = ["Name": "Acme Corp", "Industry": "Technology"]
store.upsertEntries([entry], toSoup: "accounts")

// Query entries
let querySpec = QuerySpec.buildSmartQuerySpec(
    smartSql: "SELECT {accounts:Name}, {accounts:Industry} FROM {accounts} ORDER BY {accounts:Name}",
    pageSize: 10
)

let results = store.query(using: querySpec, pageIndex: 0, error: nil)
for entry in results {
    print("Account: \(entry["Name"] ?? "")")
}

// Delete entries
store.removeEntries(fromSoup: "accounts", withSoupEntryIds: [entryId])
```

### MobileSync (Data Synchronization)

```swift
import MobileSync

// Get sync manager
let syncManager = SyncManager.shared(store: store)

// Sync down from Salesforce
let target = SoqlSyncDownTarget(
    query: "SELECT Id, Name, Industry FROM Account WHERE LastModifiedDate > {LastModifiedDate}"
)

let options = SyncOptions(mergeMode: .overwrite)

syncManager.syncDown(
    target: target,
    soupName: "accounts",
    options: options
) { syncState in
    if syncState.isDone() {
        print("Sync down complete: \(syncState.totalSize) records")
    } else if syncState.hasFailed() {
        print("Sync failed: \(syncState.error?.localizedDescription ?? "")")
    }
}

// Sync up to Salesforce
let target = SyncUpTarget()
let options = SyncOptions(mergeMode: .overwrite)

syncManager.syncUp(
    target: target,
    soupName: "accounts",
    options: options
) { syncState in
    if syncState.isDone() {
        print("Sync up complete: \(syncState.totalSize) records")
    }
}
```

## Building from Source

### Prerequisites

- **Xcode**: 15.0 or higher
- **iOS Deployment Target**: 17.0 or higher
- **CocoaPods**: 1.8.0 or higher (for dependency management)
- **Git**: 2.13 or higher

### Setup

```bash
# Clone the repository
git clone https://github.com/forcedotcom/SalesforceMobileSDK-iOS.git
cd SalesforceMobileSDK-iOS

# Install dependencies (submodules)
./install.sh

# Open workspace in Xcode
open SalesforceMobileSDK.xcworkspace
```

### Building

```bash
# Build all libraries (from command line)
xcodebuild -workspace SalesforceMobileSDK.xcworkspace \
  -scheme SalesforceSDKCore \
  -sdk iphonesimulator \
  build

# Build specific library
xcodebuild -workspace SalesforceMobileSDK.xcworkspace \
  -scheme SmartStore \
  -sdk iphonesimulator \
  build
```

### Running Tests

```bash
# Run tests for SalesforceSDKCore
xcodebuild test \
  -workspace SalesforceMobileSDK.xcworkspace \
  -scheme SalesforceSDKCore \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 15'

# Run SmartStore tests
xcodebuild test \
  -workspace SalesforceMobileSDK.xcworkspace \
  -scheme SmartStore \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 15'

# Run MobileSync tests
xcodebuild test \
  -workspace SalesforceMobileSDK.xcworkspace \
  -scheme MobileSync \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Distribution

The SDK is distributed via:

- **CocoaPods**: Podspecs published to [SalesforceMobileSDK-iOS-Specs](https://github.com/forcedotcom/SalesforceMobileSDK-iOS-Specs)
- **Swift Package Manager**: XCFrameworks published to [SalesforceMobileSDK-iOS-SPM](https://github.com/forcedotcom/SalesforceMobileSDK-iOS-SPM)
- **npm**: CLI tool [forceios](https://www.npmjs.com/package/forceios) for generating apps from templates

### Using CocoaPods

```ruby
# Podfile
platform :ios, '17.0'
use_frameworks!

target 'MyApp' do
  pod 'SalesforceSDKCore'
  pod 'SmartStore'
  pod 'MobileSync'
end
```

### Using Swift Package Manager

```swift
// Package.swift
dependencies: [
    .package(
        url: "https://github.com/forcedotcom/SalesforceMobileSDK-iOS-SPM",
        from: "13.2.0"
    )
]
```

### Creating Apps with forceios

```bash
# Install forceios CLI
npm install -g forceios

# Create a new app
forceios create \
  --appname MyApp \
  --packagename com.mycompany.myapp \
  --organization "My Company"

# List available templates
forceios listtemplates

# Create from specific template
forceios createwithtemplate \
  --templaterepouri iOSNativeSwiftTemplate \
  --appname MyApp \
  --packagename com.mycompany.myapp
```

Documentation
==

* [SalesforceSDKCommon Library Reference](http://forcedotcom.github.io/SalesforceMobileSDK-iOS/Documentation/SalesforceSDKCommon/documentation/salesforcesdkcommon/)
* [SalesforceAnalytics Library Reference](http://forcedotcom.github.io/SalesforceMobileSDK-iOS/Documentation/SalesforceAnalytics/documentation/salesforceanalytics/)
* [SalesforceSDKCore Library Reference](http://forcedotcom.github.io/SalesforceMobileSDK-iOS/Documentation/SalesforceSDKCore/documentation/salesforcesdkcore/)
* [SmartStore Library Reference](http://forcedotcom.github.io/SalesforceMobileSDK-iOS/Documentation/SmartStore/documentation/smartstore/)
* [MobileSync Library Reference](http://forcedotcom.github.io/SalesforceMobileSDK-iOS/Documentation/MobileSync/documentation/mobilesync/)
* Salesforce Mobile SDK Development Guide -- [HTML](https://developer.salesforce.com/docs/atlas.en-us.mobile_sdk.meta/mobile_sdk/preface_intro.htm)
* [Mobile SDK Trail](https://trailhead.salesforce.com/en/content/learn/trails/start-ios-appdev)

Discussion
==

If you would like to make suggestions, have questions, or encounter any issues, we'd love to hear from you. Post any feedback you have on the [Mobile SDK Trailblazer Community](https://trailhead.salesforce.com/en/trailblazer-community/groups/0F94S000000kH0HSAU?tab=discussion&sort=LAST_MODIFIED_DATE_DESC).
