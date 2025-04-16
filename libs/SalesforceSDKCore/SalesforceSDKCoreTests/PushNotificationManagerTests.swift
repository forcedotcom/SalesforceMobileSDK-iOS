import XCTest
@testable import SalesforceSDKCore

class PushNotificationManagerTests: XCTestCase {

    var pushNotificationManager: PushNotificationManager!
    var mockRestClient: MockRestClient!
    var mockUserAccount: UserAccount!
    
    override func setUp() {
        super.setUp()
        pushNotificationManager = PushNotificationManager.sharedInstance()
        mockRestClient = MockRestClient()
        mockRestClient.apiVersion = "v64.0"
        mockUserAccount = UserAccount()
    }

    override func tearDown() {
        mockUserAccount = nil
        pushNotificationManager = nil
        mockRestClient = nil
        super.tearDown()
    }

    func testGetNotificationTypes_SuccessfulAPIResponse() async throws {
        // Given
        mockRestClient.jsonResponse = makeMockJSONResponse()

        // When
        try await pushNotificationManager.fetchAndStoreNotificationTypes(restClient: mockRestClient, account: mockUserAccount)

        // Then
        let cachedData = try? XCTUnwrap(mockUserAccount.notificationTypes)
        XCTAssertFalse(cachedData!.isEmpty, "Expected notification types to be stored")
    }

    func testGetNotificationTypes_FallbackToCache() async throws {
        // Given
        mockRestClient.mockError = NSError(domain: "MockRestClient", code: 500, userInfo: [NSLocalizedDescriptionKey: "Mock API failure"])
        mockUserAccount.notificationTypes = [NotificationType(type: "cachedType", apiName: "cached_notification", label: "Cached Notification", actionGroups: [])]

        // When
        try await pushNotificationManager.fetchAndStoreNotificationTypes(restClient: mockRestClient, account: mockUserAccount)

        // Then
        let cachedData = try? XCTUnwrap(mockUserAccount.notificationTypes)
        XCTAssertFalse(cachedData!.isEmpty, "Expected cached notification types to be retrieved.")
    }

    func testGetNotificationTypes_FailNoCache() async throws {
        // Given
        mockRestClient.mockError = NSError(
            domain: "MockRestClient",
            code: 500,
            userInfo: [NSLocalizedDescriptionKey: "Mock API failure"]
        )
        mockUserAccount.notificationTypes = nil

        // When
        do {
            try await pushNotificationManager.fetchAndStoreNotificationTypes(restClient: mockRestClient, account: mockUserAccount)
        } catch {
            // Then
            XCTAssertNotNil(error)
            return
        }
        XCTFail("Should throw an assertion before we get here.")
    }
    
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

        func testGetAction_Success() {
            // Given
            let action = Action(name: "approve", identifier: "approval_req__approve", label: "Approve", type: .notificationApiAction)
            let actionGroup = ActionGroup(name: "approval_req", actions: [action])
            let mockNotificationType = NotificationType(type: "test_type", apiName: "test_api_name", label: "Test Label", actionGroups: [actionGroup])
            mockUserAccount.notificationTypes = [mockNotificationType]

            // When
            let retrievedAction = pushNotificationManager.getAction(notificationTypeApiName: "test_api_name", actionIdentifier: "approval_req__approve", account: mockUserAccount)

            // Then
            XCTAssertNotNil(retrievedAction)
            XCTAssertEqual(retrievedAction?.identifier, "approval_req__approve")
            XCTAssertEqual(retrievedAction?.label, "Approve")
        }

        func testGetAction_Failure() {
            // Given
            mockUserAccount.notificationTypes = []

            // When
            let retrievedAction = pushNotificationManager.getAction(notificationTypeApiName: "invalid_api_name", actionIdentifier: "non_existent_action", account: mockUserAccount)

            // Then
            XCTAssertNil(retrievedAction)
        }

        // MARK: - Invoke Server Notification Action

        func testInvokeServerNotificationAction_Success() async throws {
            // Given
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

        func testInvokeServerNotificationAction_Failure() async throws {
            // Given
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
        return json.data(using: .utf8)!
    }
}

// MARK: - Mock RestClient

class MockRestClient: RestClient {
    var mockError: Error?
    weak var testDelegate: RestRequestDelegate?
    var jsonResponse: Data = """
    {
        "notificationTypes": [
            {
                "type": "chatter_mention",
                "apiName": "chatter_mention",
                "label": "Chatter Mention",
                "actionGroups": []
            }
        ]
    }
    """.data(using: .utf8)! // Default mock JSON response

    override func send(_ request: RestRequest, requestDelegate: RestRequestDelegate?) {
        let mockURLResponse = URLResponse(url: URL(string: "https://example.com")!,
                                          mimeType: "application/json",
                                          expectedContentLength: 0,
                                          textEncodingName: "utf-8")

        if let error = mockError {
            requestDelegate?.request?(request, didSucceed: error, rawResponse: mockURLResponse)
            return
        }
        
        requestDelegate?.request?(request, didSucceed: jsonResponse, rawResponse: mockURLResponse)
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
