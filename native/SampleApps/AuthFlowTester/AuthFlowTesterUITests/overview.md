# AuthFlowTester UI Tests Overview

This document provides an overview of all UI tests in the AuthFlowTester test suite.

## Test Classes

| Class | Description |
|-------|-------------|
| `LegacyLoginTests` | Tests for legacy login flows (CA, web server flow, and user agent flow) with default, subset, and all scopes, in-app WebView and external browser paths |
| `LegacyLoginTestsNotHybrid` | Tests for legacy login flows (non-hybrid) - extends `LegacyLoginTests` with `useHybridFlow` overridden to `false` |
| `ECALoginTests` | Tests for External Client App (ECA) login flows including negative testing with invalid configurations |
| `BeaconLoginTests` | Tests for Beacon app login flows (using regular_auth login host) |
| `AdvancedAuthBeaconLoginTests` | Tests for Beacon app login flows (using advanced_auth login host) |
| `WelcomeLoginTests` | Tests for welcome (domain discovery) login flows using simulated domain discovery |
| `ForceAdvancedAuthTests` | Tests for `SalesforceSDKManager.forceAdvancedAuthentication` flag — verifies it controls external browser vs in-app WebView |
| `LoginForAdminTests` | Tests for the "Login for Admins" menu flow, which launches OAuth in a browser while the in-app WebView remains loaded |
| `DPoPLoginTests` | Tests for DPoP-bound sessions, including basic login, RTR, multi-user, migration, and restart |
| `RTRLoginTests` | Tests for ECA login flows with Refresh Token Rotation (RTR), with and without hybrid flow, with and without app restart |
| `LoginWithRestartTests` | Tests for verifying that user sessions and per-user feature flags (BW, WD, B-markers, L-markers) persist across app restarts |
| `RefreshTokenMigrationTests` | Tests for refresh token migration between app configurations without re-authentication. Includes multi-user leakage detection (TM/A-marker isolation). |
| `RefreshTokenMigrationWithRestartTests` | Tests for verifying that migrated refresh tokens persist across app restarts |
| `MultiUserLoginTests` | Tests for multi-user login scenarios with various configurations, including token revocation and A-marker per-user isolation |

---

## Login Tests

### LegacyLoginTests (7 tests)

Tests for Connected App (CA) configurations with default, subset, and all scopes using hybrid authentication flow. Tests web server flow with both the external browser (default) and in-app WebView (`forceAdvancedAuthentication: false`), plus the user agent flow (also in-app WebView).

> **DPoP default note:** Mobile SDK 14 defaults DPoP **on** for new logins (`SalesforceSDKManager.useDPoP` defaults to `true`). Every case in this suite explicitly passes `useDPoP: false`, so it is the dedicated **Bearer (non-DPoP) compatibility suite** — the legacy CA flows continue to be exercised as they behaved before 14, independent of the new default. DPoP-bound coverage lives in `DPoPLoginTests`.

| Test Name | App Config | Scopes | Flow | Auth Surface |
|-----------|------------|--------|------|--------------|
| `testCAOpaque_DefaultScopes_WebServerFlow` | CA Opaque | Default | Web Server | Browser (default) |
| `testCAOpaque_SubsetScopes_WebServerFlow` | CA Opaque | Subset | Web Server | Browser (default) |
| `testCAOpaque_AllScopes_WebServerFlow` | CA Opaque | All | Web Server | Browser (default) |
| `testCAOpaque_DefaultScopes_WebServerFlow_InAppWebView` | CA Opaque | Default | Web Server | In-App WebView |
| `testCAOpaque_SubsetScopes_WebServerFlow_InAppWebView` | CA Opaque | Subset | Web Server | In-App WebView |
| `testCAOpaque_AllScopes_WebServerFlow_InAppWebView` | CA Opaque | All | Web Server | In-App WebView |
| `testCAOpaque_DefaultScopes_UserAgentFlow` | CA Opaque | Default | User Agent | In-App WebView |

