# AuthFlowTester

A native iOS sample app for the Salesforce Mobile SDK that serves as the primary vehicle for **UI automation testing** of authentication flows. The app displays OAuth credentials, token details, and user information after login, enabling end-to-end validation of the SDK's authentication infrastructure.

## UI Test Coverage

Tests are run via GitHub Actions using the `AuthFlowTester` Xcode scheme and `xcodebuild test` on iOS Simulator.

### Test Suites

#### LegacyLoginTests
Legacy login tests using the default Connected App (CA) opaque configuration from the app's boot config.

| Test | App Config | Scopes | Auth Surface |
|------|-----------|--------|--------------|
| `testCAOpaque_DefaultScopes_WebServerFlow` | CA Opaque | Default | ASWebAuthenticationSession |
| `testCAOpaque_SubsetScopes_WebServerFlow` | CA Opaque | Subset | ASWebAuthenticationSession |
| `testCAOpaque_AllScopes_WebServerFlow` | CA Opaque | All | ASWebAuthenticationSession |
| `testCAOpaque_DefaultScopes_WebServerFlow_InAppWebView` | CA Opaque | Default | In-App WKWebView |
| `testCAOpaque_SubsetScopes_WebServerFlow_InAppWebView` | CA Opaque | Subset | In-App WKWebView |
| `testCAOpaque_AllScopes_WebServerFlow_InAppWebView` | CA Opaque | All | In-App WKWebView |
| `testCAOpaque_DefaultScopes_UserAgentFlow` | CA Opaque | Default | In-App WKWebView |

#### ECALoginTests
External Client App (ECA) login tests for both opaque and JWT token formats with scope variations. Also covers pool server login (non-DPoP) and negative-path dynamic config tests.

| Test | App Config | Scopes | Notes |
|------|-----------|--------|-------|
| `testECAOpaque_DefaultScopes` | ECA Opaque | Default | |
| `testECAOpaque_SubsetScopes` | ECA Opaque | Subset | |
| `testECAOpaque_AllScopes` | ECA Opaque | All | |
| `testECAJwt_DefaultScopes` | ECA JWT | Default | |
| `testECAJwt_SubsetScopes` | ECA JWT | Subset | |
| `testECAJwt_AllScopes` | ECA JWT | All | |
| `test_givenNoDPoP_whenLoginViaPoolServer_thenSessionIsValid` | ECA JWT DPoP | — | Pool server login without DPoP |
| `testDynamicConfigurationWithInvalidClientId` | — | — | Invalid consumer key; login must fail |
| `testDynamicConfigurationWithInvalidScope` | — | — | Invalid scope; login must fail |

#### DPoPLoginTests
All DPoP tests live here — basic login, RTR, multi-user, migration, restart, pool server, and admin login. Verifies that DPoP-bound access tokens are issued (`token_type: "DPoP"`), API calls succeed with `ath`-bound proofs, the access token refreshes correctly, and the DPoP nonce rotates on every `/token` response.

| Test | App Config | Hybrid | Notes |
|------|-----------|--------|-------|
| `test_givenDPoPHybrid_whenLogin_thenTokenTypeIsDPoPAndRefreshWorks` | ECA JWT DPoP | Yes | |
| `test_givenDPoPNoHybrid_whenLogin_thenTokenTypeIsDPoPAndRefreshWorks` | ECA JWT DPoP | No | |
| `test_givenDPoPRtrHybrid_whenLogin_pendingServerFix` | ECA JWT DPoP RTR | Yes | `XCTSkip` (pending server fix for Named JWTs + RTR + hybrid) |
| `test_givenDPoPRtrNoHybrid_whenLogin_thenRefreshTokenRotatesAndDPoPBindingHolds` | ECA JWT DPoP RTR | No | DPoP + refresh token rotation |
| `test_givenTwoDPoPUsers_whenSwitchAndRefresh_thenTokensAndNoncesAreIsolated` | ECA JWT DPoP | — | Two users; unique tokens and nonces; independent revoke+refresh per user |
| `test_givenDPoPUserWithSubsetScopes_whenMigrateToAllScopes_thenDPoPBindingPreserved` | ECA JWT DPoP | — | Scope upgrade; DPoP binding preserved |
| `test_givenDPoPUser_whenMigrateToDPoPRtr_thenRefreshTokenRotationEnabled` | ECA JWT DPoP → ECA JWT DPoP RTR | — | Migrate from DPoP to DPoP+RTR |
| `test_givenDPoPUser_whenAppRestart_thenSessionAndKeypairSurvive` | ECA JWT DPoP | — | `XCTSkip` (pending SDK fix — RestClient path lacks nonce-challenge retry; post-restart DPoP revoke fails because in-memory nonce cache is empty) |
| `test_givenDPoP_whenLoginViaPoolServer_thenTokenTypeIsDPoP` | ECA JWT DPoP | — | `XCTSkip` (W-23864247 — pool login server rejects valid `dpop_jkt` token exchange) |
| `test_givenDPoPECA_whenAdminLogin_thenDPoPBindingWorksThroughBrowser` | ECA JWT DPoP | — | Login for Admins hand-off to ASWebAuthenticationSession works with DPoP binding |

