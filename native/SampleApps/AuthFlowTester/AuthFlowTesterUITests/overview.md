# AuthFlowTester UI Tests Overview

This document provides an overview of all UI tests in the AuthFlowTester test suite.

## Test Classes

| Class | Description |
|-------|-------------|
| `LegacyLoginTests` | Tests for legacy login flows with subset and all scopes (CA, user agent flow, non-hybrid flow) |
| `DefaultScopesLegacyLoginTests` | Legacy login tests using default scopes (CA opaque) |
| `ECALoginTests` | Tests for External Client App (ECA) login flows |
| `BeaconLoginTests` | Tests for Beacon app login flows (using regular_auth login host) |
| `AdvancedAuthBeaconLoginTests` | Tests for Beacon app login flows (using advanced_auth login host) |
| `DynamicConfigLoginTests` | Tests for login with dynamic (runtime-selected) app configuration; CA, ECA, and Beacon with restart validation |
| `WelcomeLoginTests` | Tests for welcome (domain discovery) login flows using simulated domain discovery |
| `MigrationTests` | Tests for refresh token migration between app configurations |
| `MultiUserLoginTests` | Tests for multi-user login scenarios |

---

## Login Tests

### LegacyLoginTests (8 tests)

Tests for Connected App (CA) configurations with subset and all scopes, including user agent flow and non-hybrid flow options.

| Test Name | App Config | Scopes | Flow | Hybrid | Dynamic Config |
|-----------|------------|--------|------|--------|----------------|
| `testCAOpaque_SubsetScopes_WebServerFlow` | CA Opaque | Subset | Web Server | No | No |
| `testCAOpaque_AllScopes_WebServerFlow` | CA Opaque | All | Web Server | Yes | No |
| `testCAOpaque_SubsetScopes_WebServerFlow_NotHybrid` | CA Opaque | Subset | Web Server | No | No |
| `testCAOpaque_AllScopes_WebServerFlow_NotHybrid` | CA Opaque | All | Web Server | No | No |
| `testCAOpaque_SubsetScopes_UserAgentFlow` | CA Opaque | Subset | User Agent | Yes | No |
| `testCAOpaque_AllScopes_UserAgentFlow` | CA Opaque | All | User Agent | Yes | No |
| `testCAOpaque_SubsetScopes_UserAgentFlow_NotHybrid` | CA Opaque | Subset | User Agent | No | No |
| `testCAOpaque_AllScopes_UserAgentFlow_NotHybrid` | CA Opaque | All | User Agent | No | No |

### DefaultScopesLegacyLoginTests (4 tests)

Legacy login tests using default scopes (CA opaque).

| Test Name | App Config | Scopes | Flow | Hybrid |
|-----------|------------|--------|------|--------|
| `testCAOpaque_DefaultScopes_WebServerFlow` | CA Opaque | Default | Web Server | Yes |
| `testCAOpaque_DefaultScopes_WebServerFlow_NotHybrid` | CA Opaque | Default | Web Server | No |
| `testCAOpaque_DefaultScopes_UserAgentFlow` | CA Opaque | Default | User Agent | Yes |
| `testCAOpaque_DefaultScopes_UserAgentFlow_NotHybrid` | CA Opaque | Default | User Agent | No |

### ECALoginTests (6 tests)

Tests for External Client App (ECA) configurations using web server flow with hybrid auth.

| Test Name | App Config | Scopes | Dynamic Config |
|-----------|------------|--------|----------------|
| `testECAOpaque_DefaultScopes` | ECA Opaque | Default | No |
| `testECAOpaque_SubsetScopes` | ECA Opaque | Subset | No |
| `testECAOpaque_AllScopes` | ECA Opaque | All | No |
| `testECAJwt_DefaultScopes` | ECA JWT | Default | No |
| `testECAJwt_SubsetScopes_NotHybrid` | ECA JWT | Subset | No |
| `testECAJwt_AllScopes` | ECA JWT | All | No |

### BeaconLoginTests (6 tests)

Tests for Beacon app configurations using web server flow with hybrid auth. Uses `regular_auth` login host.