### LegacyLoginTestsNotHybrid (7 tests)

Tests for Connected App (CA) configurations with non-hybrid authentication flow. Extends `LegacyLoginTests` and runs the same tests with `useHybridFlow` set to false. Non-hybrid flow means the app does not receive front-door session cookies (SIDs) during authentication.

| Test Name | App Config | Scopes | Flow | Auth Surface |
|-----------|------------|--------|------|--------------|
| `testCAOpaque_DefaultScopes_WebServerFlow` | CA Opaque | Default | Web Server | Browser (default) |
| `testCAOpaque_SubsetScopes_WebServerFlow` | CA Opaque | Subset | Web Server | Browser (default) |
| `testCAOpaque_AllScopes_WebServerFlow` | CA Opaque | All | Web Server | Browser (default) |
| `testCAOpaque_DefaultScopes_WebServerFlow_InAppWebView` | CA Opaque | Default | Web Server | In-App WebView |
| `testCAOpaque_SubsetScopes_WebServerFlow_InAppWebView` | CA Opaque | Subset | Web Server | In-App WebView |
| `testCAOpaque_AllScopes_WebServerFlow_InAppWebView` | CA Opaque | All | Web Server | In-App WebView |
| `testCAOpaque_DefaultScopes_UserAgentFlow` | CA Opaque | Default | User Agent | In-App WebView |

### ECALoginTests (9 tests)

Tests for External Client App (ECA) configurations using web server flow with hybrid auth. Includes negative testing scenarios for invalid client ID and invalid scopes.

| Test Name | App Config | Scopes | Description |
|-----------|------------|--------|-------------|
| `testECAOpaque_DefaultScopes` | ECA Opaque | Default | Standard login with default scopes |
| `testECAOpaque_SubsetScopes` | ECA Opaque | Subset | Standard login with subset scopes |
| `testECAOpaque_AllScopes` | ECA Opaque | All | Standard login with all scopes |
| `testECAJwt_DefaultScopes` | ECA JWT | Default | Standard login with default scopes |
| `testECAJwt_SubsetScopes` | ECA JWT | Subset | Standard login with subset scopes |
| `testECAJwt_AllScopes` | ECA JWT | All | Standard login with all scopes |
| `test_givenNoDPoP_whenLoginViaPoolServer_thenSessionIsValid` | ECA JWT | Default | Pool server login without DPoP; session valid with Bearer tokens |
| `testDynamicConfigurationWithInvalidClientId` | Invalid (dynamic) | Default | Negative test: invalid client ID in dynamic config |
| `testDynamicConfigurationWithInvalidScope` | ECA JWT (dynamic) | Invalid | Negative test: invalid scope in dynamic config |

### RTRLoginTests (8 tests)

Tests for ECA configurations with Refresh Token Rotation (RTR) enabled. Verifies that the refresh token rotates on each token refresh (RTR apps) and that sessions survive app restarts. The `assertRevokeAndRefreshWorks` check asserts the refresh token **changes** after a revoke/refresh cycle for RTR apps, and **stays the same** for non-RTR apps.

| Test Name | App Config | Hybrid | Restart |
|-----------|------------|--------|---------|
| `testECAJwtRtr_Hybrid` | ECA JWT RTR | Yes | No |
| `testECAJwtRtr_Hybrid_WithRestart` | ECA JWT RTR | Yes | Yes |
| `testECAJwtRtr_NoHybrid` | ECA JWT RTR | No | No |
| `testECAJwtRtr_NoHybrid_WithRestart` | ECA JWT RTR | No | Yes |
| `testECAOpaqueRtr_Hybrid` | ECA Opaque RTR | Yes | No |
| `testECAOpaqueRtr_Hybrid_WithRestart` | ECA Opaque RTR | Yes | Yes |
| `testECAOpaqueRtr_NoHybrid` | ECA Opaque RTR | No | No |
| `testECAOpaqueRtr_NoHybrid_WithRestart` | ECA Opaque RTR | No | Yes |

