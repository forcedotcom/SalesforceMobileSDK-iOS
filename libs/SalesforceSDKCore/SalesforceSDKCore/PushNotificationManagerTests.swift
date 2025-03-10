import XCTest
@testable import SalesforceSDKCore

class PushNotificationManagerTests: XCTestCase {

    var pushNotificationManager: PushNotificationManager!
    var mockRestClient: MockRestClient!
    var mockUserDefaults: UserDefaults!
    
    override func setUp() {
        super.setUp()
        pushNotificationManager = PushNotificationManager.sharedInstance()
        mockRestClient = MockRestClient()
        mockUserDefaults = UserDefaults(suiteName: "TestDefaults")!
    }

    override func tearDown() {
        mockUserDefaults.removePersistentDomain(forName: "TestDefaults")
        pushNotificationManager = nil
        mockRestClient = nil
        mockUserDefaults = nil
        super.tearDown()
    }


    func testGetNotificationTypes_SuccessfulAPIResponse() async {
        // Setup
        mockRestClient.jsonString = """
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
                        },
                        {
                            "name": "approval_pending",
                            "actions": [
                                {
                                    "name": "escalate",
                                    "identifier": "approval_pending__escalate",
                                    "label": "Escalate",
                                    "type": "NotificationApiAction"
                                },
                                {
                                    "name": "reminder",
                                    "identifier": "approval_pending__reminder",
                                    "label": "Reminder",
                                    "type": "NotificationApiAction"
                                },
                                {
                                    "name": "approve",
                                    "identifier": "approval_pending__approve",
                                    "label": "Approval",
                                    "type": "NotificationApiAction"
                                }
                            ]
                        }
                    ]
                },
                {
                    "type": "0MLSG0000009oVR4AY",
                    "apiName": "account_created",
                    "label": "Account Created",
                    "actionGroups": [
                                     {
                                         "name": "account_c",
                                         "actions": [
                                             {
                                                 "name": "view",
                                                 "identifier": "account_c__view",
                                                 "label": "View",
                                                 "type": "NotificationApiAction"
                                             },
                                             {
                                                 "name": "dismiss",
                                                 "identifier": "account_c__dismiss",
                                                 "label": "Dismiss",
                                                 "type": "NotificationApiAction"
                                             }
                                         ]
                                     }
                                     ]
                }
            ]
        }
        """

        // Test
        let (success, error) = await pushNotificationManager.getNotificationTypes(restClient: mockRestClient, userDefaults: mockUserDefaults)

        // Validate
        XCTAssertTrue(success)
        XCTAssertNil(error)
        let cachedData = mockUserDefaults.data(forKey: UserDefaultsKeys.cachedNotificationTypes)
        XCTAssertNotNil(cachedData)
    }

    func testGetNotificationTypes_FallbackToCache() async {
        // Setup
        mockRestClient.mockError = NSError(domain: "MockRestClient", code: 500, userInfo: [NSLocalizedDescriptionKey: "Mock API failure"])
        let cachedTypes = [
            NotificationType(type: "cachedType",
                             apiName: "cached_notification",
                             label: "Cached Notification",
                             actionGroups: [])
        ]
        let encodedData = try! JSONEncoder().encode(cachedTypes)
        mockUserDefaults.set(encodedData, forKey: UserDefaultsKeys.cachedNotificationTypes)

        // Test
        let (success, error) = await pushNotificationManager.getNotificationTypes(
            restClient: mockRestClient,
            userDefaults: mockUserDefaults
        )

        // Validate
        XCTAssertTrue(success, "Expected success even with API failure, since cache should be used.")
        XCTAssertNil(error, "Expected no error when falling back to cache.")
        let cachedData = mockUserDefaults.data(forKey:UserDefaultsKeys.cachedNotificationTypes)
        XCTAssertNotNil(cachedData, "Expected cached notification types to be stored and retrieved.")
    }

    func testGetNotificationTypes_FailNoCache() async {
        // Setup
        mockRestClient.mockError = NSError(
            domain: "MockRestClient",
            code: 500,
            userInfo: [NSLocalizedDescriptionKey: "Mock API failure"]
        )
        
        // Test
        mockUserDefaults.removeObject(forKey: UserDefaultsKeys.cachedNotificationTypes)
        let (success, error) = await pushNotificationManager.getNotificationTypes(
            restClient: mockRestClient,
            userDefaults: mockUserDefaults
        )

        // Validate
        XCTAssertFalse(success, "Expected failure since both API and cache are unavailable.")
        XCTAssertNotNil(error, "Expected an error when API fails and cache is empty.")
        XCTAssertEqual(error as? PushNotificationManagerError, .failedNotificationTypesRetrieval, "Expected a `failedNotificationTypesRetrieval` error.")
    }

