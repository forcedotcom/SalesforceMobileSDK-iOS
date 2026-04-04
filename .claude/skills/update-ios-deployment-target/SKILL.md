# Update iOS Minimum Deployment Target

This skill updates the minimum iOS deployment target across the entire Salesforce Mobile SDK for iOS repository.

## When to Use
- When bumping the minimum supported iOS version for a new SDK release
- Typically done once per major release cycle

## What This Skill Does

Updates the iOS deployment target in all necessary locations:

1. **CocoaPods Specifications** - Updates platform version in all 5 podspec files
2. **Build Configuration** - Updates Xcode configuration files
3. **Project Files** - Updates all .pbxproj files for libraries and sample apps
4. **Installation Scripts** - Updates version checks in install.sh
5. **Documentation** - Updates readme.md with new minimum version
6. **Helper Scripts** - Updates mobilesdk_pods.rb deployment target
7. **GitHub Actions Workflows** - Updates CI workflow matrices and runtime installation steps
8. **Code Cleanup** - Identifies and removes obsolete version checks in source code
9. **Comment Updates** - Updates version references in code comments

## Usage

When invoked, ask the user for:
- **Current minimum iOS version** (e.g., "16.0")
- **New minimum iOS version** (e.g., "17.0")
- **Corresponding minimum Xcode version** (e.g., "16.0" for iOS 17)

## Step-by-Step Process

### 1. Update CocoaPods Specifications
Update `s.platform = :ios, "X.0"` in:
- MobileSync.podspec
- SalesforceAnalytics.podspec
- SalesforceSDKCommon.podspec
- SalesforceSDKCore.podspec
- SmartStore.podspec

### 2. Update Build Configuration
In `configuration/Packaging-Dynamic.xcconfig`:
- Change `IPHONEOS_DEPLOYMENT_TARGET = X.0`

### 3. Update Helper Scripts
In `mobilesdk_pods.rb`:
- Update `change_deployment_target(target, 'X.0')`

### 4. Update Installation Script
In `install.sh`:
- Update iOS version check strings (e.g., "iOS 15.0" → "iOS 17.0")
- Update Xcode version requirements (XCODE_MIN_VERSION and XCODE_MIN_VERSION_STR)

### 5. Update Documentation
In `readme.md`:
- Update minimum iOS version requirement statement

### 6. Update Xcode Project Files
Find all .pbxproj files and update `IPHONEOS_DEPLOYMENT_TARGET`:
- libs/MobileSync/MobileSync.xcodeproj/project.pbxproj
- libs/SalesforceAnalytics/SalesforceAnalytics.xcodeproj/project.pbxproj
- libs/SalesforceSDKCommon/SalesforceSDKCommon.xcodeproj/project.pbxproj
- libs/SalesforceSDKCore/SalesforceSDKCore.xcodeproj/project.pbxproj
- libs/SmartStore/SmartStore.xcodeproj/project.pbxproj
- Sample apps (MobileSyncExplorer, RestAPIExplorer, etc.)

### 7. Update GitHub Actions Workflows
Remove the old minimum iOS version from CI workflows and clean up runtime installation steps:

In `.github/workflows/nightly.yaml`:
- Remove old iOS version from test matrix (e.g., `ios: [^26, ^18, ^17]` → `ios: [^26, ^18]`)
- Remove old iOS version from build matrix
- Remove corresponding Xcode version mapping from matrix.include

In `.github/workflows/ui-test-nightly.yaml`:
- Remove old iOS version from test matrix
- Remove corresponding Xcode version mapping from matrix.include

### 8. Code Cleanup - Remove Obsolete Version Checks
Search for and review code with version-specific conditional compilation:
- `#if __IPHONE_OS_VERSION_MAX_ALLOWED >= [OLD_VERSION]`
- `@available(iOS X.Y, *)`
- `if #available(iOS X.Y, *)`

For each occurrence where the check is for a version now below the new minimum:
- Remove the conditional wrapper
- Keep only the modern code path
- Remove else/fallback branches for old iOS versions

Example patterns to search for:
```bash
# Find preprocessor conditionals
grep -r "#if __IPHONE_OS_VERSION_MAX_ALLOWED" libs/

# Find availability checks in Swift
grep -r "@available(iOS" libs/

# Find availability checks in Objective-C
grep -r "respondsToSelector" libs/
```

### 9. Update Version References in Comments
Search for and update comments that reference the old minimum version:
```bash
grep -r "iOS [OLD_VERSION]" libs/ --include="*.swift" --include="*.m" --include="*.h"
```

## Post-Update Tasks

1. **Build Verification**: Build all library schemes to verify no compilation errors
2. **Sample App Check**: Build and run sample apps (RestAPIExplorer, MobileSyncExplorer)


## Important Notes

- **STOP and FLAG for human review**: This is a significant change that affects all SDK consumers
- **Release timing**: Only bump deployment target at major releases, never patches
- **Breaking change**: Document this in migration guide and release notes


## Example Command Flow

```bash
# 1. Create a feature branch
git checkout -b bump-ios-18

# 2. Use this skill to make all updates
# (skill automates file edits)

# 3. Search for version-specific code
grep -r "@available(iOS 17" libs/ --include="*.swift"
grep -r "#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 170000" libs/

# 4. Build all libraries
xcodebuild -workspace SalesforceMobileSDK.xcworkspace -scheme SalesforceSDKCore -sdk iphonesimulator
xcodebuild -workspace SalesforceMobileSDK.xcworkspace -scheme SmartStore -sdk iphonesimulator
xcodebuild -workspace SalesforceMobileSDK.xcworkspace -scheme MobileSync -sdk iphonesimulator

```

## Historical References
- PR #3796: iOS 16 → iOS 17 bump
- PR #3681: iOS 15 → iOS 16 bump

## Checklist

Before marking complete:
- [ ] All 5 podspec files updated
- [ ] Packaging-Dynamic.xcconfig updated
- [ ] mobilesdk_pods.rb updated
- [ ] install.sh updated (both iOS and Xcode versions)
- [ ] readme.md updated
- [ ] All .pbxproj files updated (libraries + sample apps)
- [ ] Obsolete version checks removed from code
- [ ] Version references in comments updated
- [ ] All libraries build successfully
- [ ] Sample apps build
