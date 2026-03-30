# CLAUDE.md — Salesforce Mobile SDK

---

## About This Project

The Salesforce Mobile SDK is a public, open-source SDK that enables developers to build mobile apps that integrate with the Salesforce platform. It is consumed by ISVs, SI partners, and internal Salesforce teams.

**Key constraint**: This is a **public SDK**. Every change is visible to external developers. Backward compatibility, deprecation cycles, and semver discipline are non-negotiable.

## iOS Library Architecture

Workspace: `SalesforceMobileSDK.xcworkspace`

Libraries live under `libs/` with the following dependency hierarchy (arrows = "depends on"):

```
MobileSync
  └── SmartStore
       └── SalesforceSDKCore
            └── SalesforceAnalytics
                 └── SalesforceSDKCommon
```

### Library Descriptions

| Library | Path | Purpose |
|---------|------|---------|
| **SalesforceAnalytics** | `libs/SalesforceAnalytics/` | Telemetry, instrumentation, and analytics event tracking |
| **SalesforceSDKCommon** | `libs/SalesforceSDKCommon/` | Shared utilities, crypto helpers, and base protocols |
| **SalesforceSDKCore** | `libs/SalesforceSDKCore/` | OAuth2 authentication, identity, REST client (`RestClient`/`SFRestAPI`), account management, `SalesforceSDKManager`, push notifications, login UI, app lifecycle |
| **SmartStore** | `libs/SmartStore/` | Encrypted on-device SQLite storage (backed by SQLCipher). Soup-based data model with indexing and Smart SQL query support |
| **MobileSync** | `libs/MobileSync/` | Bidirectional data sync between device (SmartStore) and Salesforce cloud. Sync targets, sync managers, layout/metadata sync. `MobileSyncSDKManager` |