    // MARK: - deleteNotificationTypes Tests

    func testDeleteNotificationTypes_RemovesCache() {
        // Setup
        mockUserDefaults.set(Data(), forKey: UserDefaultsKeys.cachedNotificationTypes)

        // Test
        pushNotificationManager.deleteNotificationTypes(userDefaults: mockUserDefaults)

        // Validate
        XCTAssertNil(mockUserDefaults.data(forKey: UserDefaultsKeys.cachedNotificationTypes))
    }

    func testDeleteNotificationTypes_RemovesNotificationCategories() async {
        // Setup
        mockRestClient.jsonString = """
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
                        },
                        {
                            "name": "approval_pending",
                            "actions": [
                                {
                                    "name": "escalate",
                                    "identifier": "approval_pending__escalate",
                                    "label": "Escalate",
                                    "type": "NotificationApiAction"
                                },
                                {
                                    "name": "reminder",
                                    "identifier": "approval_pending__reminder",
                                    "label": "Reminder",
                                    "type": "NotificationApiAction"
                                },
                                {
                                    "name": "approve",
                                    "identifier": "approval_pending__approve",
                                    "label": "Approval",
                                    "type": "NotificationApiAction"
                                }
                            ]
                        }
                    ]
                },
                {
                    "type": "0MLSG0000009oVR4AY",
                    "apiName": "account_created",
                    "label": "Account Created",
                    "actionGroups": [
                                     {
                                         "name": "account_c",
                                         "actions": [
                                             {
                                                 "name": "view",
                                                 "identifier": "account_c__view",
                                                 "label": "View",
                                                 "type": "NotificationApiAction"
                                             },
                                             {
                                                 "name": "dismiss",
                                                 "identifier": "account_c__dismiss",
                                                 "label": "Dismiss",
                                                 "type": "NotificationApiAction"
                                             }
                                         ]
                                     }
                                     ]
                }
            ]
        }
        """
        let (success, error) = await pushNotificationManager.getNotificationTypes(restClient: mockRestClient, userDefaults: mockUserDefaults)
        XCTAssertTrue(success, "Expected success even with API failure, since cache should be used.")
        XCTAssertNil(error, "Expected no error when falling back to cache.")
        var categories = await UNUserNotificationCenter.current().notificationCategories()
        XCTAssertFalse(categories.isEmpty, "Precondition: There should be existing categories before deletion")

        // Test
        pushNotificationManager.deleteNotificationTypes(userDefaults: mockUserDefaults)

        // Validate
        categories = await UNUserNotificationCenter.current().notificationCategories()
        XCTAssertTrue(categories.isEmpty, "Notification categories should be empty after deletion")
    }
}

// MARK: - Mock RestClient

class MockRestClient: RestClient {
    var mockError: Error?
    weak var testDelegate: RestRequestDelegate?
    // ✅ A customizable JSON string for test cases
    var jsonString: String = """
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
    """ // Default mock JSON response
    
    
    override func send(_ request: RestRequest, requestDelegate: RestRequestDelegate?) {
        print("called")
        
        let mockURLResponse = URLResponse(url: URL(string: "https://example.com")!,
                                          mimeType: "application/json",
                                          expectedContentLength: 0,
                                          textEncodingName: "utf-8")
        
        if let error = mockError {
            requestDelegate?.request?(request, didSucceed: error, rawResponse: mockURLResponse)
            return
        }
        
        if let jsonData = jsonString.data(using: .utf8) {
            requestDelegate?.request?(request, didSucceed: jsonData, rawResponse: mockURLResponse)
        }
    }
}

class MockRestClientDelegate: NSObject, RestRequestDelegate {
    var receivedResponse: Any?
    var receivedError: Error?

    func request(_ request: RestRequest, didLoadResponse jsonResponse: Any) {
        receivedResponse = jsonResponse
        print("Mock delegate received response: \(jsonResponse)")
    }

    func request(_ request: RestRequest, didFailLoadWithError error: Error, rawResponse: URLResponse?) {
        receivedError = error
        print("Mock delegate received error: \(error.localizedDescription)")
    }

    func requestDidCancelLoad(_ request: RestRequest) {
        print("Mock delegate: request canceled")
    }

    func requestDidTimeout(_ request: RestRequest) {
        print("Mock delegate: request timed out")
    }
}
