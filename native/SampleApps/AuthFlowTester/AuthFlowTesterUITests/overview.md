# AuthFlowTester UI Tests Overview

This document provides an overview of all UI tests in the AuthFlowTester test suite.

## Test Classes

| Class | Description |
|-------|-------------|
| `LegacyLoginTests` | Tests for legacy login flows (connected apps, user agent flow, non-hybrid flow) |
| `ECALoginTests` | Tests for External Client App (ECA) login flows |
| `BeaconLoginTests` | Tests for Beacon app login flows |
| `MigrationTests` | Tests for refresh token migration between app configurations |
| `MultiUserLoginTests` | Tests for multi-user login scenarios |

---

## Login Tests

### LegacyLoginTests (12 tests)

Tests for Connected App (CA) configurations including user agent flow and non-hybrid flow options.

| Test Name | App Config | Scopes | Flow | Hybrid |
|-----------|------------|--------|------|--------|
| `testCAAdvancedOpaque_DefaultScopes_WebServerFlow` | CA Advanced Opaque | Default | Web Server | Yes |
| `testCAAdvancedOpaque_SubsetScopes_WebServerFlow` | CA Advanced Opaque | Subset | Web Server | No |
| `testCAAdvancedOpaque_AllScopes_WebServerFlow` | CA Advanced Opaque | All | Web Server | Yes |
| `testCAAdvancedOpaque_DefaultScopes_WebServerFlow_NotHybrid` | CA Advanced Opaque | Default | Web Server | No |
| `testCAAdvancedOpaque_SubsetScopes_WebServerFlow_NotHybrid` | CA Advanced Opaque | Subset | Web Server | No |
| `testCAAdvancedOpaque_AllScopes_WebServerFlow_NotHybrid` | CA Advanced Opaque | All | Web Server | No |
| `testCAAdvancedOpaque_DefaultScopes_UserAgentFlow` | CA Advanced Opaque | Default | User Agent | Yes |
| `testCAAdvancedOpaque_SubsetScopes_UserAgentFlow` | CA Advanced Opaque | Subset | User Agent | Yes |
| `testCAAdvancedOpaque_AllScopes_UserAgentFlow` | CA Advanced Opaque | All | User Agent | Yes |
| `testCAAdvancedOpaque_DefaultScopes_UserAgentFlow_NotHybrid` | CA Advanced Opaque | Default | User Agent | No |
| `testCAAdvancedOpaque_SubsetScopes_UserAgentFlow_NotHybrid` | CA Advanced Opaque | Subset | User Agent | No |
| `testCAAdvancedOpaque_AllScopes_UserAgentFlow_NotHybrid` | CA Advanced Opaque | All | User Agent | No |

### ECALoginTests (6 tests)

Tests for External Client App (ECA) configurations using web server flow with hybrid auth.

| Test Name | App Config | Scopes |
|-----------|------------|--------|
| `testECAAdvancedOpaque_DefaultScopes` | ECA Advanced Opaque | Default |
| `testECAAdvancedOpaque_SubsetScopes` | ECA Advanced Opaque | Subset |
| `testECAAdvancedOpaque_AllScopes` | ECA Advanced Opaque | All |
| `testECAAdvancedJwt_DefaultScopes` | ECA Advanced JWT | Default |
| `testECAAdvancedJwt_SubsetScopes_NotHybrid` | ECA Advanced JWT | Subset |
| `testECAAdvancedJwt_AllScopes` | ECA Advanced JWT | All |

### BeaconLoginTests (6 tests)

Tests for Beacon app configurations using web server flow with hybrid auth.

| Test Name | App Config | Scopes |
|-----------|------------|--------|
| `testBeaconAdvancedOpaque_DefaultScopes` | Beacon Advanced Opaque | Default |
| `testBeaconAdvancedOpaque_SubsetScopes` | Beacon Advanced Opaque | Subset |
| `testBeaconAdvancedOpaque_AllScopes` | Beacon Advanced Opaque | All |
| `testBeaconAdvancedJwt_DefaultScopes` | Beacon Advanced JWT | Default |
| `testBeaconAdvancedJwt_SubsetScopes` | Beacon Advanced JWT | Subset |
| `testBeaconAdvancedJwt_AllScopes` | Beacon Advanced JWT | All |

---

## Migration Tests

### MigrationTests (7 tests)

Tests for migrating refresh tokens between different app configurations without re-authentication.

