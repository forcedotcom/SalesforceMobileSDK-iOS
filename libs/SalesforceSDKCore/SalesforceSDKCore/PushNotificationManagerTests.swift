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
        let types = try await pushNotificationManager.getNotificationTypes(restClient: mockRestClient, account: mockUserAccount)

        // Then
        XCTAssertFalse(types.isEmpty, "Expected notification types")
        let cachedData = try? XCTUnwrap(mockUserAccount.notificationTypes)
        XCTAssertFalse(cachedData!.isEmpty, "Expected notification types to be stored")
    }

    func testGetNotificationTypes_FallbackToCache() async throws {
        // Given
        mockRestClient.mockError = NSError(domain: "MockRestClient", code: 500, userInfo: [NSLocalizedDescriptionKey: "Mock API failure"])
        mockUserAccount.notificationTypes = [NotificationType(type: "cachedType", apiName: "cached_notification", label: "Cached Notification", actionGroups: [])]

        // When
        let types = try await pushNotificationManager.getNotificationTypes(restClient: mockRestClient, account: mockUserAccount)

        // Then
        XCTAssertFalse(types.isEmpty, "Expected success even with API failure, since cache should be used.")
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
            _ = try await pushNotificationManager.getNotificationTypes(restClient: mockRestClient, account: mockUserAccount)
        } catch {
            // Then
            XCTAssertNotNil(error)
            return
        }
        
        // Should throw an error before we get here.
        XCTFail()
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
                                    "identifier": "approval_req__approve",
                                    "label": "Approve",
                                    "type": "NotificationApiAction"
                                },
                                {
                                    "name": "deny",
                                    "identifier": "approval_req__deny",
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
