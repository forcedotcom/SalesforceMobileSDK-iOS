# AuthFlowTester UI Tests Overview

This document provides an overview of all UI tests in the AuthFlowTester test suite.

## Test Classes

| Class | Description |
|-------|-------------|
| `LegacyLoginTests` | Tests for legacy login flows (CA, user agent flow, hybrid flow) with default, subset, and all scopes |
| `LegacyLoginTestsNotHybrid` | Tests for legacy login flows (CA, user agent flow, non-hybrid flow) - extends LegacyLoginTests |
| `ECALoginTests` | Tests for External Client App (ECA) login flows |
| `BeaconLoginTests` | Tests for Beacon app login flows (using regular_auth login host) |
| `AdvancedAuthBeaconLoginTests` | Tests for Beacon app login flows (using advanced_auth login host) |
| `WelcomeLoginTests` | Tests for welcome (domain discovery) login flows using simulated domain discovery |
| `LoginWithRestartTests` | Tests for verifying that user sessions persist across app restarts |
| `RefreshTokenMigrationTests` | Tests for refresh token migration between app configurations without re-authentication |
| `RefreshTokenMigrationWithRestartTests` | Tests for verifying that migrated refresh tokens persist across app restarts |
| `MultiUserLoginTests` | Tests for multi-user login scenarios with various configurations, including token revocation |

---

## Login Tests

### LegacyLoginTests (6 tests)

Tests for Connected App (CA) configurations with default, subset, and all scopes using hybrid authentication flow. Tests both web server and user agent OAuth flows.

| Test Name | App Config | Scopes | Flow | Hybrid |
|-----------|------------|--------|------|--------|
| `testCAOpaque_DefaultScopes_WebServerFlow` | CA Opaque | Default | Web Server | Yes |
| `testCAOpaque_SubsetScopes_WebServerFlow` | CA Opaque | Subset | Web Server | Yes |
| `testCAOpaque_AllScopes_WebServerFlow` | CA Opaque | All | Web Server | Yes |
| `testCAOpaque_DefaultScopes_UserAgentFlow` | CA Opaque | Default | User Agent | Yes |
| `testCAOpaque_SubsetScopes_UserAgentFlow` | CA Opaque | Subset | User Agent | Yes |
| `testCAOpaque_AllScopes_UserAgentFlow` | CA Opaque | All | User Agent | Yes |

### LegacyLoginTestsNotHybrid (6 tests)

Tests for Connected App (CA) configurations with non-hybrid authentication flow. Extends `LegacyLoginTests` and runs the same tests with `useHybridFlow` set to false. Non-hybrid flow means the app does not receive front-door session cookies (SIDs) during authentication.

| Test Name | App Config | Scopes | Flow | Hybrid |
|-----------|------------|--------|------|--------|
| `testCAOpaque_DefaultScopes_WebServerFlow` | CA Opaque | Default | Web Server | No |
| `testCAOpaque_SubsetScopes_WebServerFlow` | CA Opaque | Subset | Web Server | No |
| `testCAOpaque_AllScopes_WebServerFlow` | CA Opaque | All | Web Server | No |
| `testCAOpaque_DefaultScopes_UserAgentFlow` | CA Opaque | Default | User Agent | No |
| `testCAOpaque_SubsetScopes_UserAgentFlow` | CA Opaque | Subset | User Agent | No |
| `testCAOpaque_AllScopes_UserAgentFlow` | CA Opaque | All | User Agent | No |

### ECALoginTests (6 tests)

Tests for External Client App (ECA) configurations using web server flow with hybrid auth.

| Test Name | App Config | Scopes |
|-----------|------------|--------|
| `testECAOpaque_DefaultScopes` | ECA Opaque | Default |
| `testECAOpaque_SubsetScopes` | ECA Opaque | Subset |
| `testECAOpaque_AllScopes` | ECA Opaque | All |
| `testECAJwt_DefaultScopes` | ECA JWT | Default |
| `testECAJwt_SubsetScopes_NotHybrid` | ECA JWT | Subset |
| `testECAJwt_AllScopes` | ECA JWT | All |

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
| `testWelcomeDiscoveryWithRegularAuthLoginHost` | regular_auth (simulated) | No |
| `testWelcomeDiscoveryWithAdvancedAuthLoginHost` | advanced_auth (simulated) | No |
| `testWelcomeDiscoveryWithRegularAuthLoginHostAndDynamicConfig` | regular_auth (simulated) | Yes |
| `testWelcomeDiscoveryWithAdvancedAuthLoginHostAndDynamicConfig` | advanced_auth (simulated) | Yes |

### LoginWithRestartTests (8 tests)

Tests for verifying that user sessions persist across app restarts. Includes CA, ECA, and Beacon configurations with both static and dynamic settings.