| Test Name | Original App | Migration App | Scope Change |
|-----------|--------------|---------------|--------------|
| `testMigrateECA_AddMoreScopes` | ECA Advanced JWT (subset) | ECA Advanced JWT (all) | Yes (add more scopes) |
| `testMigrateBeacon_AddMoreScopes` | Beacon Advanced JWT (subset) | Beacon Advanced JWT (all) | Yes (add more scopes) |
| `testMigrateCAToECA` | CA Advanced Opaque | ECA Advanced Opaque | No |
| `testMigrateCAToBeacon` | CA Advanced Opaque | Beacon Advanced Opaque | No |
| `testMigrateBeaconOpaqueToJWT` | Beacon Advanced Opaque | Beacon Advanced JWT | No |
| `testMigrateCAToBeaconAndBack` | CA Advanced Opaque → Beacon Advanced Opaque → CA Advanced Opaque | Multi-step migration | No |
| `testMigrateBeaconOpaqueToJWTAndBack` | Beacon Advanced Opaque → Beacon Advanced JWT | Token format migration (note: test name suggests rollback but only migrates forward) | No |

---

## Multi-User Tests

### MultiUserLoginTests (6 tests)

Tests for login scenarios with two users using various configurations.

| Test Name | User 1 Config | User 2 Config | Same App | Same Scopes | Restart |
|-----------|---------------|---------------|----------|-------------|---------|
| `testBothStatic_SameApp_SameScopes` | Static (Opaque) | Static (Opaque) | Yes | Yes | No |
| `testBothStatic_DifferentApps` | Static (Opaque) | Static (JWT) | No | Yes | No |
| `testBothStatic_SameApp_DifferentScopes` | Static (Opaque, subset) | Static (Opaque, default) | Yes | No | No |
| `testFirstStatic_SecondDynamic_DifferentApps` | Static (Opaque) | Dynamic (JWT) | No | Yes | No |
| `testFirstDynamic_SecondStatic_DifferentApps` | Dynamic (JWT) | Static (Opaque) | No | Yes | No |
| `testBothDynamic_DifferentApps` | Dynamic (Opaque) | Dynamic (JWT) | No | Yes | No |

---

## Scope Definitions

| Scope Type | Description |
|------------|-------------|
| **Default** | Uses all scopes defined in the server config |
| **Subset** | Uses `api id refresh_token` only |
| **All** | Explicitly requests all scopes |

## App Configuration Types

| App Type | Token Format | Description |
|----------|--------------|-------------|
| **CA** | Opaque/JWT | Connected App |
| **ECA** | Opaque/JWT | External Client App |
| **Beacon** | Opaque/JWT | Beacon App |

## Available App Configurations

| Config Name | App Type | Token | Tier | Scopes |
|-------------|----------|-------|------|--------|
| `ecaBasicOpaque` | ECA | Opaque | Basic | `api id refresh_token` |
| `ecaBasicJwt` | ECA | JWT | Basic | `api id refresh_token` |
| `ecaAdvancedOpaque` | ECA | Opaque | Advanced | `api id refresh_token content lightning visualforce sfap_api` |
| `ecaAdvancedJwt` | ECA | JWT | Advanced | `api id refresh_token content lightning visualforce sfap_api` |
| `beaconBasicOpaque` | Beacon | Opaque | Basic | `api id refresh_token` |
| `beaconBasicJwt` | Beacon | JWT | Basic | `api id refresh_token` |
| `beaconAdvancedOpaque` | Beacon | Opaque | Advanced | `api id refresh_token content lightning visualforce sfap_api` |
| `beaconAdvancedJwt` | Beacon | JWT | Advanced | `api id refresh_token content lightning visualforce sfap_api` |
| `caBasicOpaque` | CA | Opaque | Basic | `api id refresh_token` |
| `caBasicJwt` | CA | JWT | Basic | `api id refresh_token` |
| `caAdvancedOpaque` | CA | Opaque | Advanced | `api id refresh_token content lightning visualforce sfap_api` |
| `caAdvancedJwt` | CA | JWT | Advanced | `api id refresh_token content lightning visualforce sfap_api` |

### Configuration Tiers

| Tier | Description | Scopes Included |
|------|-------------|-----------------|
| **Basic** | Minimal scopes for basic API access | `api id refresh_token` |
| **Advanced** | Full scopes including hybrid auth capabilities | `api id refresh_token content lightning visualforce sfap_api` |

### Token Formats

| Format | Description |
|--------|-------------|
| **Opaque** | Opaque access tokens |
| **JWT** | JSON Web Token based access tokens |