| Test Name | App Config | Scopes | Dynamic Config |
|-----------|------------|--------|----------------|
| `testBeaconOpaque_DefaultScopes` | Beacon Opaque | Default | No |
| `testBeaconOpaque_SubsetScopes` | Beacon Opaque | Subset | No |
| `testBeaconOpaque_AllScopes` | Beacon Opaque | All | No |
| `testBeaconJwt_DefaultScopes` | Beacon JWT | Default | No |
| `testBeaconJwt_SubsetScopes` | Beacon JWT | Subset | No |
| `testBeaconJwt_AllScopes` | Beacon JWT | All | No |

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

### DynamicConfigLoginTests (6 tests)

Tests for login using dynamic (runtime-selected) app configuration. Each test logs in with a dynamic config then restarts the app and validates the session.

| Test Name | Static Config | Dynamic Config | Scopes |
|-----------|---------------|----------------|--------|
| `testCAJwt_DefaultScopes_DynamicConfiguration_WithRestart` | CA Opaque | CA JWT | Default |
| `testCAJwt_SubsetScopes_DynamicConfiguration_WithRestart` | CA Opaque | CA JWT | Subset |
| `testECAJwt_DefaultScopes_DynamicConfiguration_WithRestart` | ECA Opaque | ECA JWT | Default |
| `testECAJwt_SubsetScopes_DynamicConfiguration_WithRestart` | ECA Opaque | ECA JWT | Subset |
| `testBeaconJwt_DefaultScopes_DynamicConfiguration_WithRestart` | Beacon Opaque | Beacon JWT | Default |
| `testBeaconJwt_SubsetScopes_DynamicConfiguration_WithRestart` | Beacon Opaque | Beacon JWT | Subset |

### WelcomeLoginTests (4 tests)

Tests for welcome (domain discovery) login flows. Uses simulated domain discovery with welcome.salesforce.com as the login server.

| Test Name | Login Host | Dynamic Config |
|-----------|------------|----------------|
| `testWelcomeDiscoveryWithRegularAuthLoginHost` | regular_auth (simulated) | No |
| `testWelcomeDiscoveryWithAdvancedAuthLoginHost` | advanced_auth (simulated) | No |
| `testWelcomeDiscoveryWithRegularAuthLoginHostAndDynamicConfig` | regular_auth (simulated) | Yes |
| `testWelcomeDiscoveryWithAdvancedAuthLoginHostAndDynamicConfig` | advanced_auth (simulated) | Yes |

---

## Migration Tests

### MigrationTests (8 tests)

Tests for migrating refresh tokens between different app configurations without re-authentication.

| Test Name | Original App | Migration App | Scope Change |
|-----------|--------------|---------------|--------------|
| `testMigrateCA_AddMoreScopes` | CA JWT (subset) | CA JWT (all) | Yes (add more scopes) |
| `testMigrateECA_AddMoreScopes` | ECA JWT (subset) | ECA JWT (all) | Yes (add more scopes) |
| `testMigrateBeacon_AddMoreScopes` | Beacon JWT (subset) | Beacon JWT (all) | Yes (add more scopes) |
| `testMigrateCAToBeacon` | CA Opaque | Beacon Opaque | No |
| `testMigrateBeaconToCA` | Beacon Opaque | CA Opaque | No |
| `testMigrateCAToECA` | CA Opaque → ECA Opaque → CA Opaque | Migration with rollback | No |
| `testMigrateCAToBeaconAndBack` | CA Opaque → Beacon Opaque | Migration to Beacon | No |
| `testMigrateBeaconOpaqueToJWTAndBack` | Beacon Opaque → Beacon JWT → Beacon Opaque | Migration with rollback | No |

---

## Multi-User Tests

### MultiUserLoginTests (6 tests)

Tests for login scenarios with two users using various configurations.

| Test Name | User 1 Config | User 2 Config | Same App | Same Scopes |
|-----------|---------------|---------------|----------|-------------|
| `testBothStatic_SameApp_SameScopes` | Static (Opaque) | Static (Opaque) | Yes | Yes |
| `testBothStatic_DifferentApps` | Static (Opaque) | Static (JWT) | No | Yes |
| `testBothStatic_SameApp_DifferentScopes` | Static (Opaque, subset) | Static (Opaque, default) | Yes | No |
| `testFirstStatic_SecondDynamic_DifferentApps` | Static (Opaque) | Dynamic (JWT) | No | Yes |
| `testFirstDynamic_SecondStatic_DifferentApps` | Dynamic (JWT) | Static (Opaque) | No | Yes |
| `testBothDynamic_DifferentApps` | Dynamic (Opaque) | Dynamic (JWT) | No | Yes |

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