### BeaconLoginTests (6 tests)

Tests for Beacon app configurations using web server flow with hybrid auth. Uses `regular_auth` login host.

| Test Name | App Config | Scopes |
|-----------|------------|--------|
| `testBeaconOpaque_DefaultScopes` | Beacon Opaque | Default |
| `testBeaconOpaque_SubsetScopes` | Beacon Opaque | Subset |
| `testBeaconOpaque_AllScopes` | Beacon Opaque | All |
| `testBeaconJwt_DefaultScopes` | Beacon JWT | Default |
| `testBeaconJwt_SubsetScopes` | Beacon JWT | Subset |
| `testBeaconJwt_AllScopes` | Beacon JWT | All |

### AdvancedAuthBeaconLoginTests (6 tests)

Tests for Beacon app configurations using web server flow with hybrid auth. Uses `advanced_auth` login host. Inherits all tests from `BeaconLoginTests` but runs them with advanced authentication.

| Test Name | App Config | Scopes | Login Host |
|-----------|------------|--------|------------|
| `testBeaconOpaque_DefaultScopes` | Beacon Opaque | Default | advanced_auth |
| `testBeaconOpaque_SubsetScopes` | Beacon Opaque | Subset | advanced_auth |
| `testBeaconOpaque_AllScopes` | Beacon Opaque | All | advanced_auth |
| `testBeaconJwt_DefaultScopes` | Beacon JWT | Default | advanced_auth |
| `testBeaconJwt_SubsetScopes` | Beacon JWT | Subset | advanced_auth |
| `testBeaconJwt_AllScopes` | Beacon JWT | All | advanced_auth |

### WelcomeLoginTests (4 tests)

Tests for welcome (domain discovery) login flows. Uses simulated domain discovery with welcome.salesforce.com as the login server.

| Test Name | Login Host | Dynamic Config |
|-----------|------------|----------------|
| `testWelcomeDiscovery_RegularAuthLoginHost` | regular_auth (simulated) | No |
| `testWelcomeDiscovery_AdvancedAuthLoginHost` | advanced_auth (simulated) | No |
| `testWelcomeDiscovery_RegularAuthLoginHost_DynamicConfig` | regular_auth (simulated) | Yes |
| `testWelcomeDiscovery_AdvancedAuthLoginHost_DynamicConfig` | advanced_auth (simulated) | Yes |

### LoginWithRestartTests (10 tests)

Tests for verifying that user sessions and per-user feature flags (BW, WD, B-markers, L-markers) persist across app restarts. Includes CA, ECA, and Beacon configurations with both static and dynamic settings. Each test logs in, terminates the app via `app.terminate()`, relaunches, and verifies that credentials and user-agent feature flags are reloaded correctly from disk.

| Test Name | App Config | Scopes | Config Type | Feature Flag | Multi-User |
|-----------|------------|--------|-------------|--------------|------------|
| `testCAOpaque_DefaultScopes_WithRestart` | CA Opaque | Default | Static | — | No |
| `testECAOpaque_DefaultScopes_WithRestart` | ECA Opaque | Default | Static | — | No |
| `testBeaconOpaque_DefaultScopes_WithRestart` | Beacon Opaque | Default | Static | — | No |
| `testECAJwt_DefaultScopes_DynamicConfiguration_WithRestart` | ECA JWT | Default | Dynamic | — | No |
| `testECAJwt_SubsetScopes_DynamicConfiguration_WithRestart` | ECA JWT | Subset | Dynamic | — | No |
| `testBeaconJwt_DefaultScopes_DynamicConfiguration_WithRestart` | Beacon JWT | Default | Dynamic | — | No |
| `testBeaconJwt_SubsetScopes_DynamicConfiguration_WithRestart` | Beacon JWT | Subset | Dynamic | — | No |
| `testAdvancedAuth_WithRestart` | Beacon Opaque | Default | Static | BW + B4 | No |
| `testWelcomeDiscovery_WithRestart` | ECA Opaque | Default | Static | WD + L3 | No |
| `testMultiUserRestart` | ECA Opaque + ECA JWT | Default | Dynamic + Static | — | Yes |

