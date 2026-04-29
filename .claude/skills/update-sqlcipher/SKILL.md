---
skill: sqlcipher-update
description: Update SQLCipher dependency in Salesforce Mobile SDK for iOS
globs:
  - "*.podspec"
  - "libs/SmartStore/**/*.swift"
  - "libs/SmartStore/**/*.h"
  - "libs/SmartStore/**/*.m"
tags:
  - dependency-update
  - sqlcipher
  - encryption
  - smartstore
---

# Update SQLCipher Skill

This skill automates the process of updating the SQLCipher library version in the SalesforceMobileSDK-iOS project.

## When to Use
Use this skill when you need to:
- Update SQLCipher to a newer version for security patches or new features
- Track changes in SQLCipher's OpenSSL provider version
- Handle API changes in new SQLCipher versions

## Background
SQLCipher is an open-source extension to SQLite that provides transparent 256-bit AES encryption of database files. The SDK uses it in the SmartStore library for secure local data storage.

## Parameters
- `NEW_VERSION`: The new SQLCipher version (e.g., "4.6.1", "4.6.2")
- `OLD_VERSION`: The current SQLCipher version (default: check podspecs)
- `NEW_PROVIDER_VERSION`: The cipher provider version bundled with the new SQLCipher (check SQLCipher release notes)

## Prerequisite
Podspec for the new version is available on SalesforceMobileSDK-iOS-Specs

## Process

### 1. Research the New Version

Before starting, check the SQLCipher release notes:
- Visit: https://github.com/sqlcipher/sqlcipher/releases
- Review changes, breaking changes, and new features
- Note the provider version included (important for tests)
- Check for API changes that might affect the SDK

**Key things to look for:**
- Provider version changes (OpenSSL/LibTomCrypt versions)
- C API signature changes (sqlite3_*, sqlcipher_*)
- Deprecated PRAGMA statements or behavior changes
- Security fixes or enhancements
- Changes to encryption algorithms or key derivation

### 2. Update Dependency Version

Update SQLCipher version in the podspec file, SmartStore.xcodeproj and mobilesdk_pods.rb:

**SmartStore.podspec**
```ruby
s.dependency 'SQLCipher', '~> OLD_VERSION'
```

Change to:
```ruby
s.dependency 'SQLCipher', '~> NEW_VERSION'
```

**Files to update:**
- `SmartStore.podspec` - SmartStore pod specification
- `SmartStore.xcodeproj`
- `mobilesdk_pods.rb`

**Note:** The SDK supports exact version (`= 4.6.1`), minimum version (`>= 4.6.1`), or pessimistic version (`~> 4.6.1`) constraints depending on stability requirements.

### 3. Update Version Tests

Update libs/SmartStore/SmartStoreTests/SFSmartStoreTests.m:

Update the SQLCipher version test:

- (void) testSqlCipherVersion
{
    NSString* version = [self.store getSQLCipherVersion];
    XCTAssertEqualObjects(version, @"4.10.0 community");
}

Update the cipher provider version test:

- (void) testCipherProviderVersion {
    NSString *cipherProviderVersion = [self.store getCipherProviderVersion];
    XCTAssertNotNil(cipherProviderVersion);
    XCTAssertTrue(cipherProviderVersion.length > 0, @"cipherProviderVersion should not be an empty string");
}

Note: The OpenSSL version format is typically like "OpenSSL 3.0.17 1 Jul 2025" and the LibTomCrypt format is like "1.18.2" - check the actual runtime value or SQLCipher release notes.

Update the SQLLite version test:
- (void) testSqliteVersion {
    NSString* version = [NSString stringWithUTF8String:sqlite3_libversion()];
    XCTAssertEqualObjects(version, @"3.50.4");
}

### 4. Check for API Changes

Review if SQLCipher has any API changes that affect these files:

**Key files to check:**
- `libs/SmartStore/SmartStore/Classes/SFSmartStore.h` - Main SmartStore interface
- `libs/SmartStore/SmartStore/Classes/SFSmartStore.m` - SmartStore implementation
- `libs/SmartStore/SmartStore/Classes/SFSoupIndex.h` - Indexing
- `libs/SmartStore/SmartStore/Classes/SFQuerySpec.h` - Query specifications
- `libs/SmartStore/SmartStore/Classes/Store/SFSmartStoreDatabaseManager.swift` - Database management
- `libs/SmartStore/SmartStore/Classes/Store/SFSmartStoreEncryption.swift` - Encryption handling

**Historical API changes to watch for:**

**SQLCipher 4.x series:**
- PRAGMA cipher_* statements may have new options
- sqlite3_key_v2() signature changes (rare)
- Changes to SQLITE_HEX encoding behavior
- JSON1 extension behavior modifications
- FTS5 full-text search changes

**Common patterns:**
```objc
// Database opening with key
sqlite3_open()
sqlite3_key() // or sqlite3_key_v2()
PRAGMA cipher_page_size
PRAGMA kdf_iter
PRAGMA cipher_hmac_algorithm
PRAGMA cipher_kdf_algorithm
```