#### RTRLoginTests
Tests for ECA configurations with Refresh Token Rotation (RTR) enabled. Verifies that the refresh token rotates on each token refresh cycle. DPoP+RTR tests live in `DPoPLoginTests`.

| Test | App Config | Hybrid | Notes |
|------|-----------|--------|-------|
| `testECAJwtRtr_Hybrid` | ECA JWT RTR | Yes | |
| `testECAJwtRtr_Hybrid_WithRestart` | ECA JWT RTR | Yes | Session survives restart |
| `testECAJwtRtr_NoHybrid` | ECA JWT RTR | No | |
| `testECAJwtRtr_NoHybrid_WithRestart` | ECA JWT RTR | No | Session survives restart |
| `testECAOpaqueRtr_Hybrid` | ECA Opaque RTR | Yes | |
| `testECAOpaqueRtr_Hybrid_WithRestart` | ECA Opaque RTR | Yes | Session survives restart |
| `testECAOpaqueRtr_NoHybrid` | ECA Opaque RTR | No | |
| `testECAOpaqueRtr_NoHybrid_WithRestart` | ECA Opaque RTR | No | Session survives restart |

#### BeaconLoginTests
Beacon app login tests for lightweight authentication use cases, covering both opaque and JWT token formats.

| Test | App Config | Scopes |
|------|-----------|--------|
| `testBeaconOpaque_DefaultScopes` | Beacon Opaque | Default |
| `testBeaconOpaque_SubsetScopes` | Beacon Opaque | Subset |
| `testBeaconOpaque_AllScopes` | Beacon Opaque | All |
| `testBeaconJwt_DefaultScopes` | Beacon JWT | Default |
| `testBeaconJwt_SubsetScopes` | Beacon JWT | Subset |
| `testBeaconJwt_AllScopes` | Beacon JWT | All |

#### AdvancedAuthBeaconLoginTests
Runs the same tests as `BeaconLoginTests` but uses the advanced auth login host (`advanced_auth`). Verifies that the B4 marker (`forceAdvancedAuthentication`) is present in the `ftr_` user-agent segment and that ASWebAuthenticationSession is used.

#### ForceAdvancedAuthTests
Tests for the `forceAdvancedAuthentication` SDK flag, which forces browser-based login (ASWebAuthenticationSession) even on servers that do not require it.

| Test | Description |
|------|-------------|
| `testForceAdvancedAuth_StandardServer_LaunchesExternalBrowser` | Flag on: standard server uses ASWebAuthenticationSession |
| `testForceAdvancedAuth_Disabled_StandardServer_UsesInAppWebView` | Flag off: standard server uses in-app WKWebView |
| `testForceAdvancedAuth_MyDomainRegularHost_RemainsBrowser` | My Domain host stays in browser even after flag toggled off at runtime |
| `testForceAdvancedAuth_AddAdditionalUser_BackButtonAccessible` | Back button accessible after adding a second user in advanced auth |
| `testForceAdvancedAuth_DefaultOn_LoginOptionsReachable` | Login Options gear reachable when forceAdvancedAuthentication is on |
| `testForceAdvancedAuth_Disabled_BackAndGearStillPresent` | Back button and gear remain when flag disabled mid-session |

