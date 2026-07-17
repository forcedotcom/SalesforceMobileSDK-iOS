# Push Notifications — Salesforce Mobile SDK for iOS

This document covers the push notification subsystem in `libs/SalesforceSDKCore`. All classes live in the `SalesforceSDKCore` framework under `PushNotification/`.

For cross-platform concepts and the shared Salesforce registration model, see the [workspace-level push doc](../../../docs/push/README.md).

---

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Architecture](#architecture)
4. [Key Classes](#key-classes)
5. [Setup](#setup)
6. [Registration Lifecycle](#registration-lifecycle)
7. [Re-registration Modes](#re-registration-modes)
8. [Encrypted Push Notifications](#encrypted-push-notifications)
9. [Actionable Notifications](#actionable-notifications)
10. [In-App Notification Management](#in-app-notification-management)
11. [Testing](#testing)

---

## Overview

The SDK integrates Apple Push Notification service (APNs) to deliver push notifications from a Salesforce org to iOS devices. `PushNotificationManager` (ObjC: `SFPushNotificationManager`) handles the full lifecycle: APNs registration, Salesforce device registration, re-registration on foreground/login, encrypted payload support, and actionable notification category setup.

---

## Prerequisites

| Requirement | Details |
|---|---|
| Push Notifications capability | Add via Xcode → Signing & Capabilities; populates `aps-environment` in `.entitlements` |
| APNs certificate or key | Configured in your Apple Developer account and uploaded to the Salesforce Connected App |
| External Client App (Connected App) | Push notification endpoint enabled in your Salesforce org |
| `UserNotifications` framework | Linked automatically by the SDK |

---

## Architecture

```
App
 └── AppDelegate
      ├── UNUserNotificationCenter.requestAuthorization(...)
      ├── UIApplication.registerForRemoteNotifications()  ← triggers APNs
      └── PushNotificationManager.shared
           ├── registerForRemoteNotifications()           ← SDK call to start APNs
           ├── didRegisterForRemoteNotifications(withDeviceToken:)
           └── registerForSalesforceNotifications(...)    ← POST MobilePushServiceDevice

PushNotificationManager (internal observers)
 ├── UserAccountManager.didLogInUser        → auto-register on login
 ├── UIApplication.willEnterForeground      → auto re-register (foregroundRegistrationMode)
 └── UserAccountManager.didMigrateRefreshToken → auto re-register

Notification Service Extension (optional, separate target)
 └── SFSDKPushNotificationDecryption.decryptNotificationContent(_:error:)
```

**Registration payload sent to Salesforce** (`POST /vXX.0/sobjects/MobilePushServiceDevice`):
```json
{
  "ConnectionToken": "<hex device token>",
  "ServiceType": "Apple",
  "ApplicationBundle": "<CFBundleIdentifier>",
  "RsaPublicKey": "<base64 2048-bit RSA public key>",
  "CipherName": "RSA_OAEP_SHA256"
}
```
Fields in `customPushRegistrationBody` are merged in (overwriting conflicts). The response `id` is stored as `deviceSalesforceId` in per-user `SFPreferences` and used for unregistration.

---

## Key Classes

### `PushNotificationManager` (ObjC: `SFPushNotificationManager`)

Singleton. The main entry point for all push operations.

**Access:**
```swift
PushNotificationManager.shared          // Swift
[SFPushNotificationManager sharedInstance]  // Objective-C
```

**Key properties:**
```swift
public var deviceToken: String?
public var customPushRegistrationBody: [String: Any]?   // merged into registration POST body
public var foregroundRegistrationMode: PushNotificationForegroundRegistrationMode  // default .allUsers
```

**`PushNotificationForegroundRegistrationMode` enum:**

| Value | Behaviour |
|---|---|
| `.none` | No re-registration when app enters foreground |
| `.currentUser` | Only the current user is re-registered (pre-14.0 behaviour) |
| `.allUsers` | All logged-in users are re-registered **(default since 14.0)** |

**Registration methods:**
```swift
// Request APNs registration (call before Salesforce registration)
public func registerForRemoteNotifications()

// Forward the APNs device token from AppDelegate
@objc public func didRegisterForRemoteNotifications(withDeviceToken: Data)

// Register with Salesforce (Swift async Result API — preferred)
public func registerForSalesforceNotifications(
    _ completionBlock: @escaping (Result<Bool, PushNotificationManagerError>) -> ()
)
public func registerForSalesforceNotifications(
    user: UserAccount,
    completionBlock: @escaping (Result<Bool, PushNotificationManagerError>) -> ()
)

// ObjC-compatible variants
@discardableResult
@objc public func registerSalesforceNotifications(
    completionBlock: (() -> Void)?,
    failBlock: (() -> Void)?
) -> Bool
@discardableResult
@objc public func registerSalesforceNotifications(
    for user: UserAccount,
    completionBlock: (() -> Void)?,
    failBlock: (() -> Void)?
) -> Bool
```

**Unregistration methods:**
```swift
public func unregisterForSalesforceNotifications(_ completionBlock: @escaping (Bool) -> ())
public func unregisterForSalesforceNotifications(user: UserAccount, _ completionBlock: @escaping (Bool) -> ())

@discardableResult
@objc public func unregisterSalesforceNotifications(completionBlock: (() -> Void)?) -> Bool
@discardableResult
@objc public func unregisterSalesforceNotifications(for user: UserAccount, completionBlock: (() -> Void)?) -> Bool
```

**Encryption key:**
```swift
@objc public func getRSAPublicKey() -> String?   // base64-encoded 2048-bit RSA public key
```

**`PushNotificationManagerError` enum:**
- `.registrationFailed`
- `.currentUserNotDetected`
- `.failedNotificationTypesRetrieval`
- `.notificationActionInvocationFailed(String)`

---

### `SFSDKPushNotificationDecryption` (Objective-C)

Stateless utility for decrypting encrypted push payloads. Use this inside a **Notification Service Extension**.

```objc
+ (BOOL)decryptNotificationContent:(UNMutableNotificationContent *)notificationContent
                             error:(NSError **)error;
```

Returns `YES` (no-op) if the payload's `"encrypted"` field is absent or false. On success, populates `notificationContent.title` and `.body` from the decrypted `"alertTitle"` / `"alertBody"` fields and merges all other decrypted keys into `userInfo`.

---

### `NotificationType` (ObjC: `SFSDKNotificationType`)

```swift
public class NotificationType: NSObject, Codable, NSSecureCoding {
    public let type: String
    public let apiName: String
    public let label: String
    public let actionGroups: [ActionGroup]?
    public func filteredCopy(keepingActions allowedActionTypes: Set<String>) -> NotificationType
    public class func from(jsonData: Data) -> [NotificationType]
}
```

### `ActionGroup` / `Action`

```swift
public class ActionGroup: NSObject, Codable, NSSecureCoding {
    public let name: String
    public let actions: [Action]
}

public class Action: NSObject, Codable, NSSecureCoding {
    public let name: String
    public let identifier: String   // JSON key: "actionKey"
    public let label: String
    public let type: String         // "NotificationApiAction" → .authenticationRequired; else → .foreground
}
```

---

## Setup

### 1. Enable Push Notifications Capability

In Xcode, select your app target → **Signing & Capabilities** → **+ Capability** → **Push Notifications**. This adds `aps-environment` to your `.entitlements` file.

### 2. AppDelegate (Swift — matches SDK templates)

```swift
import UserNotifications
import SalesforceSDKCore   // or SalesforceReact for React Native

func application(_ application: UIApplication,
                 didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    // ... SDK init ...
    registerForRemotePushNotifications()
    return true
}

private func registerForRemotePushNotifications() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.sound, .alert, .badge]) { granted, error in
        if granted {
            DispatchQueue.main.async {
                PushNotificationManager.shared.registerForRemoteNotifications()
            }
        }
        if let error {
            SalesforceLogger.e(AppDelegate.self, message: "Push authorization error: \(error)")
        }
    }
}

func application(_ application: UIApplication,
                 didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    PushNotificationManager.shared.didRegisterForRemoteNotifications(withDeviceToken: deviceToken)
    if UserAccountManager.shared.currentUserAccount?.credentials.accessToken != nil {
        PushNotificationManager.shared.registerForSalesforceNotifications { result in
            switch result {
            case .success: break
            case .failure(let error): SalesforceLogger.e(AppDelegate.self, message: "Salesforce push registration failed: \(error)")
            }
        }
    }
    // If not yet authenticated, the SDK auto-registers after login via UserAccountManager.didLogInUser
}

func application(_ application: UIApplication,
                 didFailToRegisterForRemoteNotificationsWithError error: Error) {
    SalesforceLogger.e(AppDelegate.self, message: "APNs registration failed: \(error)")
}
```

### 3. AppDelegate (Objective-C)

```objc
- (void)registerForRemotePushNotifications {
    [[UNUserNotificationCenter currentNotificationCenter]
        requestAuthorizationWithOptions:(UNAuthorizationOptionSound | UNAuthorizationOptionAlert | UNAuthorizationOptionBadge)
        completionHandler:^(BOOL granted, NSError *error) {
            if (granted) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[SFPushNotificationManager sharedInstance] registerForRemoteNotifications];
                });
            }
        }];
}

- (void)application:(UIApplication *)app
    didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    [[SFPushNotificationManager sharedInstance] didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
    if ([SFUserAccountManager sharedInstance].currentUser.credentials.accessToken) {
        [[SFPushNotificationManager sharedInstance]
            registerSalesforceNotificationsWithCompletionBlock:nil failBlock:nil];
    }
}
```

### 4. Handle Foreground and Tapped Notifications (Optional)

Implement `UNUserNotificationCenterDelegate` to control display while the app is in the foreground and to respond to user taps:

```swift
extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle notification tap or action button here
        completionHandler()
    }
}
```

Set the delegate in `didFinishLaunchingWithOptions`:
```swift
UNUserNotificationCenter.current().delegate = self
```

---

## Registration Lifecycle

```
App launch / login
        │
        ▼
requestAuthorization(...)        ← user grants permission
        │
        ▼
PushNotificationManager.registerForRemoteNotifications()
        │
        ▼ (APNs responds)
didRegisterForRemoteNotificationsWithDeviceToken(_:)
        │
        ├─ Authenticated? ──► registerForSalesforceNotifications()
        │                              │
        │              POST /vXX.0/sobjects/MobilePushServiceDevice
        │                              │
        │                    ┌─────────┴──────────┐
        │                    ▼                     ▼
        │               201 Created           404 Not Found
        │           (store device ID)    (push not enabled on org)
        │
        └─ Not authenticated ──► SDK auto-registers via UserAccountManager.didLogInUser

Unregistration (logout)
        │
        ▼
unregisterForSalesforceNotifications(...)
        │
        ▼
DELETE /vXX.0/sobjects/MobilePushServiceDevice/<deviceId>
```

**Automatic re-registration triggers (SDK-managed):**
- `UserAccountManager.didLogInUser` — re-registers if `deviceToken` is stored
- `UIApplication.willEnterForegroundNotification` — re-registers per `foregroundRegistrationMode`
- `UserAccountManager.didMigrateRefreshToken` — re-registers current user

---

## Re-registration Modes

Control which users are re-registered when the app enters the foreground:

```swift
PushNotificationManager.shared.foregroundRegistrationMode = .currentUser
```

| Value | Behaviour |
|---|---|
| `.allUsers` | Re-registers all authenticated users **(default)** |
| `.currentUser` | Re-registers only the current user (use for Publisher billing scenarios) |
| `.none` | No automatic re-registration on foreground |

---

## Encrypted Push Notifications

The SDK automatically handles encrypted Salesforce Notification Builder payloads with no additional app-side configuration:

1. During registration, the SDK generates an RSA-2048 key pair in the Keychain (key name: `com.salesforce.mobilesdk.notificationKey`) and includes the public key and cipher name (`RSA_OAEP_SHA256`) in the registration payload.
2. Salesforce encrypts future notification payloads using the registered public key.
3. Incoming encrypted payloads carry:
   - `"encrypted": true`
   - `"secret"` — RSA-OAEP-SHA256-wrapped 32-byte value (16-byte AES key + 16-byte IV), base64-encoded
   - `"content"` — AES-128-CBC-encrypted JSON payload, base64-encoded

To decrypt the notification **before it is displayed** (required for encrypted payloads), add a **Notification Service Extension** to your app target:

```objc
// NotificationService.m
#import <SalesforceSDKCore/SFSDKPushNotificationDecryption.h>

- (void)didReceiveNotificationRequest:(UNNotificationRequest *)request
                   withContentHandler:(void (^)(UNNotificationContent *))contentHandler {
    UNMutableNotificationContent *mutableContent = [request.content mutableCopy];
    NSError *error;
    [SFSDKPushNotificationDecryption decryptNotificationContent:mutableContent error:&error];
    if (error) {
        NSLog(@"Decryption error: %@", error);
    }
    contentHandler(mutableContent);
}
```

**Important:** The Notification Service Extension must share the same **Keychain Access Group** as the main app (add the Keychain Sharing capability to both targets with a matching group identifier) so the extension can access the RSA private key. The key is stored with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.

Apex push notifications are **not** encrypted and are forwarded as-is.

---

## Actionable Notifications

Requires Salesforce API version v64.0 or later.

After successful Salesforce registration, the SDK automatically calls `fetchAndStoreNotificationTypes`, which:
1. GETs `/vXX.0/connect/notifications/types`
2. Stores the returned `[NotificationType]` on the `UserAccount` object (persisted via `NSSecureCoding`)
3. Calls `UNUserNotificationCenter.current().setNotificationCategories(_:)` to register action buttons

**Filter which notification types your app supports:**
```swift
UserAccountManager.shared.filterSupportedNotificationTypes = { types in
    types.filter { $0.apiName == "approval_request" }
    // or use filteredCopy(keepingActions:) to limit specific action types
}
```

**Handle a tapped action:**
```swift
// In UNUserNotificationCenterDelegate.userNotificationCenter(_:didReceive:withCompletionHandler:)
if let notificationId = response.notification.request.content.userInfo["nid"] as? String {
    do {
        let result = try await PushNotificationManager.shared.invokeServerNotificationAction(
            client: restClient,
            notificationId: notificationId,
            actionIdentifier: response.actionIdentifier
        )
        SalesforceLogger.d(AppDelegate.self, message: "Action result: \(result.message)")
    } catch {
        SalesforceLogger.e(AppDelegate.self, message: "Action invocation failed: \(error)")
    }
}
completionHandler()
```

Action type `"NotificationApiAction"` receives `UNNotificationActionOptions.authenticationRequired`. All other types receive `.foreground`.

---

## In-App Notification Management

Use `SFRestAPI(Notifications)` to query and update notification state:

```objc
// Fetch unread notifications
SFRestRequest *req = [[SFRestAPI sharedInstance] requestForNotificationsStatus:kSFRestDefaultAPIVersion];

// Fetch notification types
SFRestRequest *req = [[SFRestAPI sharedInstance] requestForNotificationTypes];

// Mark as read
// Use SFSDKUpdateNotificationsRequestBuilder to build a PATCH request
```

See `SFRestAPI+Notifications.h` for the full set of builder classes (`SFSDKFetchNotificationsRequestBuilder`, `SFSDKUpdateNotificationsRequestBuilder`).

---

## Testing

Push notification tests are in `libs/SalesforceSDKCore/SalesforceSDKCoreTests/`:

| Test class | Coverage |
|---|---|
| `PushNotificationManagerTests.swift` | Registration/unregistration lifecycle, re-registration modes, token handling |
| `PushNotificationDecryptionTests.swift` | Swift decryption of encrypted payloads |
| `SFSDKEncryptedPushNotificationTests.m` | ObjC decryption tests, error code coverage |
| `SFPushNotificationManagerTests.m` | ObjC-surface registration and Salesforce endpoint communication |

Run tests via Xcode or `xcodebuild` targeting the `SalesforceSDKCoreTests` scheme.