Check if any of these patterns need updates.

### 5. Build SmartStore

Build the SmartStore library to catch compilation issues:

```bash
xcodebuild -workspace SalesforceMobileSDK.xcworkspace \
  -scheme SmartStore \
  -sdk iphonesimulator \
  build
```

Address any compilation errors related to:
- Deprecated SQLCipher APIs
- Changed function signatures (especially sqlite3_* functions)
- New required PRAGMA statements
- Header import changes (sqlite3.h, sqlcipher.h)
- Compiler warnings about encryption functions

### 6. Run SmartStore Tests

**CRITICAL**: Full SmartStore test suite must pass before proceeding.

```bash
xcodebuild test -workspace SalesforceMobileSDK.xcworkspace \
  -scheme SmartStore \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

**Key tests to verify:**
- Database open/close operations with encryption
- Key derivation and PRAGMA cipher settings
- CRUD operations (create, read, update, delete)
- Query performance and Smart SQL
- Index creation and queries
- JSON1 extension functionality
- Concurrent access patterns
- Data integrity after encryption/decryption
- Migration from databases created with older SQLCipher versions

**Common test failures:**
- SQLITE_NOTADB errors (wrong encryption key/version)
- Query behavior changes (JOIN, JSON functions)
- Index performance differences
- PRAGMA statement compatibility issues

If tests fail:
- Check SQLCipher release notes for behavior changes
- Review error logs for SQLCipher-specific errors
- Test with all SQLCipher editions if applicable (Community, Commercial, Enterprise, FIPS)
- Compare PRAGMA settings between versions

### 7. Verify Other Libraries

SmartStore is a dependency of MobileSync, so verify the change doesn't break downstream:

```bash
# Build MobileSync
xcodebuild -workspace SalesforceMobileSDK.xcworkspace \
  -scheme MobileSync \
  -sdk iphonesimulator \
  build

# Run MobileSync tests (they use SmartStore)
xcodebuild test -workspace SalesforceMobileSDK.xcworkspace \
  -scheme MobileSync \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

MobileSync sync operations depend on SmartStore encryption working correctly.

### 8. Create Pull Request

When creating the PR:
- **Title:** "Moving to SQLCipher {NEW_VERSION}" or "Update SQLCipher to {NEW_VERSION}"
- **Description:** Include:
  - SQLCipher version being updated to
  - OpenSSL/LibTomCrypt version included
  - Link to SQLCipher release notes
  - Any API changes handled
  - Test results summary
  - Any breaking changes or migration notes
  - Impact on SmartStore encryption features

## File Checklist

- [ ] `SmartStore.podspec` - Update SmartStore's SQLCipher dependency
- [ ] `SmartStore.xcodeproj` - Update the dependency for the workspace
- [ ] `mobilesdk_pods.rb` - Update the dependency for podfiles
- [ ] Version test files (if they exist) - Update expected versions
- [ ] SmartStore API implementation files - Check for API changes
- [ ] Run full SmartStore test suite
- [ ] Run full MobileSync test suite
- [ ] Verify on multiple iOS versions (min deployment target to latest)

## Key Files Reference

**Build Configuration:**
- `SmartStore.podspec` - SmartStore pod specification
- `SalesforceMobileSDK.xcworkspace` - Xcode workspace

**Source Files (Objective-C):**
- `libs/SmartStore/SmartStore/Classes/SFSmartStore.h` - Main interface
- `libs/SmartStore/SmartStore/Classes/SFSmartStore.m` - Main implementation
- `libs/SmartStore/SmartStore/Classes/SFSoupIndex.h` - Indexing
- `libs/SmartStore/SmartStore/Classes/SFQuerySpec.h` - Queries

**Source Files (Swift):**
- `libs/SmartStore/SmartStore/Classes/Store/SFSmartStoreDatabaseManager.swift` - Database management
- `libs/SmartStore/SmartStore/Classes/Store/SFSmartStoreEncryption.swift` - Encryption

**Test Files:**
- `libs/SmartStore/SmartStoreTests/` - SmartStore test suite


## Notes

- SQLCipher updates are usually straightforward but can have subtle issues
- Always test thoroughly on real devices, not just simulators
- Check SQLCipher's GitHub issues before and after updating
- The community edition (default) includes "community" in the version string
- Crypto provider version changes are common and must be verified in tests
- Test with encrypted databases from previous SDK versions to ensure migration works

## Resources

- SQLCipher: https://www.zetetic.net/sqlcipher/
- SQLCipher iOS: https://github.com/sqlcipher/sqlcipher
- SQLCipher Releases: https://github.com/sqlcipher/sqlcipher/releases
- SQLCipher Documentation: https://www.zetetic.net/sqlcipher/documentation/
- CocoaPods: https://cocoapods.org/
- SmartStore docs: https://forcedotcom.github.io/SalesforceMobileSDK-iOS/Documentation/SmartStore/html/index.html
