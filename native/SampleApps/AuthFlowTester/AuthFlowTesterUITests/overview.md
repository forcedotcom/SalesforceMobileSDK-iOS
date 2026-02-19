# AuthFlowTester UI Tests Overview

This document provides an overview of all UI tests in the AuthFlowTester test suite.

## Test Classes

| Class | Description |
|-------|-------------|
| `LegacyLoginTests` | Tests for legacy login flows with subset and all scopes (CA, user agent flow, non-hybrid flow) |
| `DefaultScopesLegacyLoginTests` | Legacy login tests using default scopes (CA advanced opaque) |
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
| `testCAAdvancedOpaque_SubsetScopes_WebServerFlow` | CA Advanced Opaque | Subset | Web Server | No | No |
| `testCAAdvancedOpaque_AllScopes_WebServerFlow` | CA Advanced Opaque | All | Web Server | Yes | No |
| `testCAAdvancedOpaque_SubsetScopes_WebServerFlow_NotHybrid` | CA Advanced Opaque | Subset | Web Server | No | No |
| `testCAAdvancedOpaque_AllScopes_WebServerFlow_NotHybrid` | CA Advanced Opaque | All | Web Server | No | No |
| `testCAAdvancedOpaque_SubsetScopes_UserAgentFlow` | CA Advanced Opaque | Subset | User Agent | Yes | No |
| `testCAAdvancedOpaque_AllScopes_UserAgentFlow` | CA Advanced Opaque | All | User Agent | Yes | No |
| `testCAAdvancedOpaque_SubsetScopes_UserAgentFlow_NotHybrid` | CA Advanced Opaque | Subset | User Agent | No | No |
| `testCAAdvancedOpaque_AllScopes_UserAgentFlow_NotHybrid` | CA Advanced Opaque | All | User Agent | No | No |

### DefaultScopesLegacyLoginTests (4 tests)

Legacy login tests using default scopes (CA advanced opaque).

| Test Name | App Config | Scopes | Flow | Hybrid |
|-----------|------------|--------|------|--------|
| `testCAAdvancedOpaque_DefaultScopes_WebServerFlow` | CA Advanced Opaque | Default | Web Server | Yes |
| `testCAAdvancedOpaque_DefaultScopes_WebServerFlow_NotHybrid` | CA Advanced Opaque | Default | Web Server | No |
| `testCAAdvancedOpaque_DefaultScopes_UserAgentFlow` | CA Advanced Opaque | Default | User Agent | Yes |
| `testCAAdvancedOpaque_DefaultScopes_UserAgentFlow_NotHybrid` | CA Advanced Opaque | Default | User Agent | No |

### ECALoginTests (6 tests)

Tests for External Client App (ECA) configurations using web server flow with hybrid auth.

| Test Name | App Config | Scopes | Dynamic Config |
|-----------|------------|--------|----------------|
| `testECAAdvancedOpaque_DefaultScopes` | ECA Advanced Opaque | Default | No |
| `testECAAdvancedOpaque_SubsetScopes` | ECA Advanced Opaque | Subset | No |
| `testECAAdvancedOpaque_AllScopes` | ECA Advanced Opaque | All | No |
| `testECAAdvancedJwt_DefaultScopes` | ECA Advanced JWT | Default | No |
| `testECAAdvancedJwt_SubsetScopes_NotHybrid` | ECA Advanced JWT | Subset | No |
| `testECAAdvancedJwt_AllScopes` | ECA Advanced JWT | All | No |

### BeaconLoginTests (6 tests)

Tests for Beacon app configurations using web server flow with hybrid auth. Uses `regular_auth` login host.

| Test Name | App Config | Scopes | Dynamic Config |
|-----------|------------|--------|----------------|
| `testBeaconAdvancedOpaque_DefaultScopes` | Beacon Advanced Opaque | Default | No |
| `testBeaconAdvancedOpaque_SubsetScopes` | Beacon Advanced Opaque | Subset | No |
| `testBeaconAdvancedOpaque_AllScopes` | Beacon Advanced Opaque | All | No |
| `testBeaconAdvancedJwt_DefaultScopes` | Beacon Advanced JWT | Default | No |
| `testBeaconAdvancedJwt_SubsetScopes` | Beacon Advanced JWT | Subset | No |
| `testBeaconAdvancedJwt_AllScopes` | Beacon Advanced JWT | All | No |

### AdvancedAuthBeaconLoginTests (6 tests)

Tests for Beacon app configurations using web server flow with hybrid auth. Uses `advanced_auth` login host. Inherits all tests from `BeaconLoginTests` but runs them with advanced authentication.

