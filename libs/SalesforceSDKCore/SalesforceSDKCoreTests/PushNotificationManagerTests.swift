import XCTest
@testable import SalesforceSDKCore

class PushNotificationManagerTests: XCTestCase {

    var pushNotificationManager: PushNotificationManager!
    var mockRestClient: MockRestClient!
    var mockUserAccount: UserAccount!
    var mockApplicationHelper: MockApplicationHelper!
    var originalMethod: IMP?
    var mockPreferences: MockPreferences!
    
    override func setUp() {
        super.setUp()
        mockApplicationHelper = MockApplicationHelper()
        
        mockRestClient = MockRestClient()
        mockRestClient.apiVersion = SFRestDefaultAPIVersion
        mockUserAccount = UserAccount()
        mockPreferences = MockPreferences()
        mockPreferences.setObject("mock-sfid", forKey: PushNotificationConstants.deviceSalesforceId)
        pushNotificationManager = PushNotificationManager(notificationRegister: mockApplicationHelper,
                                                          apiVersion: SFRestDefaultAPIVersion,
                                                          restClient: mockRestClient,
                                                          currentUser: mockUserAccount,
                                                          preferences: mockPreferences)
        pushNotificationManager.isSimulator = false
    }

    override func tearDown() {
        // Restore original method
        if let originalMethod = originalMethod {
            let originalSelector = #selector(SFPreferences.sharedPreferences(for:user:))
            class_replaceMethod(SFPreferences.self, originalSelector, originalMethod, "@@:@@")
        }
        
        mockUserAccount = nil
        pushNotificationManager = nil
        mockRestClient = nil
        mockApplicationHelper = nil
        UserAccountManager.shared.currentUserAccount = nil
        super.tearDown()
    }

    // MARK: - Remote Registration Tests
    
    func testRegisterForRemoteNotifications_Simulator() {
        // Given
        pushNotificationManager.isSimulator = true
        
        // When
        pushNotificationManager.registerForRemoteNotifications()
        
        // Then - No crash, just logs and returns
        XCTAssertFalse(mockApplicationHelper.registerForRemoteNotificationsCalled)
    }
    
    func testRegisterForRemoteNotifications_RealDevice() {
        // Given
        pushNotificationManager.isSimulator = false
        
        // When
        pushNotificationManager.registerForRemoteNotifications()
        
        // Then
        XCTAssertTrue(mockApplicationHelper.registerForRemoteNotificationsCalled)
    }
    
    func testDidRegisterForRemoteNotificationsWithDeviceToken() {
        // Given
        let deviceToken = Data([0x01, 0x02, 0x03, 0x04])
        
        // When
        pushNotificationManager.didRegisterForRemoteNotifications(withDeviceToken: deviceToken)
        
        // Then
        XCTAssertNotNil(pushNotificationManager.deviceToken)
        XCTAssertEqual(pushNotificationManager.deviceToken, "01020304")
    }
    
    func testRegisterSalesforceNotifications_NoCurrentUser() {
        // Given
        UserAccountManager.shared.currentUserAccount = nil
        
        // When
        let result = pushNotificationManager.registerSalesforceNotifications(completionBlock: nil, failBlock: nil)
        
        // Then
        XCTAssertFalse(result)
    }
    
    func testRegisterSalesforceNotifications_NoDeviceToken() {
        // Given
        pushNotificationManager.deviceToken = nil
        
        // When
        let result = pushNotificationManager.registerSalesforceNotifications(completionBlock: nil, failBlock: nil)
        
        // Then
        XCTAssertFalse(result)
    }
    
    func testUnregisterSalesforceNotifications_NoCurrentUser() {
        // Given
        UserAccountManager.shared.currentUserAccount = nil
        
        // When
        let result = pushNotificationManager.unregisterSalesforceNotifications(completionBlock: nil)
        
        // Then
        XCTAssertFalse(result)
    }
    
    func testUnregisterSalesforceNotifications_NoDeviceSalesforceId() {
        // Given
        pushNotificationManager.deviceSalesforceId = nil
        UserAccountManager.shared.currentUserAccount = mockUserAccount
        
        // When
        let result = pushNotificationManager.unregisterSalesforceNotifications(completionBlock: nil)
        
        // Then
        XCTAssertTrue(result)
    }
    