| Test Name | App Config | Scopes | Config Type | Multi-User |
|-----------|------------|--------|-------------|------------|
| `testCAOpaque_DefaultScopes_WithRestart` | CA Opaque | Default | Static | No |
| `testECAOpaque_DefaultScopes_WithRestart` | ECA Opaque | Default | Static | No |
| `testBeaconOpaque_DefaultScopes_WithRestart` | Beacon Opaque | Default | Static | No |
| `testECAJwt_DefaultScopes_DynamicConfiguration_WithRestart` | ECA JWT | Default | Dynamic | No |
| `testECAJwt_SubsetScopes_DynamicConfiguration_WithRestart` | ECA JWT | Subset | Dynamic | No |
| `testBeaconJwt_DefaultScopes_DynamicConfiguration_WithRestart` | Beacon JWT | Default | Dynamic | No |
| `testBeaconJwt_SubsetScopes_DynamicConfiguration_WithRestart` | Beacon JWT | Subset | Dynamic | No |
| `testMultiUserRestart` | ECA Opaque + ECA JWT | Default | Dynamic + Static | Yes |

---

## Migration Tests

### RefreshTokenMigrationTests (9 tests)

Tests for migrating refresh tokens between different app configurations without re-authentication.

| Test Name | Original App | Migration App | Scope Change | Multi-User |
|-----------|--------------|---------------|--------------|------------|
| `testMigrateCA_AddMoreScopes` | CA JWT (subset) | CA JWT (all) | Yes | No |
| `testMigrateECA_AddMoreScopes` | ECA JWT (subset) | ECA JWT (all) | Yes | No |
| `testMigrateBeacon_AddMoreScopes` | Beacon JWT (subset) | Beacon JWT (all) | Yes | No |
| `testMigrateCAToBeacon` | CA Opaque | Beacon Opaque | No | No |
| `testMigrateBeaconToCA` | Beacon Opaque | CA Opaque | No | No |
| `testMigrateCAToECA` | CA Opaque → ECA Opaque → CA Opaque | No | No |
| `testMigrateCAToBeaconAndBack` | CA Opaque → Beacon Opaque → CA Opaque | No | No |
| `testMigrateBeaconOpaqueToJWTAndBack` | Beacon Opaque → Beacon JWT → Beacon Opaque | No | No |
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

### MultiUserLoginTests (9 tests)

Tests for login scenarios with two users using various configurations, including token revocation scenarios.

| Test Name | User 1 Config | User 2 Config | Same App | Same Scopes | Beacon | Token Revocation |
|-----------|---------------|---------------|----------|-------------|--------|------------------|
| `testBothStatic_SameApp_SameScopes` | Static (Opaque) | Static (Opaque) | Yes | Yes | No | No |
| `testBothStatic_DifferentApps` | Static (Opaque) | Static (JWT) | No | Yes | No | No |
| `testBothStatic_SameApp_DifferentScopes` | Static (Opaque, subset) | Static (Opaque, default) | Yes | No | No | No |
| `testFirstStatic_SecondDynamic_DifferentApps` | Static (Opaque) | Dynamic (JWT) | No | Yes | No | No |
| `testFirstDynamic_SecondStatic_DifferentApps` | Dynamic (JWT) | Static (Opaque) | No | Yes | No | No |
| `testBothDynamic_DifferentApps` | Dynamic (Opaque) | Dynamic (JWT) | No | Yes | No | No |
| `testBeaconAndNonBeacon_MultiUser` | Beacon (Opaque) | CA (Opaque) | No | Yes | Yes | No |
| `testRevokeUserWithDynamicConfig_OtherUserUnaffected` | ECA (Opaque) static | ECA (JWT) dynamic | No | Yes | No | Yes (User B) |
| `testDifferentAppTypes_RevokeCaUser_EcaUserUnaffected` | CA (Opaque) | ECA (Opaque) | No | Yes | No | Yes (User A) |

---

## Scope Definitions

| Scope Type | Description |
|------------|-------------|
| **Default** | No scopes requested (all scopes defined in server config should be granted) |
| **Subset** | Explicitly requests all scopes except for sfap_api |
| **All** | Explicitly requests all scopes |

## App Configuration Types

| App Type | Token Format | Description |
|----------|--------------|-------------|
| **CA** | Opaque/JWT | Connected App |
| **ECA** | Opaque/JWT | External Client App |
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
| `beaconOpaque` | Beacon | Opaque | `api content id lightning refresh_token sfap_api web` |
| `beaconJwt` | Beacon | JWT | `api content id lightning refresh_token sfap_api web` |
| `caOpaque` | CA | Opaque | `api content id lightning refresh_token sfap_api visualforce web` |
| `caJwt` | CA | JWT | `api content id lightning refresh_token sfap_api visualforce web` |

### Token Formats

| Format | Description |
|--------|-------------|
| **Opaque** | Opaque access tokens |
| **JWT** | JSON Web Token based access tokens |

## Login Hosts

The test suite supports testing against different Salesforce org configurations with different authentication mechanisms. The login host configuration is specified in `ui_test_config.json` under the `loginHosts` array.

| Login Host | Description | Authentication Mechanism |
|------------|-------------|-------------------------|
| **regular_auth** | Org configured to use regular authentication | Authentication through web view |
| **advanced_auth** | Org configured to use native browser for authentication | Chrome Custom Tab on Android and ASWebAuthenticationSession on iOS |

Most tests use the `regular_auth` login host by default. The `AdvancedAuthBeaconLoginTests` class runs the same Beacon login tests but uses the `advanced_auth` login host to verify authentication flows work correctly with native browser authentication. The `WelcomeLoginTests` use simulated domain discovery with welcome.salesforce.com as the login server to test the welcome/domain discovery flow.