---

## Migration Tests

### RefreshTokenMigrationTests (12 tests)

Tests for migrating refresh tokens between different app configurations without re-authentication. Tests can optionally specify the OAuth flow type (web server vs user agent) and hybrid flow setting to use during migration.

| Test Name | Original App | Migration App | Scope Change | Multi-User |
|-----------|--------------|---------------|--------------|------------|
| `testMigrateCA_AddMoreScopes` | CA JWT (subset) | CA JWT (all) | Yes | No |
| `testMigrateECA_AddMoreScopes` | ECA JWT (subset) | ECA JWT (all) | Yes | No |
| `testMigrateBeacon_AddMoreScopes` | Beacon JWT (subset) | Beacon JWT (all) | Yes | No |
| `testMigrateCAToBeacon` | CA Opaque | Beacon Opaque | No | No |
| `testMigrateBeaconToCA` | Beacon Opaque | CA Opaque | No | No |
| `testMigrateCAUserAgentToECAWebServer` | CA Opaque (user agent) | ECA Opaque (web server) | No | No |
| `testMigrateCAUserAgentToBeaconWebServer` | CA Opaque (user agent) | Beacon Opaque (web server) | No | No |
| `testMigrateCAToECA` | CA Opaque → ECA Opaque → CA Opaque | No | No |
| `testMigrateCAToBeaconAndBack` | CA Opaque → Beacon Opaque → CA Opaque | No | No |
| `testMigrateBeaconOpaqueToJWTAndBack` | Beacon Opaque → Beacon JWT → Beacon Opaque | No | No |
| `testFlagDiversity_MigratedBeaconJwtVsNonHybridOpaque` | User A: CA→Beacon JWT (A2+TM+JT+BN), User B: CA Opaque non-hybrid (A1+OT) | No | Yes |
| `testMigrateOneUserOnly` | User A: CA→ECA, User B: CA (unchanged) | No | Yes |

### RefreshTokenMigrationWithRestartTests (5 tests)

Tests for verifying that migrated refresh tokens persist across app restarts. Combines migration scenarios with app restart validation.

| Test Name | Original App | Migration App | Scope Change | Multi-User |
|-----------|--------------|---------------|--------------|------------|
| `testMigrateCAToECA_WithRestart` | CA Opaque | ECA Opaque | No | No |
| `testMigrateCAToBeacon_WithRestart` | CA Opaque | Beacon Opaque | No | No |
| `testMigrateScopeAddition_WithRestart` | ECA JWT (subset) | ECA JWT (all) | Yes | No |
| `testMigrateBeaconScopeAddition_WithRestart` | Beacon JWT (subset) | Beacon JWT (all) | Yes | No |
| `testMigrateMultipleUsers_WithRestart` | User A: CA→ECA, User B: Beacon | No | Yes |

---

## Multi-User Tests

### MultiUserLoginTests (15 tests)

Tests for login scenarios with two users using various configurations, including token revocation, user logout scenarios, and A-marker per-user isolation.

**A-marker isolation note**: all earlier multi-user tests happen to use the same app type for both users, producing identical A-markers (A2). The two `testFlagDiversity_*` tests below deliberately diverge the auth-flow type (non-hybrid vs hybrid) and token-format flags (OT vs JT) so that per-user flag leakage is detectable.

