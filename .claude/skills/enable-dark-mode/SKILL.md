---
skill: enable-dark-mode
description: Enable dark mode in a Salesforce Mobile SDK iOS app — pick the right mechanism and wire it up.
globs:
  - "Info.plist"
  - "**/*.swift"
  - "**/*.m"
  - "**/*.h"
  - "**/*.xcassets/**"
tags:
  - ui
  - dark-mode
  - appearance
---

# Enable Dark Mode Skill

This skill guides you through enabling dark mode in a Salesforce Mobile SDK iOS app. You'll learn which mechanism to use, how to wire it up, and the screens it covers vs. the ones you must style yourself.

## When to Use

Use this skill when you need to:
- Enable dark mode support in your Mobile SDK iOS app
- Decide between static and runtime configuration
- Confirm which screens the SDK styles for you and which you must style yourself

## Background

By default — when neither the `Info.plist` key nor the runtime property is set — the SDK follows the system appearance (same as any iOS app). If you want to override that, the Mobile SDK provides two mechanisms:

**Option A — Static Configuration (All SDK Versions)**

Use the `UIUserInterfaceStyle` key in your app's `Info.plist` to statically opt in or out of dark mode. This applies to your entire app at launch.

- Set to `Light` to disable dark mode entirely
- Set to `Dark` to force dark mode always
- Omit the key (or set to `Automatic`) to follow the system appearance

**Option B — Runtime Control (SDK 8.3+)**

Use the `SFSDKWindowManager.sharedManager().userInterfaceStyle` property to toggle dark mode at runtime.

> **Important — limited scope.** This property only affects SDK-managed screens: the login host picker, OAuth web login, Switch User screen, passcode/biometric prompts, and the snapshot window (the privacy view the SDK shows while the app is backgrounded). Your app's own view controllers are not affected — you must style those separately (see "Styling Your Own App UI" below).

**Precedence Rule:** If both mechanisms are configured, the runtime property overrides the `Info.plist` value.

## Decision: Which Mechanism?

Choose based on your SDK version and requirements:

**Use Info.plist if:**
- You're on SDK 8.2 or earlier (runtime control unavailable)
- You want to permanently disable dark mode (`UIUserInterfaceStyle = Light`)
- You want to force dark mode with no user toggle (`UIUserInterfaceStyle = Dark`)

**Use runtime control if:**
- You're on SDK 8.3 or later
- You want to let users toggle dark mode in your app's settings
- You want to conditionally enable dark mode based on app logic

**Use both if:**
- You want a default behavior (via `Info.plist`) but also runtime flexibility (SDK 8.3+)

To check your SDK version, look at the resolved version of `SalesforceSDKCore` in your `Podfile.lock` (CocoaPods) or `Package.resolved` (Swift Package Manager).

## Styling Your Own App UI

Both mechanisms in this skill control only SDK-managed screens. The dark appearance of your own view controllers is your responsibility and is not specific to the Mobile SDK — use the standard iOS / UIKit dark mode APIs (dynamic colors, semantic system colors, asset-catalog "Any, Dark" variants).

See Apple's "Supporting Dark Mode in Your Interface" in the Resources section below.

## Process

You can enable dark mode in two ways — pick Option A or Option B based on the Decision section above.

### Option A: Static Configuration via Info.plist

Add the `UIUserInterfaceStyle` key to your app's `Info.plist`:

```xml
<key>UIUserInterfaceStyle</key>
<string>Light</string>
```

**Values:**
- `Light` — disable dark mode, always use light appearance
- `Dark` — force dark mode, always use dark appearance
- Omit the key or use `Automatic` to follow system appearance

This forces the appearance on all windows in your app, SDK-managed and your own. If you pick `Dark`, your own hardcoded colors won't auto-adapt — your UI still needs dynamic colors or asset-catalog dark variants to actually look correct.

### Option B: Runtime Control via SFSDKWindowManager (SDK 8.3+)