### iOS Reference Docs
- [SalesforceAnalytics](https://forcedotcom.github.io/SalesforceMobileSDK-iOS/Documentation/SalesforceAnalytics/html/index.html)
- [SalesforceSDKCommon](https://forcedotcom.github.io/SalesforceMobileSDK-iOS/Documentation/SalesforceSDKCommon/html/index.html)
- [SalesforceSDKCore](https://forcedotcom.github.io/SalesforceMobileSDK-iOS/Documentation/SalesforceSDKCore/html/index.html)
- [SmartStore](https://forcedotcom.github.io/SalesforceMobileSDK-iOS/Documentation/SmartStore/html/index.html)
- [MobileSync](https://forcedotcom.github.io/SalesforceMobileSDK-iOS/Documentation/MobileSync/html/index.html)

### iOS Build Details
- **Minimum target**: iOS 17.0
- **Workspace**: `SalesforceMobileSDK.xcworkspace` (open this, not individual `.xcodeproj` files)
- **Setup**: Run `./install.sh` after cloning to pull submodule dependencies
- **Dependency management**: CocoaPods (podspecs at repo root) + Swift Package Manager
- **Encryption**: SmartStore depends on SQLCipher. Supports SQLCipher Community, Commercial, Enterprise, and Enterprise FIPS editions.
- **Language**: Swift for all new code. Legacy Objective-C exists in older classes. No new Obj-C files.
- **Schemes**: Individual per library (`SalesforceSDKCore`, `SmartStore`, `MobileSync`, etc.) plus test schemes

### iOS Build & Test Commands
```bash
# Initial setup (after clone)
./install.sh

# Build a specific scheme
xcodebuild -workspace SalesforceMobileSDK.xcworkspace \
  -scheme SalesforceSDKCore \
  -sdk iphonesimulator \

# Run tests for a specific library
xcodebuild test -workspace SalesforceMobileSDK.xcworkspace \
  -scheme SalesforceSDKCore \
  -sdk iphonesimulator \

# Run tests for SmartStore
xcodebuild test -workspace SalesforceMobileSDK.xcworkspace \
  -scheme SmartStore \
  -sdk iphonesimulator \

# Run tests for MobileSync
xcodebuild test -workspace SalesforceMobileSDK.xcworkspace \
  -scheme MobileSync \
  -sdk iphonesimulator \

# Static analysis (Clang)
# Results output to libs/<Library>/clangReport/StaticAnalyzer/
```

---

## Code Standards

### General Rules (Both Platforms)
- **Public API changes require a deprecation cycle**. Deprecate in release N, remove no earlier than release N+2 (next major). Always use `@available(*, deprecated)` (Swift) or `@Deprecated` (Kotlin) with a message explaining the replacement.
- **No hardcoded secrets, tokens, or PII in source**. Not even in test fixtures — use test-scoped configuration.
- **Never log PII, refresh tokens, or full request/response bodies**. Use the SDK's own telemetry APIs.
- **Compiler warnings are bugs**. Fix all warnings before submitting a PR. Pay special attention to deprecation warnings from upstream SDK versions.
- **Localization**: New user-facing strings must be added to localization files (`Localizable.strings`). Flag new strings in the PR description.

### iOS-Specific
- **Swift for all new code**. No new Objective-C files.
- **No force unwraps (`!`)**
- **Async/await preferred** over completion handlers. Completion-based methods are being deprecated in favor of async/await (ongoing since 13.0).
- **`RestClient`** is the single entry point for REST API calls. As of 13.1, direct `URLRequest` is also supported. Don't create custom `URLSession` instances.
- **Prefix public ObjC-visible types** with `SF` (legacy) or use Swift namespacing for new types.

### Naming Conventions
- **Classes/Structs/Protocols**: `PascalCase`
- **Functions/Methods/Properties**: `camelCase`

---

## Testing Standards

### Unit Tests
- **iOS**: XCTest. Test targets per library scheme.
- **Coverage target**: 80% line coverage for new code. Never decrease existing coverage.
- **Naming**: `test_given[Precondition]_when[Action]_then[Expected]`
- **Focus on behavior**: Test public API contracts. Test how consumers will use the SDK, not internal state.
- **Mock boundaries, not internals**: Mock network responses, keychain/keystore access, SQLCipher, and system services. Do not mock the class under test.
- **Edge cases are mandatory**: Null/empty inputs, expired tokens, network failures, SQLCipher encryption errors, concurrent access to SmartStore soups.
- **No flaky tests**: Tests must be deterministic. No `Thread.sleep()` / `Task.sleep()` / hardcoded delays. Use controlled dispatchers/schedulers and XCTest expectations with timeouts.
- **Test data cleanup**: Every test must clean up created soups, user accounts, and cached data. Use `setUp`/`tearDown` rigorously.

### What to Test for Each Library

**SalesforceSDKCore / SalesforceSDK (Core)**:
- OAuth2 flow: token refresh, token revocation, session expiry, multi-user account switching
- REST client: request construction, response parsing, error handling (401→refresh, 403, network errors)
- Identity service: user info retrieval, community user handling
- Push notification registration/deregistration
- App lifecycle: foreground/background transitions, biometric unlock, passcode lock
- Login UI: host picker, custom tabs (Android), QR code login, welcome domain login

**SmartStore**:
- Soup CRUD: create, read, update, upsert, delete
- Indexing: index creation, index migration, query performance
- Smart SQL: query construction, aggregation, joins across soups
- Encryption: database open/close with correct key, key rotation, SQLCipher edition compatibility
- Concurrency: simultaneous reads/writes from multiple threads
- Migration: upgrade path from older SmartStore versions

**MobileSync**:
- Sync down: SOQL targets, MRU targets, layout targets, metadata targets
- Sync up: create/update/delete records, batch sync, advanced sync, conflict detection
- Parent-child relationships: sync up with related records
- Clean ghosts: remove server-deleted records from local store

### When Generating Tests
1. Read this file first for project conventions.
2. Identify which library the code belongs to and match existing test patterns in that library's test target.
3. Follow BDD naming: `test_given[Precondition]_when[Action]_then[Expected]`
4. Use existing test utilities and mocks already in the test targets. Don't create parallel mock infrastructure.
5. Run the full test suite for the affected library after generation. Fix failures before committing.
6. If the code under test requires an External Client App or sandbox org, note this clearly in the test documentation.
7. If test generation reveals tightly coupled or untestable code, flag this in the PR description as a refactoring opportunity — do not restructure production code just to make tests pass.

---

## Code Review Checklist

When reviewing PRs (or acting as an AI reviewer), verify:

- [ ] **Backward compatibility**: Does this change break any existing public API? If an API is being changed, is the old version properly deprecated with a migration path?
- [ ] **Both platforms considered**: If this is a feature/fix that applies to both iOS and Android, is there a corresponding PR for the other platform?
- [ ] **Tests included**: New/changed behavior has corresponding test coverage in the correct test target.
- [ ] **No regressions**: Full test suite for the affected library passes.
- [ ] **Multi-user**: Does this work correctly with multiple logged-in accounts?
- [ ] **Localization**: Are new user-facing strings added to localization files? Are they called out in the PR description?
- [ ] **Security**: No hardcoded credentials, no PII logging, tokens handled securely, no new `NSAllowsArbitraryLoads` or cleartext traffic exceptions.
- [ ] **Performance**: No unnecessary main-thread work, no unbounded memory growth, no blocking network calls.
- [ ] **Deprecation warnings**: Does this PR introduce new deprecation warnings? Are existing warnings addressed?
- [ ] **Documentation**: Public APIs have doc comments. Breaking changes are called out for release notes.
- [ ] **Sample apps**: If changing public API, are sample and template apps (RestAPIExplorer, MobileSyncExplorerSwift, etc.) updated?

---

## Agent Behavior Guidelines

These rules apply when Claude Code operates as an agent in these repos:

### Do
- Always run the test suite for the affected library before creating a commit. Before running the suite, check that test_credentials.json or ui_test_config.json (for UI tests) exists in `shared/test`.
- When fixing a bug, write a failing test first, then fix the code.
- Check both iOS and Android repos when investigating a feature — the behavior should be consistent across platforms.
- Reference the public developer documentation at https://developer.salesforce.com/docs/platform/mobile-sdk/guide when understanding expected behavior.
- Flag any public API surface changes for human review — these have downstream impact on thousands of apps.
- Use `--allowedTools` restrictions in CI — limit to Read, Write, Grep, Glob, and the test runner.

### Don't
- Don't merge without human approval. This is a public SDK — every merge is a commitment to external developers.
- Don't modify `Podfile`, `*.podspec`, `.xcodeproj`/`.xcworkspace`, or CI configuration files without explicit human request.
- Don't add new third-party dependencies without flagging for human review and legal/license check.
- Don't suppress lint warnings, deprecation warnings, or test failures.
- Don't modify `install.sh` setup script.
- Don't remove deprecated APIs — they follow a release-cycle deprecation process. Only remove in major versions after the deprecation notice period.
- Don't bump minimum iOS version without team discussion.

### Escalation — Stop and Flag for Human Review
- Any change to the OAuth2 flow, token storage, or credential handling.
- Any change to SQLCipher integration, encryption keys, or keychain/keystore access.
- Any new public API or modification to an existing public API signature.
- Any change to the login UI flow or account switching behavior.
- Build system changes (Gradle, Xcode project, CocoaPods, SPM).
- Dependency version bumps (especially SQLCipher, Cordova).
- Changes affecting Privacy Manifests (iOS) or Android permission declarations.
- Any change that touches `Localizable.strings` (localization).
- Removal of any previously deprecated API.

---

## Key Domain Concepts

Understanding these concepts is essential for working in this codebase:

- **External Client App or Connected App (legacy)**: A Salesforce configuration that defines OAuth2 client credentials (consumer key, callback URI, scopes). Every Mobile SDK app requires one. External Client Apps are the preferred model.
- **Soup**: SmartStore's unit of storage — analogous to a database table. Has a name, index specs, and entries (JSON blobs).
- **Smart SQL**: SmartStore's SQL dialect for querying across soups. Uses `{soupName:fieldPath}` syntax.
- **Sync Target**: MobileSync's abstraction for defining what data to sync and how. Includes SOQL down targets, SOSL down targets, MRU targets, layout targets, metadata targets, and various up targets (standard, batch, advanced).
- **User Agent**: The SDK constructs a specific user agent string that identifies the SDK version, app type, and platform. Don't override this.
- **SalesforceSDKManager**: The singleton entry point for SDK configuration and lifecycle. Manages OAuth configuration settings, auth scopes, login behavior, and user account events.
- **Hybrid Authentication**: Uses session IDs from login/refresh endpoints (instead of frontdoor URLs) for loading app content in WebViews.
- **UI Bridge API**: Used to construct frontdoor URLs for opening Salesforce UIs in WebViews without re-authentication.
- **Advanced Authentication**: Native browser login, bypassing the standard WKWebView for orgs requiring it.
- **QR Code Login**: Allows login by scanning a QR code generated from a Salesforce setup page. Validates consumer key match.
- **WebSockets**: Client-side bidirectional TCP connections added in 13.1, working with SDK auth.

---

## Release Process Awareness

When working on code, be aware of these release patterns:

- **Major releases** (e.g., 13.0): May remove previously deprecated APIs. Include breaking changes documented in migration guides and "APIs Removed" pages.
- **Minor releases** (e.g., 13.1): New features and deprecations. Should not remove APIs. Document new deprecations clearly.
- **Patch releases** (e.g., 13.1.1): Bug fixes only. No API changes, no new features.
- **Deprecation notices**: Always check compiler warnings page ([iOS](https://developer.salesforce.com/docs/platform/mobile-sdk/guide/ios-current-deprecations.html).

---

## Related Documentation

- **Mobile SDK Development Guide**: https://developer.salesforce.com/docs/platform/mobile-sdk/guide
- **iOS Library References**: Links in iOS section above
- **Android Javadoc**: https://forcedotcom.github.io/SalesforceMobileSDK-Android/index.html
- **GitHub Repos**: https://github.com/forcedotcom (search `SalesforceMobileSDK`)
- **Migration Guides**: Published per major release in the developer guide