| Test Name | User 1 Config | User 2 Config | Same App | Same Scopes | Beacon | Action |
|-----------|---------------|---------------|----------|-------------|--------|--------|
| `testBothStatic_SameApp_SameScopes` | Static (Opaque) | Static (Opaque) | Yes | Yes | No | None |
| `testBothStatic_DifferentApps` | Static (Opaque) | Static (JWT) | No | Yes | No | None |
| `testBothStatic_SameApp_DifferentScopes` | Static (Opaque, subset) | Static (Opaque, default) | Yes | No | No | None |
| `testFirstStatic_SecondDynamic_DifferentApps` | Static (Opaque) | Dynamic (JWT) | No | Yes | No | None |
| `testFirstDynamic_SecondStatic_DifferentApps` | Dynamic (JWT) | Static (Opaque) | No | Yes | No | None |
| `testBothDynamic_DifferentApps` | Dynamic (Opaque) | Dynamic (JWT) | No | Yes | No | None |
| `testBeaconAndNonBeacon_MultiUser` | Beacon (Opaque) | CA (Opaque) | No | Yes | Yes | None |
| `testRevokeAccessForUserWithDynamicConfig_OtherUserUnaffected` | ECA (Opaque) static | ECA (JWT) dynamic | No | Yes | No | Revoke User B |
| `testDifferentAppTypes_RevokeAccessForCaUser_EcaUserUnaffected` | CA (Opaque) | ECA (Opaque) | No | Yes | No | Revoke User A |
| `testLogoutUserWithDynamicConfig_OtherUserUnaffected` | ECA (Opaque) static | ECA (JWT) dynamic | No | Yes | No | Logout User B |
| `testDifferentAppTypes_LogoutCaUser_EcaUserUnaffected` | CA (Opaque) | ECA (Opaque) | No | Yes | No | Logout User A |
| `testFlagDiversity_NonHybridOpaqueVsHybridJwt` | CA Opaque non-hybrid (A1+OT) | ECA JWT hybrid (A2+JT) | No | Yes | No | Logout User B |
| `testFlagDiversity_BeaconNonHybridJwtVsHybridOpaque` | Beacon JWT non-hybrid (A1+JT+BN) | CA Opaque hybrid (A2+OT) | No | Yes | Partial | Logout User B |
| `testAdvancedAuthUser_HasBWFlag_RegularAuthUser_DoesNot` | ECA Opaque (regular, BW off) | Beacon Opaque (advanced auth, BW set) | No | Yes | Partial | Logout User B |
| `test_dpopAndNonDPoPUsers_flagOff_maintainIndependentProofs` | ECA JWT DPoP (User A) | ECA JWT Bearer (User B) | No | Yes | No | DPoP flag flip + restart; Logout User B |

---

## Scope Definitions

| Scope Type | Description |
|------------|-------------|
| **Default** | No scopes requested (all scopes defined in server config should be granted) |
| **Subset** | Explicitly requests all scopes except for sfap_api |
| **All** | Explicitly requests all scopes |
| **Invalid** | Requests "invalid_scope" for negative testing scenarios |

## App Configuration Types

| App Type | Token Format | Description |
|----------|--------------|-------------|
| **CA** | Opaque/JWT | Connected App |
| **ECA** | Opaque/JWT | External Client App |
| **ECA RTR** | Opaque/JWT | External Client App with Refresh Token Rotation enabled |
| **Beacon** | Opaque/JWT | Beacon App |

### Configuration Modes

| Mode | Description |
|------|-------------|
| **Static** | Using Login Options "static config" - equivalent to having the settings in bootconfig |
| **Dynamic** | Using Login Options "dynamic config" - only used for that login flow |

## Available App Configurations

| Config Name | App Type | Token | Scopes |
|-------------|----------|-------|--------|
| `ecaOpaque` | ECA | Opaque | `api content id lightning refresh_token sfap_api visualforce web` |
| `ecaJwt` | ECA | JWT | `api content id lightning refresh_token sfap_api visualforce web` |
| `ecaOpaqueRtr` | ECA RTR | Opaque | `api content id lightning refresh_token sfap_api web` |
| `ecaJwtRtr` | ECA RTR | JWT | `api content id lightning refresh_token sfap_api web` |
| `beaconOpaque` | Beacon | Opaque | `api content id lightning refresh_token sfap_api web` |
| `beaconJwt` | Beacon | JWT | `api content id lightning refresh_token sfap_api web` |
| `caOpaque` | CA | Opaque | `api content id lightning refresh_token sfap_api visualforce web` |
| `caJwt` | CA | JWT | `api content id lightning refresh_token sfap_api visualforce web` |
| `invalid` | Invalid | N/A | `invalid_scope` (for negative testing) |