Set the `userInterfaceStyle` property on the shared `SFSDKWindowManager` instance. The typical place is your app delegate's `application(_:didFinishLaunchingWithOptions:)`, after SDK initialization:

**Swift:**
```swift
import SalesforceSDKCore

func application(_ application: UIApplication,
                 didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    // After SalesforceSDKManager has been initialized:
    SFSDKWindowManager.sharedManager().userInterfaceStyle = .dark
    return true
}
```

**Objective-C:**
```objc
#import <SalesforceSDKCore/SalesforceSDKCore.h>

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [SFSDKWindowManager sharedManager].userInterfaceStyle = UIUserInterfaceStyleDark;
    return YES;
}
```

**Available values:**
- `.unspecified` / `UIUserInterfaceStyleUnspecified` — follow system appearance
- `.light` / `UIUserInterfaceStyleLight` — light appearance
- `.dark` / `UIUserInterfaceStyleDark` — dark appearance

**Wiring a user-toggle in your settings screen:**

```swift
@IBAction func darkModeToggled(_ sender: UISwitch) {
    let style: UIUserInterfaceStyle = sender.isOn ? .dark : .light
    SFSDKWindowManager.sharedManager().userInterfaceStyle = style
    UserDefaults.standard.set(sender.isOn, forKey: "darkModeEnabled")
}
```

On launch (in your AppDelegate, after SDK initialization), read the saved preference and apply it:

```swift
let darkOn = UserDefaults.standard.bool(forKey: "darkModeEnabled")
SFSDKWindowManager.sharedManager().userInterfaceStyle = darkOn ? .dark : .light
```

## Verify

Verification is a manual visual check:

1. Build your app with dark appearance enabled (either via `Info.plist` or runtime property)
2. Run on a simulator or device
3. Visually inspect the SDK-managed screens:
   - **Login host picker** — log out, then on the login screen tap the host-selector control (gear icon or "Change Server")
   - **OAuth web login flow** — proceed past the host picker; the SDK presents the org's hosted login page
   - **Switch User screen** — open the SDK user-switching UI from your app's account menu
   - **Passcode/biometric prompts** — enable a passcode policy in your Connected App / External Client App settings (requires admin access to the org's app definition), then background and foreground the app to trigger the lock screen
   - **Snapshot window** — the privacy view the SDK shows while the app is backgrounded. Send the app to the background and immediately re-foreground it; the snapshot window flashes briefly during the transition
4. Visually inspect your own app screens for rendering issues (white-on-white text, missing icons, etc.)

This is not automatable — dark mode correctness requires human judgment of visual appearance.

## File Checklist

- [ ] `Info.plist` — `UIUserInterfaceStyle` key set (if using static configuration)
- [ ] `AppDelegate.swift` / `AppDelegate.m` — `SFSDKWindowManager.userInterfaceStyle` set (if using runtime control)
- [ ] App settings screen — wired to update `SFSDKWindowManager.userInterfaceStyle` (if exposing a user toggle)
- [ ] App-owned UI styled for dark mode separately (see Apple's dark-mode docs in Resources)
- [ ] Manual visual check passed on the SDK-managed screens listed in Verify

## Notes

- **Avoid forcing dark mode on users:** Unless your app has a specific design reason, prefer following the system appearance (`.unspecified` or omit `UIUserInterfaceStyle`).

## Resources

- Salesforce Mobile SDK Dark Mode Guide: https://developer.salesforce.com/docs/platform/mobile-sdk/guide/ui-dark-settings.html
- Apple — Supporting Dark Mode in Your Interface: https://developer.apple.com/documentation/uikit/supporting-dark-mode-in-your-interface
- Apple Human Interface Guidelines — Dark Mode: https://developer.apple.com/design/human-interface-guidelines/dark-mode
- UIKit Appearance and Trait Collections: https://developer.apple.com/documentation/uikit/appearance_customization