#### LoginForAdminTests
Tests for the "Login for Admin" menu flow, which launches OAuth in SFSafariViewController while the in-app WKWebView remains loaded. The DPoP variant lives in `DPoPLoginTests`.

| Test | Description |
|------|-------------|
| `testLoginForAdmin_WebServerFlowEnabled` | Custom tab URL matches WebView URL |
| `testLoginForAdmin_WebServerFlowDisabled` | Custom tab forces Web Server Flow despite WebView config |

#### MultiUserLoginTests
End-to-end tests for multi-user scenarios: logging in two users, switching between them, and validating that each user's tokens and OAuth configuration are preserved independently.

| Test | Description |
|------|-------------|
| `testBothStatic_SameApp_SameScopes` | Two users on same CA Opaque app; unique tokens and user switching |
| `testBothStatic_DifferentApps` | Two users on different static apps (CA + ECA) |
| `testBothStatic_SameApp_DifferentScopes` | Two users on same app with different scopes |
| `testFirstStatic_SecondDynamic_DifferentApps` | First user on boot config (CA), second on dynamic config (ECA JWT) |
| `testFirstDynamic_SecondStatic_DifferentApps` | First user on dynamic config (ECA JWT), second on boot config (CA) |
| `testBothDynamic_DifferentApps` | Both users on dynamic configs with different apps |
| `testBeaconAndNonBeacon_MultiUser` | Beacon and non-Beacon users coexist; Beacon child-key isolation |
| `testRevokeAccessForUserWithDynamicConfig_OtherUserUnaffected` | Revoke dynamic-config user's access; static user unaffected |
| `testDifferentAppTypes_RevokeAccessForCaUser_EcaUserUnaffected` | Revoke CA user's access; ECA user unaffected |
| `testLogoutUserWithDynamicConfig_OtherUserUnaffected` | Logout dynamic-config user; static user unaffected |
| `testDifferentAppTypes_LogoutCaUser_EcaUserUnaffected` | Logout CA user; ECA user unaffected |
| `testFlagDiversity_NonHybridOpaqueVsHybridJwt` | User A: non-hybrid+OT; User B: hybrid+JT; validates per-user flag isolation |
| `testFlagDiversity_BeaconNonHybridJwtVsHybridOpaque` | User A: beacon+non-hybrid+JT; User B: hybrid+OT; validates A-marker and BN isolation |
| `testAdvancedAuthUser_HasBWFlag_RegularAuthUser_DoesNot` | One user on advanced auth (BW flag set), one on regular auth |
| `test_dpopAndNonDPoPUsers_flagOff_maintainIndependentProofs` | DPoP and non-DPoP users coexist; toggling DPoP off for second user does not affect first |

#### RefreshTokenMigrationTests
Tests the SDK's refresh token migration flow. Validates that tokens are replaced and the new tokens are functional.

| Test | Description |
|------|-------------|
| `testMigrateCA_AddMoreScopes` | Scope upgrade within the same CA JWT app |
| `testMigrateECA_AddMoreScopes` | Scope upgrade within the same ECA JWT app |
| `testMigrateBeacon_AddMoreScopes` | Scope upgrade within the same Beacon JWT app |
| `testMigrateCAToBeacon` | Migrate from CA Opaque to Beacon Opaque |
| `testMigrateBeaconToCA` | Migrate from Beacon Opaque to CA Opaque |
| `testMigrateCAUserAgentToECAWebServer` | Migrate CA (user agent) → ECA with extended scopes |
| `testMigrateCAUserAgentToBeaconWebServer` | Migrate CA (user agent) → Beacon with extended scopes |
| `testMigrateCAToECA` | Migrate CA → ECA → CA (with rollback) |
| `testMigrateCAToBeaconAndBack` | Migrate CA → Beacon → CA (with rollback) |
| `testMigrateBeaconOpaqueToJWTAndBack` | Migrate Beacon Opaque → JWT → Opaque (with rollback) |
| `testFlagDiversity_MigratedBeaconJwtVsNonHybridOpaque` | Flag isolation after migration: Beacon JWT user vs non-hybrid opaque user |
| `testMigrateOneUserOnly` | Migrate one user's tokens while the other remains unaffected |

#### WelcomeLoginTests
Tests for the Welcome Discovery login flow.