### Token Formats

| Format | Description |
|--------|-------------|
| **Opaque** | Opaque access tokens |
| **JWT** | JSON Web Token based access tokens |

### OAuth Flow Types

| Flow Type | Description |
|-----------|-------------|
| **Web Server Flow** | OAuth 2.0 web server flow (authorization code flow) - default |
| **User Agent Flow** | OAuth 2.0 user agent flow (implicit flow) |

### Hybrid Flow

| Setting | Description |
|---------|-------------|
| **Hybrid** | Authentication includes front-door session cookies (SIDs) for Lightning, Visualforce, and Content domains |
| **Non-Hybrid** | Authentication without front-door session cookies |

## Login Hosts

The test suite supports testing against different Salesforce org configurations with different authentication mechanisms. The login host configuration is specified in `ui_test_config.json` under the `loginHosts` array.

| Login Host | Description | Authentication Mechanism |
|------------|-------------|-------------------------|
| **regular_auth** | Org configured to use regular authentication | Authentication through web view |
| **advanced_auth** | Org configured to use native browser for authentication | ASWebAuthenticationSession on iOS |

Most tests use the `regular_auth` login host by default. The `AdvancedAuthBeaconLoginTests` class runs the same Beacon login tests but uses the `advanced_auth` login host to verify authentication flows work correctly with native browser authentication. The `WelcomeLoginTests` use simulated domain discovery with welcome.salesforce.com as the login server to test the welcome/domain discovery flow.

---

## B- and L-markers in `ftr_`

Each `validateUserAgent` call verifies two telemetry code families in the `ftr_` segment of the user-agent string (W-23701450).

### B-markers — why browser login was used

Registered once per user alongside the BW (browser-windows) flag. Exactly one is set when `ASWebAuthenticationSession` login occurred; none are set for in-app WKWebView login. When `expectedBMarker` is `nil` in `validateUserAgent`, the assertion is skipped.

| Code | Constant | Meaning | Priority |
|------|----------|---------|----------|
| B1 | `kSFAppFeatureBrowserLoginServerAuthConfig` | Server auth-config required browser login | Lowest |
| B2 | `kSFAppFeatureBrowserLoginMDM` | MDM (useBrowserAuth) required browser login | — |
| B3 | `kSFAppFeatureBrowserLoginForAdmin` | "Login for Admin" flow used | Highest |
| B4 | `kSFAppFeatureBrowserLoginForceFlag` | `SalesforceSDKManager.forceAdvancedAuthentication` was set | — |

Priority order when multiple reasons apply: **B3 > B2 > B4 > B1**.

### L-markers — which login server type was used

Registered on every non-refresh login. Exactly one is set per login.

| Code | Constant | Meaning |
|------|----------|---------|
| L1 | `kSFAppFeatureLoginServerProduction` | Production pool server (`login.salesforce.com` and internal pool equivalents) |
| L2 | `kSFAppFeatureLoginServerSandbox` | Sandbox (`test.salesforce.com`) |
| L3 | `kSFAppFeatureLoginServerWelcomeDiscovery` | Welcome Discovery flow was used |
| L4 | `kSFAppFeatureLoginServerMyDomain` | My Domain org (`.my.` in the host) |
| L5 | `kSFAppFeatureLoginServerOther` | Any other login server |

L3 takes priority over the resolved domain: even if Welcome Discovery resolves to a My Domain org, the final L-marker is L3 (captured before the WD global flag is cleared).

The marker constants are defined in `SFSDKAppFeatureMarkers.m`. Local string copies used in the UI test helper (`BaseAuthFlowTester.swift`) match those constants exactly.