| Test Name | App Config | Scopes | Login Host |
|-----------|------------|--------|------------|
| `testBeaconAdvancedOpaque_DefaultScopes` | Beacon Advanced Opaque | Default | advanced_auth |
| `testBeaconAdvancedOpaque_SubsetScopes` | Beacon Advanced Opaque | Subset | advanced_auth |
| `testBeaconAdvancedOpaque_AllScopes` | Beacon Advanced Opaque | All | advanced_auth |
| `testBeaconAdvancedJwt_DefaultScopes` | Beacon Advanced JWT | Default | advanced_auth |
| `testBeaconAdvancedJwt_SubsetScopes` | Beacon Advanced JWT | Subset | advanced_auth |
| `testBeaconAdvancedJwt_AllScopes` | Beacon Advanced JWT | All | advanced_auth |

### DynamicConfigLoginTests (6 tests)

Tests for login using dynamic (runtime-selected) app configuration. Each test logs in with a dynamic config then restarts the app and validates the session.

| Test Name | Static Config | Dynamic Config | Scopes |
|-----------|---------------|----------------|--------|
| `testCAAdvancedJwt_DefaultScopes_DynamicConfiguration_WithRestart` | CA Advanced Opaque | CA Advanced JWT | Default |
| `testCAAdvancedJwt_SubsetScopes_DynamicConfiguration_WithRestart` | CA Advanced Opaque | CA Advanced JWT | Subset |
| `testECAAdvancedJwt_DefaultScopes_DynamicConfiguration_WithRestart` | ECA Advanced Opaque | ECA Advanced JWT | Default |
| `testECAAdvancedJwt_SubsetScopes_DynamicConfiguration_WithRestart` | ECA Advanced Opaque | ECA Advanced JWT | Subset |
| `testBeaconAdvancedJwt_DefaultScopes_DynamicConfiguration_WithRestart` | Beacon Advanced Opaque | Beacon Advanced JWT | Default |
| `testBeaconAdvancedJwt_SubsetScopes_DynamicConfiguration_WithRestart` | Beacon Advanced Opaque | Beacon Advanced JWT | Subset |

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
| `testMigrateCA_AddMoreScopes` | CA Advanced JWT (subset) | CA Advanced JWT (all) | Yes (add more scopes) |
| `testMigrateECA_AddMoreScopes` | ECA Advanced JWT (subset) | ECA Advanced JWT (all) | Yes (add more scopes) |
| `testMigrateBeacon_AddMoreScopes` | Beacon Advanced JWT (subset) | Beacon Advanced JWT (all) | Yes (add more scopes) |
| `testMigrateCAToBeacon` | CA Advanced Opaque | Beacon Advanced Opaque | No |
| `testMigrateBeaconToCA` | Beacon Advanced Opaque | CA Advanced Opaque | No |
| `testMigrateCAToECA` | CA Advanced Opaque → ECA Advanced Opaque → CA Advanced Opaque | Migration with rollback | No |
| `testMigrateCAToBeaconAndBack` | CA Advanced Opaque → Beacon Advanced Opaque | Migration to Beacon | No |
| `testMigrateBeaconOpaqueToJWTAndBack` | Beacon Advanced Opaque → Beacon Advanced JWT → Beacon Advanced Opaque | Migration with rollback | No |

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

| Config Name | App Type | Token | Tier | Scopes |
|-------------|----------|-------|------|--------|
| `ecaBasicOpaque` | ECA | Opaque | Basic | `api id refresh_token` |
| `ecaBasicJwt` | ECA | JWT | Basic | `api id refresh_token` |
| `ecaAdvancedOpaque` | ECA | Opaque | Advanced | `api content id lightning refresh_token sfap_api visualforce web` |
| `ecaAdvancedJwt` | ECA | JWT | Advanced | `api content id lightning refresh_token sfap_api visualforce web` |
| `beaconBasicOpaque` | Beacon | Opaque | Basic | `api profile refresh_token` |
| `beaconBasicJwt` | Beacon | JWT | Basic | `api id refresh_token` |
| `beaconAdvancedOpaque` | Beacon | Opaque | Advanced | `api content id lightning refresh_token sfap_api web` |
| `beaconAdvancedJwt` | Beacon | JWT | Advanced | `api content id lightning refresh_token sfap_api web` |
| `caBasicOpaque` | CA | Opaque | Basic | `api id refresh_token` |
| `caBasicJwt` | CA | JWT | Basic | `api id refresh_token` |
| `caAdvancedOpaque` | CA | Opaque | Advanced | `api content id lightning refresh_token sfap_api visualforce web` |
| `caAdvancedJwt` | CA | JWT | Advanced | `api content id lightning refresh_token sfap_api visualforce web` |

### Configuration Tiers

| Tier | Description | Scopes Included |
|------|-------------|-----------------|
| **Basic** | Minimal scopes for basic API access | CA/ECA: `api id refresh_token`<br>Beacon Opaque: `api profile refresh_token`<br>Beacon JWT: `api id refresh_token` |
| **Advanced** | Full scopes including hybrid auth capabilities | CA/ECA: `api content id lightning refresh_token sfap_api visualforce web`<br>Beacon: `api content id lightning refresh_token sfap_api web` |

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
