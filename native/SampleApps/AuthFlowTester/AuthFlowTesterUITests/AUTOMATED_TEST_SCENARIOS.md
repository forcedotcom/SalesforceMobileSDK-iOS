# AuthFlowTester Automated Test Scenarios

## Overview

This document describes the automated UI test scenarios for AuthFlowTester, organized according to the Mobile SDK 13.2 high-level test plans. The automated tests validate three key features introduced in Mobile SDK 13.2:

1. **Dynamic Scope Retrieval** - Applications can omit scopes in bootconfig and receive all configured scopes from the server
2. **Runtime Consumer Key Selection** - Applications can override the consumer key at runtime via dynamic configuration
3. **Refresh Token Migration** - Applications can exchange refresh tokens between different consumer keys and scopes

## Related Resources

- [13.2 Test Org Setup for Authentication Testing](https://drive.google.com/file/d/1SiXgxD46_LBhUATvt8kGYmmcoQd7reIgU0NICGbK-Ks/view) - User accounts and server-side app configuration
- [13.2 Dynamic Scope Retrieval High Level Test Plan](https://drive.google.com/file/d/14Ioi4qwRj3Gnsc67Fm59HoiaD2vnUH0IKAJZ5p9GX60/view)
- [13.2 Runtime Consumer Key Selection High Level Test Plan](https://drive.google.com/file/d/1-sFppGcou7XPhCpXXzOHix3Tk188uyddnnYp3R6_Vrk/view)
- [13.2 Refresh Token Migration High Level Test Plan](https://drive.google.com/file/d/19-o-3oQbDS_Dsv3hSEd8H-Me0lmGlmw2zZaIpiOC-pU/view)

## General Test Execution Instructions

### Prerequisites

1. **Test Accounts and Server Setup**: User accounts and server-side apps (ECA, CA, Beacon) configured per the [13.2 Test Org Setup for Authentication Testing](https://drive.google.com/file/d/1SiXgxD46_LBhUATvt8kGYmmcoQd7reIgU0NICGbK-Ks/view) document
2. **Test Configuration**: User credentials and app configurations defined in `ui_test_config.json`

Note: The automated tests configure the consumer key and login server dynamically - no bootconfig changes are required.

### How to Execute Test Scenarios Manually

All test scenarios follow this general pattern:

1. **Launch AuthFlowTester**
2. **Configure Login Options** (via Login Settings menu on login screen)
   - Click the settings/gear icon on the login screen
   - Configure Static Configuration (equivalent to bootconfig - persists across app restarts)
   - OR Configure Dynamic Configuration (runtime override - does not persist)
   - Select auth flow type (Web Server Flow vs User Agent Flow, Hybrid vs Non-Hybrid)
   - Save/apply settings
3. **Perform Login**
   - Enter credentials
   - Complete authentication
4. **Validate Credentials**
   - Expand "User Credentials" section - verify username, client ID, redirect URI, granted scopes, token format
   - Expand "OAuth Configuration" section - verify static configuration persists
   - If JWT token: expand "JWT Access Token Details" - verify expiration, scopes, client ID
5. **Test Token Operations**
   - Click "Revoke Access Token" - verify token is revoked
   - Click "Make Rest API request" - verify access token is refreshed and API succeeds
6. **Multi-User Operations** (if applicable)
   - Click "Users" icon (bottom bar) - add or switch users
7. **Migration Operations** (if applicable)
   - Click "Key" icon (bottom bar) - configure new app configuration
   - Configure auth flow type (Web Server Flow vs User Agent Flow, Hybrid vs Non-Hybrid)
   - Verify refresh token changes in "User Credentials" section

**Note**: The automated tests access the login settings menu directly through the UI test framework. Manual testers can also access login configuration through the Dev Support Menu (^+⌘+Z or shake device) if needed.

### Negative Testing Support

The test suite includes support for negative testing scenarios through invalid configurations:

- **Invalid App Configuration** (`.invalid`): Uses hard-coded invalid values (consumer key: "invalid_consumer_key", redirect URI: "invalid://callback") to test error handling when authentication fails
- **Invalid Scopes** (`.invalid`): Requests "invalid_scope" to test error handling when server rejects invalid scope requests

These can be used in automated tests by specifying:
```swift
// Test with invalid app config
launchLoginAndValidate(staticAppConfigName: .invalid)

// Test with invalid scopes
launchLoginAndValidate(staticAppConfigName: .caOpaque, staticScopeSelection: .invalid)
```

---

## 1. Dynamic Scope Retrieval High Level Test Plan

### Overview
Tests for the feature that allows applications to omit scopes from bootconfig and dynamically receive all scopes configured on the server. Scopes granted are saved with the user account and can be queried by the application.

### Test Groups

#### Group 1: Basic Login / Scope Behavior

##### Test 1.1: Login with Default Scopes (No Explicit Scopes)
**Automated Test**: `ECALoginTests.testECAOpaque_DefaultScopes`, `ECALoginTests.testECAJwt_DefaultScopes`
**Maps To**: High-Level Test Case 1.1
**Description**: Login using ECA with no explicitly requested scopes

**Manual Execution Steps**:
1. Launch AuthFlowTester
2. Click the settings/gear icon on the login screen to access login options
3. Expand "Static Configuration"
4. Configure:
   - Consumer Key: ECA-AllScopes consumer key
   - Scopes: (leave empty to request all scopes)
   - Auth Flow: Web Server Flow (Hybrid)
5. Click "Use static config"
6. Enter credentials and login
8. Expand "User Credentials" section
9. **Verify**: Granted scopes = id, api, refresh_token (all scopes defined on ECA-AllScopes)
10. Click "Make Rest API request"
11. **Verify**: API call succeeds
12. Click "Revoke Access Token"
13. Click "Make Rest API request" again
14. **Verify**: Access token is refreshed automatically, API call succeeds

##### Test 1.2: Login Explicitly Requesting Scopes
**Automated Test**: `ECALoginTests.testECAOpaque_AllScopes`, `ECALoginTests.testECAJwt_AllScopes`
**Maps To**: High-Level Test Case 1.2
**Description**: Login requesting specific scopes (id, api, refresh_token)

**Manual Execution Steps**:
1. Launch AuthFlowTester
2. Click the settings/gear icon on the login screen to access login options
3. Expand "Static Configuration"
4. Configure:
   - Consumer Key: ECA-AllScopes consumer key
   - Scopes: `id api refresh_token`
5. Click "Use static config"
6. Enter credentials and login
8. Expand "User Credentials" section
9. **Verify**: Granted scopes = id, api, refresh_token (exactly as requested)
10. Click "Make Rest API request"
11. **Verify**: API call succeeds

##### Test 1.3: Login with Subset of Scopes
**Automated Test**: `ECALoginTests.testECAOpaque_SubsetScopes`, `ECALoginTests.testECAJwt_SubsetScopes`
**Maps To**: High-Level Test Case 1.4
**Description**: Login requesting only id and refresh_token (omitting api scope)

**Manual Execution Steps**:
1. Launch AuthFlowTester
2. Click the settings/gear icon on the login screen to access login options
3. Expand "Static Configuration"
4. Configure:
   - Consumer Key: ECA-AllScopes consumer key
   - Scopes: `id refresh_token`
5. Click "Use static config"
6. Enter credentials and login
8. Expand "User Credentials" section
9. **Verify**: Granted scopes = id, refresh_token (no api scope)
10. Click "Make Rest API request"
11. **Verify**: API call fails (missing api scope)

#### Group 2: API Call & Token Behavior

##### Test 2.1: Call API After Successful Login
**Automated Test**: All login tests include API validation
**Maps To**: High-Level Test Case 2.1
**Description**: Verify API calls work after login

**Manual Execution Steps**:
1. Complete any successful login test (e.g., Test 1.1)
2. Click "Make Rest API request"
3. **Verify**: API returns success response
4. **Verify**: Request/response details shown

##### Test 2.2: Revoke Access Token and Refresh
**Automated Test**: Built into all validation flows via `assertRevokeAndRefreshWorks`
**Maps To**: High-Level Test Case 2.2
**Description**: Verify automatic token refresh after revocation

**Manual Execution Steps**:
1. Complete any successful login test
2. Note current access token value in "User Credentials"
3. Click "Revoke Access Token"
4. **Verify**: Access token is cleared/invalidated
5. Click "Make Rest API request"
6. **Verify**: New access token appears in "User Credentials"
7. **Verify**: Access token value changed
8. **Verify**: API call succeeds

#### Group 3: Multi-User Scenarios

##### Test 3.1: Multiple Users with Different Apps
**Automated Test**: `MultiUserLoginTests.testBothStatic_DifferentApps`
**Maps To**: High-Level Test Case 3.1
**Description**: Login User A with one ECA, then User B with different ECA

**Manual Execution Steps**:
1. Launch AuthFlowTester
2. Login User A with ECA-AllScopes (default scopes)
3. Verify User A credentials show correct scopes
4. Click "Users" icon (bottom bar)
5. Click "Add User"
6. Login User B with ECA-NewScopeAdded (default scopes)
7. **Verify**: User B credentials show ECA-NewScopeAdded scopes (including sfap_api)
8. Switch back to User A
9. **Verify**: User A credentials unchanged (no sfap_api scope)
10. Switch back to User B
11. **Verify**: User B credentials unchanged (still has sfap_api scope)

##### Test 3.2: Multiple Users with Same App, Different Scopes
**Automated Test**: `MultiUserLoginTests.testBothStatic_SameApp_DifferentScopes`
**Maps To**: Related to High-Level Test Case 3.1
**Description**: Two users with same ECA but different scope selections

**Manual Execution Steps**:
1. Launch AuthFlowTester
2. Login User A with ECA-AllScopes, subset scopes (id, refresh_token)
3. Verify User A has only id, refresh_token scopes
4. Click "Users" icon, add User B
5. Login User B with ECA-AllScopes, default scopes (all)
6. **Verify**: User B has id, api, refresh_token scopes
7. Switch between users
8. **Verify**: Each user retains their respective scopes

##### Test 3.3: Revoke One User's Token
**Automated Test**: `MultiUserLoginTests.testRevokeAccessForUserWithDynamicConfig_OtherUserUnaffected`
**Maps To**: High-Level Test Case 3.2
**Description**: Revoke user's access token (who uses dynamic config), verify other user unaffected

**Manual Execution Steps**:
1. Login User A and User B (following Test 3.1)
2. Switch to User B
3. Click "Revoke Access Token"
4. Switch to User A
5. Click "Make Rest API request"
6. **Verify**: User A's API call succeeds without needing refresh
7. Switch back to User B
8. Click "Make Rest API request"
9. **Verify**: User B's access token is refreshed, API succeeds

#### Group 4: Refresh Token Migration (Scope Changes)

##### Test 4.1: Migrate with More Scopes on Server
**Automated Test**: `RefreshTokenMigrationTests.testMigrateCA_AddMoreScopes`, `RefreshTokenMigrationTests.testMigrateECA_AddMoreScopes`
**Maps To**: High-Level Test Case 4.1
**Description**: Login with subset scopes, migrate requesting all scopes

**Manual Execution Steps**:
1. Launch AuthFlowTester
2. Login with ECA-AllScopes, subset scopes (id, refresh_token)
3. Note refresh token value in "User Credentials"
4. Click "Key" icon (bottom bar)
5. Configure migration auth flow type (optional):
   - Use Web Server Flow: On/Off
   - Use Hybrid Flow: On/Off
6. Configure migration:
   - Consumer Key: ECA-AllScopes (same)
   - Scopes: `id api refresh_token` (all scopes)
7. Click "Migrate"
8. **Verify**: Refresh token value changed
9. **Verify**: Granted scopes now include api scope
10. Click "Make Rest API request"
11. **Verify**: API call now succeeds

##### Test 4.2: Migrate with Fewer Scopes
**Automated Test**: Part of migration test validation
**Maps To**: High-Level Test Case 4.2, 4.4
**Description**: Login with all scopes, migrate requesting subset

**Manual Execution Steps**:
1. Launch AuthFlowTester
2. Login with ECA-AllScopes, all scopes (id, api, refresh_token)
3. Verify API call works
4. Click "Key" icon
5. Configure migration auth flow type (optional):
   - Use Web Server Flow: On/Off
   - Use Hybrid Flow: On/Off
6. Configure migration:
   - Consumer Key: ECA-AllScopes (same)
   - Scopes: `id refresh_token` (subset)
7. Click "Migrate"
8. **Verify**: Refresh token changed
9. **Verify**: Granted scopes = id, refresh_token (api removed)
10. Click "Make Rest API request"
11. **Verify**: API call fails (missing api scope)

##### Test 4.3: Migrate from Explicit to Implicit Scopes
**Automated Test**: Implicitly tested in migration tests
**Maps To**: High-Level Test Case 4.3
**Description**: Login with subset, migrate with no explicit scopes

**Manual Execution Steps**:
1. Launch AuthFlowTester
2. Login with ECA-AllScopes, subset scopes (id, refresh_token)
3. Verify only id, refresh_token scopes present
4. Click "Key" icon
5. Configure migration auth flow type (optional):
   - Use Web Server Flow: On/Off
   - Use Hybrid Flow: On/Off
6. Configure migration:
   - Consumer Key: ECA-AllScopes (same)
   - Scopes: (leave empty for all server-defined scopes)
7. Click "Migrate"
8. **Verify**: Refresh token changed
9. **Verify**: Granted scopes = id, api, refresh_token (all ECA scopes)
10. Click "Make Rest API request"
11. **Verify**: API call succeeds

#### Group 5: Negative Testing Scenarios

##### Test 5.1: Dynamic Configuration with Invalid Client ID
**Automated Test**: `ECALoginTests.testDynamicConfigurationWithInvalidClientId`
**Maps To**: Negative Testing
**Description**: Attempt login with invalid client ID in dynamic configuration to verify error handling

**Manual Execution Steps**:
1. Launch AuthFlowTester
2. Click the settings/gear icon on the login screen to access login options
3. Expand "Static Configuration" - configure ECA Opaque (valid config)
4. Expand "Dynamic Configuration" - configure with invalid client ID:
   - Consumer Key: `invalid_consumer_key`
   - Redirect URI: `invalid://callback`
   - Scopes: (leave empty)
5. Click "Use dynamic config"
6. Enter credentials and attempt login
7. **Verify**: Login fails with appropriate error
8. **Verify**: Error indicates invalid client credentials

##### Test 5.2: Dynamic Configuration with Invalid Scope
**Automated Test**: `ECALoginTests.testDynamicConfigurationWithInvalidScope`
**Maps To**: Negative Testing
**Description**: Attempt login with invalid scope in dynamic configuration to verify scope validation

**Manual Execution Steps**:
1. Launch AuthFlowTester
2. Click the settings/gear icon on the login screen to access login options
3. Expand "Static Configuration" - configure ECA Opaque (valid config)
4. Expand "Dynamic Configuration" - configure ECA JWT with invalid scope:
   - Consumer Key: ECA-JWT consumer key
   - Scopes: `invalid_scope`
5. Click "Use dynamic config"
6. Enter credentials and attempt login
7. **Verify**: Login fails or completes with no scopes granted
8. **Verify**: Invalid scope is not in granted scopes

---

## 2. Runtime Consumer Key Selection High Level Test Plan

### Overview
Tests for the feature that allows applications to override the consumer key at runtime via dynamic configuration (block/lambda), enabling different consumer keys per login host without recompiling the app.

### Test Groups

#### Group 1: Base Functional Scenarios

##### Test BF-01: Login with Dynamic Config
**Automated Test**: `LoginWithRestartTests.testECAJwt_DefaultScopes_DynamicConfiguration_WithRestart`
**Maps To**: High-Level Test Case BF-01
**Description**: Use dynamic configuration to specify consumer key at runtime

**Manual Execution Steps**:
1. Launch AuthFlowTester
2. Click the settings/gear icon on the login screen to access login options
3. Expand "Static Configuration" - configure ECA-Opaque (will be in bootconfig)
4. Expand "Dynamic Configuration" - configure ECA-JWT (different consumer key)
5. Click "Use dynamic config"
6. Enter credentials and login
8. Expand "User Credentials" section
9. **Verify**: Client ID = ECA-JWT consumer key (not ECA-Opaque)
10. **Verify**: Token format = jwt
11. Expand "OAuth Configuration" section
12. **Verify**: Static config shows ECA-Opaque settings (not used for this user)
13. Click "Make Rest API request"
14. **Verify**: API call succeeds

##### Test BF-02: Access Token Revocation and Refresh
**Automated Test**: Built into all dynamic config tests
**Maps To**: High-Level Test Case BF-02
**Description**: Verify token refresh works with dynamic configuration

**Manual Execution Steps**:
1. Complete Test BF-01
2. Note access token value
3. Click "Revoke Access Token"
4. **Verify**: Access token cleared
5. Click "Make Rest API request"
6. **Verify**: Access token refreshed (new value)
7. **Verify**: API call succeeds

#### Group 2: Multi-User Scenarios

##### Test MU-01: Two Users with Different Configs
**Automated Test**: `MultiUserLoginTests.testFirstStatic_SecondDynamic_DifferentApps`
**Maps To**: High-Level Test Case MU-01
**Description**: User A uses static config, User B uses dynamic config

**Manual Execution Steps**:
1. Launch AuthFlowTester
2. Login User A with static config (ECA-Opaque)
3. Verify User A has ECA-Opaque consumer key
4. Click "Users" icon, add User B
5. Configure dynamic config for ECA-JWT
6. Login User B with dynamic config
7. **Verify**: User B has ECA-JWT consumer key
8. Switch to User A
9. **Verify**: User A still has ECA-Opaque settings
10. Switch to User B
11. **Verify**: User B still has ECA-JWT settings
12. **Verify**: Configs are isolated per user

##### Test MU-02: Revoke One User's Access Token
**Automated Test**: `MultiUserLoginTests.testRevokeAccessForUserWithDynamicConfig_OtherUserUnaffected`
**Maps To**: High-Level Test Case MU-02
**Description**: Revoke user's token (who uses dynamic config), other user unaffected

**Manual Execution Steps**:
1. Setup two users (following Test MU-01)
2. Switch to User A
3. Click "Revoke Access Token"
4. Switch to User B
5. Click "Make Rest API request"
6. **Verify**: User B's API succeeds without refresh
7. Switch to User A
8. Click "Make Rest API request"
9. **Verify**: User A's token refreshed automatically

##### Test MU-02a: Logout One User
**Automated Test**: `MultiUserLoginTests.testLogoutUserWithDynamicConfig_OtherUserUnaffected`
**Maps To**: High-Level Test Case MU-02 (variation with logout)
**Description**: Logout user with dynamic config, verify other user unaffected and automatic switch occurs

**Manual Execution Steps**:
1. Login User A with ECA Opaque (static)
2. Add User B with ECA JWT (dynamic)
3. Currently on User B - Click "Logout" icon (bottom bar) and confirm
4. **Verify**: App automatically switches to User A
5. **Verify**: User A's credentials unchanged
6. Click "Make Rest API request"
7. **Verify**: User A's API succeeds
8. **Verify**: Cannot switch back to User B (logged out)

##### Test MU-03: Both Users Use Dynamic Config
**Automated Test**: `MultiUserLoginTests.testBothDynamic_DifferentApps`
**Maps To**: High-Level Test Case MU-01, MU-04
**Description**: Two users both using dynamic configuration with different apps

**Manual Execution Steps**:
1. Launch AuthFlowTester
2. Login User A with dynamic config (ECA-Opaque)
3. Add User B, login with dynamic config (ECA-JWT)
4. **Verify**: Each user has correct consumer key and token format
5. Switch between users multiple times
6. **Verify**: Dynamic configs persist per user
7. Make API calls for each user
8. **Verify**: API calls work correctly for both users

##### Test MU-04: Mixed Static and Dynamic Scopes
**Automated Test**: `MultiUserLoginTests.testFirstDynamic_SecondStatic_DifferentApps`
**Maps To**: Related to High-Level Test Case MU-04
**Description**: First user dynamic config, second user static config

**Manual Execution Steps**:
1. Launch AuthFlowTester
2. Login User A with dynamic config (ECA-JWT)
3. Add User B with static config (ECA-Opaque)
4. **Verify**: User A has ECA-JWT (from dynamic)
5. **Verify**: User B has ECA-Opaque (from static)
6. Switch between users
7. **Verify**: Each retains correct configuration
8. Test API calls for both
9. **Verify**: Both work independently

#### Group 3: App Restart Scenarios

##### Test RS-01: Restart After Login
**Automated Test**: `DynamicConfigLoginTests` tests with `restartAndValidate`
**Maps To**: High-Level Test Case RS-01
**Description**: Verify user session and dynamic config persist after restart

**Manual Execution Steps**:
1. Login with dynamic config (ECA-JWT)
2. Verify credentials correct
3. Terminate app (swipe up from app switcher)
4. Launch app again
5. **Verify**: User still logged in
6. **Verify**: User credentials show ECA-JWT consumer key
7. Click "Make Rest API request"
8. **Verify**: API call succeeds

##### Test RS-02: Restart, Revoke, and Refresh
**Automated Test**: Covered by restart validation in dynamic config tests
**Maps To**: High-Level Test Case RS-02
**Description**: After restart, verify token refresh still works

**Manual Execution Steps**:
1. Complete Test RS-01
2. Click "Revoke Access Token"
3. Click "Make Rest API request"
4. **Verify**: Access token refreshed
5. **Verify**: API call succeeds

##### Test RS-03: Multi-User Restart
**Automated Test**: `LoginWithRestartTests.testMultiUserRestart`
**Maps To**: High-Level Test Case RS-03
**Description**: Restart with multiple users, verify all persist

**Manual Execution Steps**:
1. Login User A with dynamic config (ECA-Opaque)
2. Add User B with static config (ECA-JWT)
3. Terminate app
4. Launch app
5. **Verify**: User A appears in user switcher
6. **Verify**: User B appears in user switcher
7. Switch to each user
8. **Verify**: Each has correct consumer key
9. Make API calls
10. **Verify**: Both work correctly

#### Group 4: Scope & Consumer Key Behavior

##### Test SC-01: Request Subset of Scopes
**Automated Test**: `LoginWithRestartTests.testECAJwt_SubsetScopes_DynamicConfiguration_WithRestart`
**Maps To**: High-Level Test Case SC-01
**Description**: Use dynamic config to request only specific scopes

**Manual Execution Steps**:
1. Launch AuthFlowTester
2. Configure dynamic config:
   - Consumer Key: ECA JWT
   - Scopes: `id api` (subset only)
3. Login with dynamic config
4. **Verify**: Granted scopes = id, api only
5. **Verify**: No other scopes present

##### Test SC-02: No Scopes Specified
**Automated Test**: `LoginWithRestartTests.testECAJwt_DefaultScopes_DynamicConfiguration_WithRestart`
**Maps To**: High-Level Test Case SC-02
**Description**: Dynamic config with no scopes → get all ECA scopes

**Manual Execution Steps**:
1. Launch AuthFlowTester
2. Configure dynamic config:
   - Consumer Key: ECA JWT
   - Scopes: (leave empty)
3. Login with dynamic config
4. **Verify**: Granted scopes include all available ECA scopes

---

## 3. Refresh Token Migration High Level Test Plan

### Overview
Tests for the feature that allows applications to exchange a refresh token for a new one with different consumer key and/or scopes, facilitating migration to Beacon apps, JWT tokens, and new scopes. The migration UI includes auth flow type configuration (Web Server Flow vs User Agent Flow, Hybrid vs Non-Hybrid) that can be set before performing the migration.

### Test Groups

#### Group 1: Baseline Login & Token Establishment

##### Test 1.1: Login with CA
**Automated Test**: `LegacyLoginTests.testCAOpaque_DefaultScopes_WebServerFlow`
**Maps To**: High-Level Test Scenario 1.1
**Description**: Establish baseline with Connected App

**Manual Execution Steps**:
1. Launch AuthFlowTester
2. Login with CA Opaque (static config)
3. **Verify**: Login succeeds
4. **Verify**: Granted scopes = id, api, refresh_token
5. Click "Make Rest API request"
6. **Verify**: API works
7. Click "Revoke Access Token", then make API call
8. **Verify**: Token refresh works

##### Test 1.2: Login with ECA
**Automated Test**: `ECALoginTests.testECAOpaque_DefaultScopes`
**Maps To**: High-Level Test Scenario 1.2
**Description**: Establish baseline with External Client App

**Manual Execution Steps**:
1. Launch AuthFlowTester
2. Login with ECA Opaque (static config)
3. **Verify**: Login succeeds
4. **Verify**: Granted scopes = id, api, refresh_token
5. Test API and refresh (same as Test 1.1)

##### Test 1.3: Login with Beacon
**Automated Test**: `BeaconLoginTests.testBeaconOpaque_DefaultScopes`
**Maps To**: High-Level Test Scenario 1.3
**Description**: Establish baseline with Beacon app

**Manual Execution Steps**:
1. Launch AuthFlowTester
2. Configure login host for advanced authentication (if needed)
3. Login with Beacon Opaque (static config)
4. **Verify**: Login succeeds
5. **Verify**: Beacon child key appears in credentials
6. **Verify**: Granted scopes = id, api, refresh_token
7. Test API and refresh

#### Group 2: Basic Migration Flows (Single User)

##### Test 2.1: Migrate CA to ECA
**Automated Test**: `RefreshTokenMigrationTests.testMigrateCAToECA`
**Maps To**: High-Level Test Scenario 2.1
**Description**: Migrate from Connected App to External Client App

**Manual Execution Steps**:
1. Launch AuthFlowTester
2. Login with CA Opaque
3. Note refresh token value
4. Click "Key" icon (bottom bar)
5. Configure migration auth flow type (optional):
   - Use Web Server Flow: On/Off
   - Use Hybrid Flow: On/Off
6. Configure migration:
   - Consumer Key: ECA Opaque
   - Scopes: (empty for default)
7. Click "Migrate"
8. **Verify**: Refresh token changed (new value)
9. **Verify**: Client ID = ECA Opaque consumer key
10. **Verify**: Granted scopes = id, api, refresh_token
11. Click "Make Rest API request"
12. **Verify**: API succeeds with new token

##### Test 2.2: Migrate CA to Beacon
**Automated Test**: `RefreshTokenMigrationTests.testMigrateCAToBeacon`
**Maps To**: High-Level Test Scenario 2.2
**Description**: Migrate from Connected App to Beacon app

**Manual Execution Steps**:
1. Launch AuthFlowTester
2. Login with CA Opaque
3. Note refresh token value
4. Click "Key" icon
5. Configure migration auth flow type (optional):
   - Use Web Server Flow: On/Off
   - Use Hybrid Flow: On/Off
6. Configure migration:
   - Consumer Key: Beacon Opaque
   - Scopes: (empty for default)
7. Click "Migrate"
8. **Verify**: Refresh token changed
9. **Verify**: Beacon child key appears in credentials
10. **Verify**: Client ID = Beacon Opaque consumer key
11. Click "Make Rest API request"
12. **Verify**: API succeeds

##### Test 2.3: Migrate ECA with Scope Addition
**Automated Test**: `RefreshTokenMigrationTests.testMigrateECA_AddMoreScopes`
**Maps To**: High-Level Test Scenario 2.3
**Description**: Migrate within same ECA, adding more scopes

**Manual Execution Steps**:
1. Launch AuthFlowTester
2. Login with ECA JWT, subset scopes (id, refresh_token)
3. Verify API call fails (no api scope)
4. Click "Key" icon
5. Configure migration auth flow type (optional):
   - Use Web Server Flow: On/Off
   - Use Hybrid Flow: On/Off
6. Configure migration:
   - Consumer Key: ECA JWT (same app)
   - Scopes: (empty for all server scopes)
7. Click "Migrate"
8. **Verify**: Refresh token changed
9. **Verify**: Granted scopes now include all available scopes
10. Click "Make Rest API request"
11. **Verify**: API succeeds

##### Test 2.4: Migrate Beacon with Scope Addition
**Automated Test**: `RefreshTokenMigrationTests.testMigrateBeacon_AddMoreScopes`
**Maps To**: High-Level Test Scenario 2.4
**Description**: Migrate within Beacon, adding scopes

**Manual Execution Steps**:
1. Launch AuthFlowTester
2. Login with Beacon JWT, subset scopes
3. Click "Key" icon
4. Configure migration:
   - Consumer Key: Beacon JWT (same app)
   - Scopes: (empty for all)
5. Click "Migrate"
6. **Verify**: Refresh token changed
7. **Verify**: Beacon child key retained
8. **Verify**: Scopes extended
9. Test API

##### Test 2.4a: Migrate CA User Agent to ECA Web Server
**Automated Test**: `RefreshTokenMigrationTests.testMigrateCAUserAgentToECAWebServer`
**Maps To**: High-Level Test Scenario 2.1 (with auth flow type change)
**Description**: Migrate from CA with user agent flow to ECA with web server flow

**Manual Execution Steps**:
1. Launch AuthFlowTester
2. Login with CA Opaque using user agent flow (disable "Use Web Server Flow" in login settings)
3. Note refresh token value
4. Click "Key" icon
5. Configure migration auth flow type:
   - Use Web Server Flow: On
   - Use Hybrid Flow: On (default)
6. Configure migration:
   - Consumer Key: ECA Opaque
   - Scopes: (empty for default)
7. Click "Migrate"
8. **Verify**: Refresh token changed
9. **Verify**: Client ID = ECA Opaque consumer key
10. Click "Make Rest API request"
11. **Verify**: API succeeds

##### Test 2.4b: Migrate CA User Agent to Beacon Web Server
**Automated Test**: `RefreshTokenMigrationTests.testMigrateCAUserAgentToBeaconWebServer`
**Maps To**: High-Level Test Scenario 2.2 (with auth flow type change)
**Description**: Migrate from CA with user agent flow to Beacon with web server flow

**Manual Execution Steps**:
1. Launch AuthFlowTester
2. Login with CA Opaque using user agent flow (disable "Use Web Server Flow" in login settings)
3. Note refresh token value
4. Click "Key" icon
5. Configure migration auth flow type:
   - Use Web Server Flow: On
   - Use Hybrid Flow: On (default)
6. Configure migration:
   - Consumer Key: Beacon Opaque
   - Scopes: (empty for default)
7. Click "Migrate"
8. **Verify**: Refresh token changed
9. **Verify**: Beacon child key appears in credentials
10. **Verify**: Client ID = Beacon Opaque consumer key
11. Click "Make Rest API request"
12. **Verify**: API succeeds

##### Test 2.5: Migrate ECA to CA (Rollback)
**Automated Test**: `RefreshTokenMigrationTests.testMigrateCAToECA` (includes rollback)
**Maps To**: High-Level Test Scenario 2.5
**Description**: Migrate from ECA back to CA

**Manual Execution Steps**:
1. Login with ECA Opaque
2. Migrate to CA Opaque
3. **Verify**: Refresh token changed
4. **Verify**: Client ID = CA Opaque consumer key
5. **Verify**: No beacon child key
6. Test API succeeds

##### Test 2.6: Migrate Beacon to CA (Rollback)
**Automated Test**: `RefreshTokenMigrationTests.testMigrateBeaconToCA`
**Maps To**: High-Level Test Scenario 2.6
**Description**: Migrate from Beacon back to CA

**Manual Execution Steps**:
1. Login with Beacon Opaque
2. Verify beacon child key present
3. Migrate to CA Opaque
4. **Verify**: Refresh token changed
5. **Verify**: Beacon child key disappears
6. **Verify**: Client ID = CA Opaque
7. Test API

##### Test 2.7: Migrate Between Token Formats (Opaque to JWT)
**Automated Test**: `RefreshTokenMigrationTests.testMigrateBeaconOpaqueToJWTAndBack`
**Maps To**: High-Level Test Scenario 2.7
**Description**: Migrate from opaque token to JWT token format

**Manual Execution Steps**:
1. Login with Beacon-Opaque
2. **Verify**: Token format = opaque (empty in UI)
3. Migrate to Beacon-JWT
4. **Verify**: Refresh token changed
5. **Verify**: Token format = jwt
6. Expand "JWT Access Token Details"
7. **Verify**: JWT details shown (expiration, scopes, etc.)
8. Test API succeeds

#### Group 3: Multi-User Scenarios

##### Test 3.1: Two Users, Both CA
**Automated Test**: `MultiUserLoginTests.testBothStatic_SameApp_SameScopes`
**Maps To**: High-Level Test Scenario 3.1
**Description**: Two users with same app type

**Manual Execution Steps**:
1. Login User A with CA Opaque
2. Add User B, login with CA Opaque
3. **Verify**: Both have independent tokens
4. Switch between users
5. **Verify**: Each retains own credentials

##### Test 3.2: Two Users, Different Apps
**Automated Test**: `MultiUserLoginTests.testBothStatic_DifferentApps`
**Maps To**: High-Level Test Scenario 3.2
**Description**: User A with CA, User B with ECA

**Manual Execution Steps**:
1. Login User A with CA Opaque
2. Add User B with ECA Opaque
3. **Verify**: User A has CA consumer key
4. **Verify**: User B has ECA consumer key
5. Switch between users
6. **Verify**: Each retains own app configuration

##### Test 3.3: Migrate One User Only
**Automated Test**: `RefreshTokenMigrationTests.testMigrateOneUserOnly`
**Maps To**: High-Level Test Scenario 3.3
**Description**: Migrate User A, leave User B unchanged

**Manual Execution Steps**:
1. Login User A with CA Opaque
2. Add User B with CA Opaque
3. Switch to User A
4. Migrate User A to ECA Opaque
5. **Verify**: User A now has ECA consumer key
6. Switch to User B
7. **Verify**: User B unchanged (still CA Opaque)
8. Test APIs for both users

##### Test 3.4: Revoke Access for One User During Multi-User
**Automated Test**: `MultiUserLoginTests.testDifferentAppTypes_RevokeAccessForCaUser_EcaUserUnaffected`
**Maps To**: High-Level Test Scenario 3.4
**Description**: Revoke CA user's access token, verify ECA user unaffected (different app types)

**Manual Execution Steps**:
1. Setup two users (any configuration)
2. Switch to User A
3. Click "Revoke Access Token"
4. Switch to User B
5. Click "Make Rest API request"
6. **Verify**: User B's API succeeds without refresh
7. Switch to User A
8. Click "Make Rest API request"
9. **Verify**: User A's token refreshed

##### Test 3.4a: Logout One User During Multi-User
**Automated Test**: `MultiUserLoginTests.testDifferentAppTypes_LogoutCaUser_EcaUserUnaffected`
**Maps To**: High-Level Test Scenario 3.4 (variation with logout)
**Description**: Logout CA user, verify ECA user unaffected and automatic switch occurs

**Manual Execution Steps**:
1. Login User A with CA Opaque
2. Add User B with ECA Opaque
3. Switch to User A
4. Click "Logout" icon (bottom bar) and confirm logout
5. **Verify**: App automatically switches to User B
6. **Verify**: User B's credentials unchanged
7. Click "Make Rest API request"
8. **Verify**: User B's API succeeds
9. **Verify**: Cannot switch back to User A (logged out)

##### Test 3.5: Beacon + Non-Beacon Multi-User
**Automated Test**: `MultiUserLoginTests.testBeaconAndNonBeacon_MultiUser`
**Maps To**: High-Level Test Scenario 3.5
**Description**: User A with Beacon, User B with CA

**Manual Execution Steps**:
1. Login User A with Beacon Opaque
2. **Verify**: User A has beacon child key
3. Add User B with CA Opaque
4. **Verify**: User B has no beacon child key
5. Switch between users
6. **Verify**: User A always shows child key
7. **Verify**: User B never shows child key

#### Group 4: Persistence & App-Restart

##### Test 4.1: Restart After CA Login
**Automated Test**: `LoginWithRestartTests.testCAOpaque_DefaultScopes_WithRestart`
**Maps To**: High-Level Test Scenario 4.1
**Description**: Verify CA session persists after restart

**Manual Execution Steps**:
1. Login with CA Opaque
2. Verify credentials
3. Terminate app
4. Launch app
5. **Verify**: User still logged in
6. **Verify**: Credentials unchanged
7. Test API succeeds

##### Test 4.2: Restart After ECA Login
**Automated Test**: `LoginWithRestartTests.testECAOpaque_DefaultScopes_WithRestart`
**Maps To**: High-Level Test Scenario 4.2
**Description**: Verify ECA session persists

**Manual Execution Steps**:
1. Login with ECA Opaque
2. Terminate and restart app
3. **Verify**: Session persists
4. Test API

##### Test 4.3: Restart After Beacon Login
**Automated Test**: `LoginWithRestartTests.testBeaconOpaque_DefaultScopes_WithRestart`
**Maps To**: High-Level Test Scenario 4.3
**Description**: Verify Beacon session and child key persist

**Manual Execution Steps**:
1. Login with Beacon Opaque
2. **Verify**: Beacon child key present
3. Terminate and restart app
4. **Verify**: Session persists
5. **Verify**: Beacon child key still present
6. Test API

##### Test 4.4: Restart After Migration (CA to ECA)
**Automated Test**: `RefreshTokenMigrationWithRestartTests.testMigrateCAToECA_WithRestart`
**Maps To**: High-Level Test Scenario 4.4
**Description**: Verify migrated tokens persist

**Manual Execution Steps**:
1. Login with CA Opaque
2. Migrate to ECA Opaque
3. Verify migration successful
4. Terminate and restart app
5. **Verify**: Migrated configuration persists
6. **Verify**: Client ID = ECA Opaque
7. Test API

##### Test 4.5: Restart After Migration (CA to Beacon)
**Automated Test**: `RefreshTokenMigrationWithRestartTests.testMigrateCAToBeacon_WithRestart`
**Maps To**: High-Level Test Scenario 4.5
**Description**: Verify beacon migration persists

**Manual Execution Steps**:
1. Login with CA Opaque
2. Migrate to Beacon Opaque
3. Terminate and restart app
4. **Verify**: Beacon child key persists
5. Test API

##### Test 4.6: Restart After Scope Migration
**Automated Test**: `RefreshTokenMigrationWithRestartTests.testMigrateScopeAddition_WithRestart`
**Maps To**: High-Level Test Scenario 4.6
**Description**: Verify scope changes persist

**Manual Execution Steps**:
1. Login with ECA JWT, subset scopes
2. Migrate to ECA JWT with all scopes
3. Verify extended scopes present
4. Terminate and restart app
5. **Verify**: Extended scopes persist
6. Test API

##### Test 4.7: Restart After Beacon Scope Migration
**Automated Test**: `RefreshTokenMigrationWithRestartTests.testMigrateBeaconScopeAddition_WithRestart`
**Maps To**: High-Level Test Scenario 4.7
**Description**: Verify beacon scope migration persists

**Manual Execution Steps**:
1. Login with Beacon JWT, subset scopes
2. Migrate to Beacon JWT with all scopes
3. Terminate and restart app
4. **Verify**: Beacon child key persists
5. **Verify**: Extended scopes persist
6. Test API

##### Test 4.8: Restart With Multiple Users
**Automated Test**: `RefreshTokenMigrationWithRestartTests.testMigrateMultipleUsers_WithRestart`
**Maps To**: High-Level Test Scenario 4.8
**Description**: Verify multi-user persistence after restart

**Manual Execution Steps**:
1. Login User A with CA Opaque
2. Migrate User A to ECA Opaque
3. Add User B with Beacon Opaque
4. Terminate and restart app
5. **Verify**: Both users in switcher
6. Switch to User A
7. **Verify**: User A has ECA Opaque config
8. Switch to User B
9. **Verify**: User B has Beacon Opaque with child key
10. Test APIs for both users

---

## Additional Test Coverage

### Legacy Login Tests

**Test Class**: `LegacyLoginTests`
**Description**: Tests for traditional Connected App (CA) authentication flows with default, subset, and all scopes using hybrid authentication. Tests both web server and user agent OAuth flows.

#### CA Web Server Flow Tests
- `testCAOpaque_DefaultScopes_WebServerFlow` - Default scopes, web server flow, hybrid
- `testCAOpaque_SubsetScopes_WebServerFlow` - Subset scopes, web server flow, hybrid
- `testCAOpaque_AllScopes_WebServerFlow` - All scopes, web server flow, hybrid

#### CA User Agent Flow Tests
- `testCAOpaque_DefaultScopes_UserAgentFlow` - Default scopes, user agent flow, hybrid
- `testCAOpaque_SubsetScopes_UserAgentFlow` - Subset scopes, user agent flow, hybrid
- `testCAOpaque_AllScopes_UserAgentFlow` - All scopes, user agent flow, hybrid

### Legacy Login Tests (Non-Hybrid)

**Test Class**: `LegacyLoginTestsNotHybrid` (extends `LegacyLoginTests`)
**Description**: Tests for traditional Connected App (CA) authentication flows using non-hybrid authentication. Extends `LegacyLoginTests` and overrides `useHybridFlow()` to return false. Non-hybrid flow means the app does not receive front-door session cookies (SIDs) for Lightning, Visualforce, and Content domains during authentication.

#### CA Web Server Flow Tests (Non-Hybrid)
- `testCAOpaque_DefaultScopes_WebServerFlow` - Default scopes, web server flow, non-hybrid
- `testCAOpaque_SubsetScopes_WebServerFlow` - Subset scopes, web server flow, non-hybrid
- `testCAOpaque_AllScopes_WebServerFlow` - All scopes, web server flow, non-hybrid

#### CA User Agent Flow Tests (Non-Hybrid)
- `testCAOpaque_DefaultScopes_UserAgentFlow` - Default scopes, user agent flow, non-hybrid
- `testCAOpaque_SubsetScopes_UserAgentFlow` - Subset scopes, user agent flow, non-hybrid
- `testCAOpaque_AllScopes_UserAgentFlow` - All scopes, user agent flow, non-hybrid

### Beacon Tests with Advanced Authentication

#### Advanced Auth Beacon Tests
**Test Class**: `AdvancedAuthBeaconLoginTests` (extends `BeaconLoginTests`)
**Description**: Same beacon tests but using advanced authentication login host

Tests all beacon scenarios with `.advancedAuth` login host instead of `.regularAuth`:
- Opaque tokens (default, subset, all scopes)
- JWT tokens (default, subset, all scopes)

### Welcome Discovery Tests

#### Welcome Discovery Flow Tests
**Test Class**: `WelcomeLoginTests`
**Description**: Tests for welcome.salesforce.com/discovery domain-based login

- `testWelcomeDiscovery_RegularAuthLoginHost` - Discovery with regular auth host, static config
- `testWelcomeDiscovery_AdvancedAuthLoginHost` - Discovery with advanced auth host, static config
- `testWelcomeDiscovery_RegularAuthLoginHost_DynamicConfig` - Discovery with dynamic config selection
- `testWelcomeDiscovery_AdvancedAuthLoginHost_DynamicConfig` - Discovery with dynamic and advanced auth

**Manual Execution**:
1. Configure login host: `welcome.salesforce.com/discovery`
2. Configure discovery settings (username pre-fill)
3. Login will redirect to user's org after domain discovery

---

## Test Configuration

### User Configuration
Tests use different users from `ui_test_config.json` to avoid login conflicts when running test suites in parallel (max 5 concurrent logins per user):
- `.first` - Used by LegacyLoginTests, ECALoginTests, BeaconLoginTests, WelcomeLoginTests
- `.second` - Used by RefreshTokenMigrationTests, AdvancedAuthBeaconLoginTests, and LoginWithRestartTests (dynamic config tests)
- `.third` - Used by RefreshTokenMigrationWithRestartTests and LoginWithRestartTests (persistence tests)
- `.fourth` and `.fifth` - Used for multi-user tests (including token revocation) in MultiUserLoginTests and related scenarios

### App Configurations
Tests reference these app configurations:
- `caOpaque` - Connected App with opaque tokens
- `caJwt` - Connected App with JWT tokens
- `ecaOpaque` - External Client App with opaque tokens
- `ecaJwt` - External Client App with JWT tokens
- `beaconOpaque` - Beacon app with opaque tokens
- `beaconJwt` - Beacon app with JWT tokens
- `invalid` - Invalid app configuration (consumer key: "invalid_consumer_key", redirect URI: "invalid://callback", scopes: "invalid_scope") for negative testing

### Scope Selections
- `.empty` - No scopes specified (default to all server scopes)
- `.subset` - Subset of scopes (all scopes except `sfap_api`)
- `.all` - All available scopes explicitly requested
- `.invalid` - Invalid scope ("invalid_scope") for negative testing scenarios

### Login Hosts
- `.regularAuth` - Standard authentication endpoint
- `.advancedAuth` - Advanced authentication endpoint (for beacon tests)

---

## Validation Steps Performed in All Tests

Each automated test performs these validations:

1. **Main Page Loads**
   - Verify AuthFlowTester main screen appears

2. **User Credentials Validation**
   - Username matches expected user
   - Client ID (consumer key) matches expected app
   - Redirect URI matches expected app
   - Granted scopes match expected scopes
   - Token format (JWT vs opaque) correct

3. **OAuth Configuration Validation**
   - Static consumer key matches bootconfig
   - Static callback URL matches bootconfig
   - Static scopes match bootconfig (persists across restarts)

4. **JWT Details Validation** (if applicable)
   - JWT access token details visible
   - Scopes in JWT match expected
   - Client ID in JWT matches
   - Expiration time present

5. **SID Validation**
   - Session ID format validated based on hybrid vs non-hybrid flow

6. **URL Validation**
   - URLs validated based on web server vs user agent flow

7. **Token Refresh Cycle**
   - Revoke access token
   - Make REST API request
   - Verify access token changed (refreshed)
   - Verify API call succeeds

8. **Beacon Child Key Validation** (if applicable)
   - Beacon child consumer key present when using beacon app
   - Absent when not using beacon app

---

## Notes

- Tests are designed to be independent and can run in any order
- Each test performs cleanup in `tearDown()` by logging out
- All tests include automatic token refresh validation
- Multi-user tests verify isolation between user sessions
- Migration tests verify refresh token changes after migration
- Restart tests verify persistence of credentials across app restarts