| Test | Login Host | App Config |
|------|-----------|-----------|
| `testWelcomeDiscovery_RegularAuthLoginHost` | Regular Auth | ECA Opaque |
| `testWelcomeDiscovery_AdvancedAuthLoginHost` | Advanced Auth | Beacon Opaque |
| `testWelcomeDiscovery_RegularAuthLoginHost_DynamicConfig` | Regular Auth | ECA Opaque (dynamic) |
| `testWelcomeDiscovery_AdvancedAuthLoginHost_DynamicConfig` | Advanced Auth | Beacon Opaque (dynamic) |

#### LoginWithRestartTests
Tests that user sessions and per-user feature flags persist across a cold app restart. Each test logs in, kills the app process, relaunches, and verifies that session credentials and feature flags are reloaded correctly. The DPoP restart test lives in `DPoPLoginTests`.

| Test | App Config | Config Type | Feature Flag |
|------|-----------|-------------|--------------|
| `testCAOpaque_DefaultScopes_WithRestart` | CA Opaque | Static | — |
| `testECAOpaque_DefaultScopes_WithRestart` | ECA Opaque | Static | — |
| `testBeaconOpaque_DefaultScopes_WithRestart` | Beacon Opaque | Static | — |
| `testECAJwt_DefaultScopes_DynamicConfiguration_WithRestart` | ECA JWT | Dynamic | — |
| `testECAJwt_SubsetScopes_DynamicConfiguration_WithRestart` | ECA JWT | Dynamic | — |
| `testBeaconJwt_DefaultScopes_DynamicConfiguration_WithRestart` | Beacon JWT | Dynamic | — |
| `testBeaconJwt_SubsetScopes_DynamicConfiguration_WithRestart` | Beacon JWT | Dynamic | — |
| `testAdvancedAuth_WithRestart` | Beacon Opaque | Static | BW |
| `testWelcomeDiscovery_WithRestart` | ECA Opaque | Static | WD |
| `testMultiUserRestart` | ECA Opaque + ECA JWT | Mixed | — |

### Validation Per Test

Each `launchLoginAndValidate` call performs the following checks:
1. **User identity** — username matches the expected test user
2. **OAuth values** — consumer key, scopes granted, and token format (opaque vs JWT) match the app configuration
3. **API request** — a REST API call succeeds with the issued tokens
4. **DPoP (DPoP apps only)** — `OAuth Token Type` is `"DPoP"` and the DPoP nonce is non-empty after login

`assertRevokeAndRefreshWorks` additionally verifies for DPoP apps:
- **Token type preserved** — `OAuth Token Type` remains `"DPoP"` after refresh
- **Nonce rotated** — the DPoP nonce changes after each token refresh cycle

Migration tests additionally verify:
- Access and refresh tokens are **replaced** (not reused)
- A **token refresh** succeeds after revoking the new access token

Multi-user tests additionally verify:
- Tokens are **unique** across users
- **User switching** preserves each user's tokens and OAuth configuration
- **Token refresh** targets the correct user after switching

Restart tests additionally verify:
- Session credentials are **reloaded from disk** after a cold process restart
- Per-user feature flags encoded in the user agent string **persist** across restarts
- DPoP EC key pairs stored in **Keychain** survive a process kill and restart

## Architecture

### Test Infrastructure

| Component | Description |
|-----------|-------------|
| `BaseAuthFlowTester` | Base class providing `launchLoginAndValidate`, `assertRevokeAndRefreshWorks`, `migrateAndValidate`, and `restartAndValidate` orchestration. Uses `XCUIApplication` + `XCTest`. |
| `UITestConfig` | Deserializes `ui_test_config.json` (from `shared/test/`) into typed config structs. |

### Configuration

- **App configs**: `ecaOpaque`, `ecaJwt`, `ecaOpaqueRtr`, `ecaJwtRtr`, `ecaJwtDpop`, `ecaJwtDpopRtr`, `beaconOpaque`, `beaconJwt`, `caOpaque`
- **Login hosts**: `regularAuth` (in-app WKWebView), `advancedAuth` (ASWebAuthenticationSession)
- **Users**: `first` through `fifth`

> **Note:** A valid `shared/test/ui_test_config.json` file with login host URLs, user credentials, and app configurations is required to run the tests.
