import XCTest
@testable import SalesforceSDKCore

class URLSessionTaskRetryPolicyTests: XCTestCase {

    class MockBiometricAuthenticationManager: BiometricAuthenticationManager {
        var enabled: Bool
        
        var locked: Bool
        
        func lock() {
            locked = true
        }
        
        func biometricOptIn(optIn: Bool) {
            locked = optIn
            enabled = optIn
        }
        
        func hasBiometricOptedIn() -> Bool {
            return enabled
        }
        
        func presentOptInDialog(viewController: UIViewController) {
            // TODO:
        }
        
        func enableNativeBiometricLoginButton(enabled: Bool) {
            self.enabled = enabled
            locked = enabled
        }
        
        init(enabled: Bool, locked: Bool) {
            self.enabled = enabled
            self.locked = locked
        }
    }

    var mockManager: MockBiometricAuthenticationManager!
    
    override func setUp() {
        super.setUp()
        mockManager = MockBiometricAuthenticationManager(enabled: false, locked: false)
    }

    override func tearDown() {
        super.tearDown()
        mockManager = nil
    }

    func testShouldRetryWith401AndUnlocked() {
        let task = MockURLSessionTask(statusCode: 401, urlPath: "/some/endpoint")
        mockManager.locked = false

        XCTAssertTrue(task.shouldRetry(with: nil, biometricAuthManager: mockManager))
    }

    func testShouldNotRetryWith401AndLocked() {
        let task = MockURLSessionTask(statusCode: 401, urlPath: "/some/endpoint")
        mockManager.locked = true

        XCTAssertFalse(task.shouldRetry(with: nil, biometricAuthManager: mockManager))
    }

    func testShouldRetryWith403BadOAuthTokenAndUnlocked() {
        let data = "Bad_OAuth_Token".data(using: .utf8)
        let task = MockURLSessionTask(statusCode: 403, urlPath: "/services/oauth2")
        mockManager.locked = false

        XCTAssertTrue(task.shouldRetry(with: data, biometricAuthManager: mockManager))
    }

    func testShouldNotRetryWith403BadOAuthTokenAndLocked() {
        let data = "Bad_OAuth_Token".data(using: .utf8)
        let task = MockURLSessionTask(statusCode: 403, urlPath: "/services/oauth2")
        mockManager.locked = true

        XCTAssertFalse(task.shouldRetry(with: data, biometricAuthManager: mockManager))
    }

    func testShouldNotRetryWith403NonOAuthPath() {
        let data = "Bad_OAuth_Token".data(using: .utf8)
        let task = MockURLSessionTask(statusCode: 403, urlPath: "/not/oauth2")
        mockManager.locked = false

        XCTAssertFalse(task.shouldRetry(with: data, biometricAuthManager: mockManager))
    }

    func testShouldNotRetryWith403WrongBody() {
        let data = "SomeOtherError".data(using: .utf8)
        let task = MockURLSessionTask(statusCode: 403, urlPath: "/services/oauth2")
        mockManager.locked = false

        XCTAssertFalse(task.shouldRetry(with: data, biometricAuthManager: mockManager))
    }

    func testShouldNotRetryWithOtherStatusCode() {
        let task = MockURLSessionTask(statusCode: 500, urlPath: "/services/oauth2")
        mockManager.locked = false

        XCTAssertFalse(task.shouldRetry(with: nil, biometricAuthManager: mockManager))
    }
}

class MockURLSessionTask: RetryPolicyEvaluating, @unchecked Sendable {
    var response: URLResponse?
    var originalRequest: URLRequest?
    var statusCode: Int
    var urlPath: String
    
    init(statusCode: Int, urlPath: String) {
        self.statusCode = statusCode
        self.urlPath = urlPath
        response = HTTPURLResponse(url: URL(string: urlPath)!,
                                   statusCode: statusCode,
                                   httpVersion: nil,
                                   headerFields: nil)
        originalRequest = URLRequest(url: URL(string: urlPath)!)
        
    }
    
    func shouldRetry(with responseData: Data? = nil, biometricAuthManager: any SalesforceSDKCore.BiometricAuthenticationManager) -> Bool {
        let policy = SessionTaskRetryPolicy()
        return policy.shouldRetry(with: responseData,
                                  biometricAuthManager: biometricAuthManager,
                                  for: originalRequest,
                                  and: response)
    }
}