    func testUnregisterSalesforceNotifications_Simulator() {
        // Given
        pushNotificationManager.isSimulator = true
        UserAccountManager.shared.currentUserAccount = mockUserAccount
        
        // When
        let result = pushNotificationManager.unregisterSalesforceNotifications(completionBlock: nil)
        
        // Then
        XCTAssertTrue(result)
    }
    
    // MARK: - Modern Swift API Tests
    
    func testRegisterForSalesforceNotifications_Success() {
        // Given
        let expectation = XCTestExpectation(description: "Registration completion")
        pushNotificationManager.deviceToken = "test-token"
        UserAccountManager.shared.currentUserAccount = mockUserAccount
        // Set up mock REST client to succeed
        mockRestClient.jsonResponse = """
        {
            "success": true
        }
        """.data(using: .utf8)!
        
        // When
        pushNotificationManager.registerForSalesforceNotifications { result in
            // Then
            switch result {
            case .success(let success):
                XCTAssertTrue(success)
            case .failure:
                XCTFail("Should not fail")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testRegisterForSalesforceNotifications_NoCurrentUser() {
        // Given
        let expectation = XCTestExpectation(description: "Registration completion")
        UserAccountManager.shared.currentUserAccount = nil
        
        // When
        pushNotificationManager.registerForSalesforceNotifications { result in
            // Then
            switch result {
            case .success:
                XCTFail("Should fail")
            case .failure(let error):
                XCTAssertEqual(error, .currentUserNotDetected)
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testUnregisterForSalesforceNotifications_Success() {
        // Given
        
        let expectation = XCTestExpectation(description: "Unregistration completion")
        pushNotificationManager.deviceSalesforceId = "test-id"
        UserAccountManager.shared.currentUserAccount = mockUserAccount
        
        // Set up mock REST client to succeed
        mockRestClient.jsonResponse = """
        {
            "success": true
        }
        """.data(using: .utf8)!
        
        // When
        pushNotificationManager.unregisterForSalesforceNotifications { success in
            // Then
            XCTAssertTrue(success)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testUnregisterForSalesforceNotifications_NoPreferences() {
        // Given
        let expectation = XCTestExpectation(description: "Unregistration completion")
        pushNotificationManager.deviceSalesforceId = "test-id"
        UserAccountManager.shared.currentUserAccount = mockUserAccount
        mockPreferences.objects.removeAll()
        
        // When
        pushNotificationManager.unregisterForSalesforceNotifications { success in
            // Then
            XCTAssertFalse(success)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testUnregisterForSalesforceNotifications_NoDeviceId() {
        // Given
        let expectation = XCTestExpectation(description: "Unregistration completion")
        pushNotificationManager.isSimulator = false
        UserAccountManager.shared.currentUserAccount = mockUserAccount
        pushNotificationManager.deviceSalesforceId = nil
        
        // When
        pushNotificationManager.unregisterForSalesforceNotifications { success in
            // Then
            XCTAssertTrue(success)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - RSA Public Key Tests
    
    func testGetRSAPublicKey() {
        // When
        let publicKey = pushNotificationManager.getRSAPublicKey()
        
        // Then
        XCTAssertNotNil(publicKey)
    }
    
    // MARK: - Notification Types Tests
    
    func testGetNotificationTypes_Success() {
        // Given
        let mockTypes = [NotificationType(type: "test", apiName: "test", label: "Test", actionGroups: [])]
        mockUserAccount.notificationTypes = mockTypes
        
        // When
        let types = pushNotificationManager.getNotificationTypes(account: mockUserAccount)
        
        // Then
        XCTAssertNotNil(types)
        XCTAssertEqual(types?.count, 1)
        XCTAssertEqual(types?.first?.apiName, "test")
    }
    
    func testGetNotificationTypes_NoAccount() {
        // When
        let types = pushNotificationManager.getNotificationTypes(account: nil)
        
        // Then
        XCTAssertNil(types)
    }
    
    // MARK: - Action Tests
    
    func testGetActionGroups_Success() {
        // Given
        let mockNotificationType = NotificationType(type: "test_type", apiName: "test_api_name", label: "Test Label", actionGroups: [
            ActionGroup(name: "group_1", actions: [])
        ])
        mockUserAccount.notificationTypes = [mockNotificationType]

        // When
        let actionGroups = pushNotificationManager.getActionGroups(notificationTypeApiName: "test_api_name", account: mockUserAccount)

        // Then
        XCTAssertNotNil(actionGroups)
        XCTAssertEqual(actionGroups?.count, 1)
        XCTAssertEqual(actionGroups?.first?.name, "group_1")
    }

    func testGetActionGroup_Success() {
        // Given
        let actionGroup = ActionGroup(name: "group_1", actions: [])
        let mockNotificationType = NotificationType(type: "test_type", apiName: "test_api_name", label: "Test Label", actionGroups: [actionGroup])
        mockUserAccount.notificationTypes = [mockNotificationType]

        // When
        let retrievedActionGroup = pushNotificationManager.getActionGroup(notificationTypeApiName: "test_api_name", actionGroupName: "group_1", account: mockUserAccount)

        // Then
        XCTAssertNotNil(retrievedActionGroup)
        XCTAssertEqual(retrievedActionGroup?.name, "group_1")
    }

    func testGetAction_Failure() {
        // Given
        mockUserAccount.notificationTypes = []

        // When
        let retrievedAction = pushNotificationManager.getAction(notificationTypeApiName: "invalid_api_name", actionIdentifier: "non_existent_action", account: mockUserAccount)

        // Then
        XCTAssertNil(retrievedAction)
    }

    // MARK: - Invoke Server Notification Action Tests

    func testInvokeServerNotificationAction_Success() async throws {
        // Given
        mockRestClient.apiVersion = "v64.0"
        mockRestClient.jsonResponse = """
        {
            "message": "Action executed successfully"
        }
        """.data(using: .utf8)!

        // When
        let result = try await pushNotificationManager.invokeServerNotificationAction(
            client: mockRestClient,
            notificationId: "test_notification",
            actionIdentifier: "test_action"
        )

        // Then
        XCTAssertEqual(result.message, "Action executed successfully")
    }
    
    func testInvokeServerNotificationAction_APITooLow() async {
        // Given
        mockRestClient.apiVersion = "v63.0"

        // When/Then: Verify that the call throws the expected error.
        do {
            _ = try await pushNotificationManager.invokeServerNotificationAction(
                client: mockRestClient,
                notificationId: "test_notification",
                actionIdentifier: "test_action"
            )
            XCTFail("Expected PushNotificationManagerError.notificationActionInvocationFailed error, but no error was thrown.")
        } catch let error as PushNotificationManagerError {
            XCTAssertEqual(error, .notificationActionInvocationFailed("API Version must be at least v64.0"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testInvokeServerNotificationAction_Failure() async throws {
        // Given
        mockRestClient.apiVersion = "v64.0"
        mockRestClient.mockError = NSError(domain: "MockRestClient", code: 500, userInfo: [NSLocalizedDescriptionKey: "Server Error"])

        // When
        do {
            _ = try await pushNotificationManager.invokeServerNotificationAction(
                client: mockRestClient,
                notificationId: "test_notification",
                actionIdentifier: "test_action"
            )
        } catch {
            // Then
            XCTAssertNotNil(error)
            return
        }

        XCTFail("Expected an error but succeeded")
    }
    
    // MARK: - Helper Function
    private func makeMockJSONResponse() -> Data {
        let json = """
        {
          "notificationTypes": [
            {
              "actionGroups": [
                {
                  "actions": [
                    {
                      "actionKey": "new_acc_and_opp__new_account",
                      "label": "New Account",
                      "name": "new_account",
                      "type": "NotificationApiAction"
                    },
                    {
                      "actionKey": "new_acc_and_opp__new_opportunity",
                      "label": "New Opportunity",
                      "name": "new_opportunity",
                      "type": "NotificationApiAction"
                    }
                  ],
                  "name": "new_acc_and_opp"
                },
                {
                  "actions": [
                    {
                      "actionKey": "updateCase__escalate",
                      "label": "Escalate",
                      "name": "escalate",
                      "type": "NotificationApiAction"
                    },
                    {
                      "actionKey": "updateCase__raise_priority",
                      "label": "Raise Priority",
                      "name": "raise_priority",
                      "type": "NotificationApiAction"
                    }
                  ],
                  "name": "updateCase"
                }
              ],
              "apiName": "actionable_notif_test_type",
              "label": "Actionable Notification Test Type",
              "type": "actionable_notif_test_type"
            },
            {
              "apiName": "approval_request",
              "label": "Approval requests",
              "type": "approval_request"
            },
            {
              "apiName": "chatter_comment_on_post",
              "label": "New comments on a post",
              "type": "chatter_comment_on_post"
            },
            {
              "apiName": "chatter_group_mention",
              "label": "Group mentions on a post",
              "type": "chatter_group_mention"
            },
            {
              "apiName": "chatter_mention",
              "label": "Individual mentions on a post",
              "type": "chatter_mention"
            },
            {
              "apiName": "group_announce",
              "label": "Group manager announcements",
              "type": "group_announce"
            },
            {
              "apiName": "group_post",
              "label": "Posts to a group",
              "type": "group_post"
            },
            {
              "apiName": "personal_analytic",
              "label": "Salesforce Classic report updates",
              "type": "personal_analytic"
            },
            {
              "apiName": "profile_post",
              "label": "Posts to a profile",
              "type": "profile_post"
            },
            {
              "apiName": "stream_post",
              "label": "Posts to a stream",
              "type": "stream_post"
            },
            {
              "apiName": "task_delegated_to",
              "label": "Task assignments",
              "type": "task_delegated_to"
            }
          ]
        }
        """
        return json.data(using: .utf8)!
    }

    // MARK: - Error Tests
    
    func testPushNotificationManagerError_Equatable_SameCases() {
        // Test same cases without associated values
        XCTAssertEqual(PushNotificationManagerError.registrationFailed, PushNotificationManagerError.registrationFailed)
        XCTAssertEqual(PushNotificationManagerError.currentUserNotDetected, PushNotificationManagerError.currentUserNotDetected)
        XCTAssertEqual(PushNotificationManagerError.failedNotificationTypesRetrieval, PushNotificationManagerError.failedNotificationTypesRetrieval)
        
        // Test same cases with same associated values
        let error1 = PushNotificationManagerError.notificationActionInvocationFailed("test error")
        let error2 = PushNotificationManagerError.notificationActionInvocationFailed("test error")
        XCTAssertEqual(error1, error2)
    }
    
    func testPushNotificationManagerError_Equatable_DifferentCases() {
        // Test different cases without associated values
        XCTAssertNotEqual(PushNotificationManagerError.registrationFailed, PushNotificationManagerError.currentUserNotDetected)
        XCTAssertNotEqual(PushNotificationManagerError.registrationFailed, PushNotificationManagerError.failedNotificationTypesRetrieval)
        XCTAssertNotEqual(PushNotificationManagerError.currentUserNotDetected, PushNotificationManagerError.failedNotificationTypesRetrieval)
        
        // Test same case with different associated values
        let error1 = PushNotificationManagerError.notificationActionInvocationFailed("error 1")
        let error2 = PushNotificationManagerError.notificationActionInvocationFailed("error 2")
        XCTAssertNotEqual(error1, error2)
        
        // Test different cases with and without associated values
        XCTAssertNotEqual(PushNotificationManagerError.registrationFailed, PushNotificationManagerError.notificationActionInvocationFailed("test"))
        XCTAssertNotEqual(PushNotificationManagerError.currentUserNotDetected, PushNotificationManagerError.notificationActionInvocationFailed("test"))
        XCTAssertNotEqual(PushNotificationManagerError.failedNotificationTypesRetrieval, PushNotificationManagerError.notificationActionInvocationFailed("test"))
    }
    
    func testPushNotificationManagerError_Equatable_EmptyString() {
        // Test with empty string
        let error1 = PushNotificationManagerError.notificationActionInvocationFailed("")
        let error2 = PushNotificationManagerError.notificationActionInvocationFailed("")
        XCTAssertEqual(error1, error2)
        
        // Test empty string vs non-empty string
        let error3 = PushNotificationManagerError.notificationActionInvocationFailed("not empty")
        XCTAssertNotEqual(error1, error3)
    }

    // MARK: - Fetch and Store Notification Types Tests
    
    func testFetchAndStoreNotificationTypes_Success() async throws {
        // Given
        mockRestClient.apiVersion = "v64.0"
        mockRestClient.jsonResponse = makeMockJSONResponse()
        
        // When
        try await pushNotificationManager.fetchAndStoreNotificationTypes(
            restClient: mockRestClient,
            account: mockUserAccount
        )
        
        // Then
        XCTAssertNotNil(mockUserAccount.notificationTypes)
        XCTAssertEqual(mockUserAccount.notificationTypes?.count, 11)
        
    }
    
    func testFetchAndStoreNotificationTypes_NoAccount() async {
        // Given
        let nilAccount: UserAccount? = nil
        
        // When/Then
        do {
            try await pushNotificationManager.fetchAndStoreNotificationTypes(
                restClient: mockRestClient,
                account: nilAccount
            )
            XCTFail("Expected currentUserNotDetected error")
        } catch let error as PushNotificationManagerError {
            XCTAssertEqual(error, .currentUserNotDetected)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testFetchAndStoreNotificationTypes_APITooLow() async {
        // Given
        mockRestClient.apiVersion = "v63.0"
        
        // When/Then
        do {
            try await pushNotificationManager.fetchAndStoreNotificationTypes(
                restClient: mockRestClient,
                account: mockUserAccount
            )
            XCTFail("Expected notificationActionInvocationFailed error")
        } catch let error as PushNotificationManagerError {
            XCTAssertEqual(error, .failedNotificationTypesRetrieval)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testFetchAndStoreNotificationTypes_ServerErrorWithCache() async throws {
        // Given
        mockRestClient.apiVersion = "v64.0"
        mockRestClient.mockError = NSError(domain: "MockRestClient", code: 500, userInfo: [NSLocalizedDescriptionKey: "Server Error"])
        
        // Set up cached types
        let cachedTypes = [
            NotificationType(type: "cached_type", apiName: "cached_type", label: "Cached Type", actionGroups: [])
        ]
        mockUserAccount.notificationTypes = cachedTypes
        
        // When
        try await pushNotificationManager.fetchAndStoreNotificationTypes(
            restClient: mockRestClient,
            account: mockUserAccount
        )
        
        // Then
        XCTAssertNotNil(mockUserAccount.notificationTypes)
        XCTAssertEqual(mockUserAccount.notificationTypes?.count, 1)
        XCTAssertEqual(mockUserAccount.notificationTypes?.first?.apiName, "cached_type")
    }
    
    func testFetchAndStoreNotificationTypes_ServerErrorNoCache() async {
        // Given
        mockRestClient.apiVersion = "v64.0"
        mockRestClient.mockError = NSError(domain: "MockRestClient", code: 500, userInfo: [NSLocalizedDescriptionKey: "Server Error"])
        mockUserAccount.notificationTypes = nil
        
        // When/Then
        do {
            try await pushNotificationManager.fetchAndStoreNotificationTypes(
                restClient: mockRestClient,
                account: mockUserAccount
            )
            XCTFail("Expected failedNotificationTypesRetrieval error")
        } catch let error as PushNotificationManagerError {
            XCTAssertEqual(error, .failedNotificationTypesRetrieval)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testFetchAndStoreNotificationTypes_InvalidResponseWithCache() async throws {
        // Given
        mockRestClient.apiVersion = "v64.0"
        mockRestClient.jsonResponse = "invalid json".data(using: .utf8)!
        
        // Set up cached types
        let cachedTypes = [
            NotificationType(type: "cached_type", apiName: "cached_type", label: "Cached Type", actionGroups: [])
        ]
        mockUserAccount.notificationTypes = cachedTypes
        
        // When
        try await pushNotificationManager.fetchAndStoreNotificationTypes(
            restClient: mockRestClient,
            account: mockUserAccount
        )
        
        // Then
        XCTAssertNotNil(mockUserAccount.notificationTypes)
        XCTAssertEqual(mockUserAccount.notificationTypes?.count, 1)
        XCTAssertEqual(mockUserAccount.notificationTypes?.first?.apiName, "cached_type")
    }
}

class NotificationCategoryFactoryTests: XCTestCase {
    var factory: NotificationCategoryFactory!
    
    override func setUp() {
        super.setUp()
        factory = NotificationCategoryFactory.shared
    }
    
    override func tearDown() {
        factory = nil
        super.tearDown()
    }
    
    func testCreateCategories_WithActualJSON() throws {
        // Given
        let json = """
        {
            "notificationTypes": [
                {
                    "type": "chatter_mention",
                    "apiName": "chatter_mention",
                    "label": "Chatter Mention",
                    "actionGroups": []
                },
                {
                    "type": "approval_notification",
                    "apiName": "approval_notification",
                    "label": "Approval Notification",
                    "actionGroups": [
                        {
                            "name": "approval_req",
                            "actions": [
                                {
                                    "name": "approve",
                                    "actionKey": "approval_req__approve",
                                    "label": "Approve",
                                    "type": "NotificationApiAction"
                                },
                                {
                                    "name": "deny",
                                    "actionKey": "approval_req__deny",
                                    "label": "Deny",
                                    "type": "NotificationApiAction"
                                }
                            ]
                        }
                    ]
                }
            ]
        }
        """
        let jsonData = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(NotificationTypesResponse.self, from: jsonData)
        
        // When
        let categories = factory.createCategories(from: response.notificationTypes)
        
        // Then
        XCTAssertEqual(categories.count, 1, "Should only create categories for notification types with action groups")
        
        // Verify approval_notification category
        let approvalCategory = categories.first { $0.identifier == "approval_req" }
        XCTAssertNotNil(approvalCategory, "Should create category for approval_notification")
        XCTAssertEqual(approvalCategory?.actions.count, 2, "Should create both approve and deny actions")
        
        // Verify approve action
        let approveAction = approvalCategory?.actions.first { $0.identifier == "approval_req__approve" }
        XCTAssertNotNil(approveAction, "Should create approve action")
        XCTAssertEqual(approveAction?.title, "Approve")
        guard let options = approveAction?.options else {
            XCTFail("Should have options")
            return
        }
        XCTAssertTrue(options.contains(.authenticationRequired))
        XCTAssertFalse(options.contains(.foreground))
        
        // Verify deny action
        let denyAction = approvalCategory?.actions.first { $0.identifier == "approval_req__deny" }
        XCTAssertNotNil(denyAction, "Should create deny action")
        XCTAssertEqual(denyAction?.title, "Deny")
        guard let options = denyAction?.options else {
            XCTFail("Should have options")
            return
        }
        XCTAssertTrue(options.contains(.authenticationRequired))
        XCTAssertFalse(options.contains(.foreground))
    }
    
    func testCreateCategories_WithNonApiAction() throws {
        // Given
        let json = """
        {
            "notificationTypes": [
                {
                    "type": "chatter_mention",
                    "apiName": "chatter_mention",
                    "label": "Chatter Mention",
                    "actionGroups": []
                },
                {
                    "type": "custom_notification",
                    "apiName": "custom_notification",
                    "label": "Custom Notification",
                    "actionGroups": [
                        {
                            "name": "custom_actions",
                            "actions": [
                                {
                                    "name": "view",
                                    "actionKey": "custom_actions__view",
                                    "label": "View Details",
                                    "type": "foreground"
                                },
                                {
                                    "name": "dismiss",
                                    "actionKey": "custom_actions__dismiss",
                                    "label": "Dismiss",
                                    "type": "dismiss"
                                }
                            ]
                        }
                    ]
                }
            ]
        }
        """
        let jsonData = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(NotificationTypesResponse.self, from: jsonData)
        
        // When
        let categories = factory.createCategories(from: response.notificationTypes)
        
        // Then
        XCTAssertEqual(categories.count, 1, "Should only create categories for notification types with action groups")
        
        // Verify custom_notification category
        let customCategory = categories.first { $0.identifier == "custom_actions" }
        XCTAssertNotNil(customCategory, "Should create category for custom_notification")
        XCTAssertEqual(customCategory?.actions.count, 2, "Should create both view and dismiss actions")
        
        // Verify view action
        let viewAction = customCategory?.actions.first { $0.identifier == "custom_actions__view" }
        XCTAssertNotNil(viewAction, "Should create view action")
        XCTAssertEqual(viewAction?.title, "View Details")
        guard let options = viewAction?.options else {
            XCTFail("Should have options")
            return
        }
        XCTAssertTrue(options.contains(.foreground))
        XCTAssertFalse(options.contains(.authenticationRequired))
        
        // Verify dismiss action
        let dismissAction = customCategory?.actions.first { $0.identifier == "custom_actions__dismiss" }
        XCTAssertNotNil(dismissAction, "Should create dismiss action")
        XCTAssertEqual(dismissAction?.title, "Dismiss")
        guard let options = dismissAction?.options else {
            XCTFail("Should have options")
            return
        }
        XCTAssertTrue(options.contains(.foreground))
        XCTAssertFalse(options.contains(.authenticationRequired))
    }
}

class ActionTypeTests: XCTestCase {
    
    func testActionTypeDecoding() throws {
        // Given
        let json = """
        {
            "name": "test",
            "actionKey": "test_key",
            "label": "Test Label",
            "type": "NotificationApiAction"
        }
        """
        let jsonData = json.data(using: .utf8)!
        
        // When
        let action = try JSONDecoder().decode(Action.self, from: jsonData)
        
        // Then
        XCTAssertEqual(action.type, .notificationApiAction)
    }
    
    func testActionTypeDecodingForeground() throws {
        // Given
        let json = """
        {
            "name": "test",
            "actionKey": "test_key",
            "label": "Test Label",
            "type": "foreground"
        }
        """
        let jsonData = json.data(using: .utf8)!
        
        // When
        let action = try JSONDecoder().decode(Action.self, from: jsonData)
        
        // Then
        XCTAssertEqual(action.type, .foregroundAction)
    }
    
    func testActionTypeStringValue() {
        // Test notificationApiAction
        let apiAction = NotificationActionType.notificationApiAction
        XCTAssertEqual(apiAction.stringValue, "NotificationApiAction")
        
        // Test foregroundAction
        let foregroundAction = NotificationActionType.foregroundAction
        XCTAssertEqual(foregroundAction.stringValue, "ForegroundAction")
    }
    
    func testActionTypeDecodingInvalidType() throws {
        // Given
        let json = """
        {
            "name": "test",
            "actionKey": "test_key",
            "label": "Test Label",
            "invalidType": "invalidType"
        }
        """
        let jsonData = json.data(using: .utf8)!
        
        // When, Then
        XCTAssertThrowsError(try JSONDecoder().decode(Action.self, from: jsonData))
    }
    
    func testActionTypeDecodingDefaultCase() throws {
        // Given
        let json = """
        {
            "name": "test",
            "actionKey": "test_key",
            "label": "Test Label",
            "type": "dismiss"
        }
        """
        let jsonData = json.data(using: .utf8)!
        
        // When
        let action = try JSONDecoder().decode(Action.self, from: jsonData)
        
        // Then
        XCTAssertEqual(action.type, .foregroundAction, "Unknown type should default to foregroundAction")
    }
}

// MARK: - Mocks
class MockApplicationHelper: RemoteNotificationRegistering {
    var registerForRemoteNotificationsCalled = false
    
    func registerForRemoteNotifications() {
        registerForRemoteNotificationsCalled = true
    }
}

class MockPreferences: SFPreferences {
    var objects: [String: Any] = [:]
    override func string(forKey key: String) -> String? {
        return objects[key] as? String
    }
    
    override func setObject(_ object: Any, forKey key: String) {
        objects[key] = object
    }
}
