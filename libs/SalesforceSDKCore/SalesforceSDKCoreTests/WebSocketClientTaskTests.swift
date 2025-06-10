import XCTest

@testable import SalesforceSDKCore

class MockWebSocketTask: WebSocketClientTaskProtocol {
    var sentMessages: [URLSessionWebSocketTask.Message] = []
    var didCancel = false
    var originalRequest: URLRequest?
    var shouldError = false
    
    func send(_ message: URLSessionWebSocketTask.Message, completionHandler: @escaping @Sendable ((any Error)?) -> Void) {
        sentMessages.append(message)
        completionHandler(nil)
    }
    
    func receive(completionHandler: @escaping @Sendable (Result<URLSessionWebSocketTask.Message, any Error>) -> Void) {
        if !shouldError {
            completionHandler(.success(URLSessionWebSocketTask.Message.string("incoming")))
        } else {
            let error = NSError(domain: "test", code: 1, userInfo: nil)
            completionHandler(.failure(error))
        }
    }
    
    func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        didCancel = true
    }
    
    func shouldRetry() -> Bool {
        return true
    }
    
    func cancel() {
        didCancel = true
    }
    
    func resume() {
        didCancel = false
    }
}

class MockNetwork: WebSocketNetworkProtocol {
    var shouldError = false
    func webSocketTask(with request: URLRequest) -> any SalesforceSDKCore.WebSocketClientTaskProtocol {
        let task = MockWebSocketTask()
        task.originalRequest = request
        task.shouldError = shouldError
        return task
    }
}

class MockUserAccountManager: UserAccountManaging {
    let mockUserAccount = UserAccount()
    let mockInfo = AuthInfo()
    
    var shouldError = false
    
    func account() -> UserAccount? {
        mockUserAccount
    }
    
    func refresh(credentials: OAuthCredentials, _ completionBlock: @escaping (Result<(UserAccount, AuthInfo), SalesforceSDKCore.UserAccountManagerError>) -> Void) -> Bool {
        if shouldError {
            let error = NSError(domain: "test", code: 1, userInfo: nil)
            let refreshError = UserAccountManagerError.refreshFailed(underlyingError: error, authInfo: mockInfo)
            completionBlock(.failure(refreshError))
        } else {
            completionBlock(.success((mockUserAccount, mockInfo)))
        }
        return true
    }
}

final class WebSocketClientTaskTests: XCTestCase {
    
    func testSendMessageSuccess() {
        // Given
        let mockTask = MockWebSocketTask()
        let client = WebSocketClientTask(task: mockTask)
        let message = URLSessionWebSocketTask.Message.string("test")
        let expectation = self.expectation(description: "Send completes")
        
        // When
        client.send(message) { error in
            // Then
            XCTAssertNil(error)
            XCTAssertEqual(mockTask.sentMessages.count, 1)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testCancelTask() {
        // Given
        let mockTask = MockWebSocketTask()
        let client = WebSocketClientTask(task: mockTask)
        
        // When
        client.cancel()
        
        // Then
        XCTAssertTrue(mockTask.didCancel)
    }
    
    func testListenReceivesSuccessMessage() {
        
        // Given
        let mockTask = MockWebSocketTask()
        let client = WebSocketClientTask(task: mockTask)
        let expectation = self.expectation(description: "Message received")
        
        // When
        client.listen { result in
            switch result {
            case .success(_):
                // Then
                expectation.fulfill()
            case .failure(_):
                XCTFail("Expected success")
            }
        }
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testListenReceivesFailureAndPerformRetryToSuccess() {
        // Given
        let mockTask = MockWebSocketTask()
        mockTask.shouldError.toggle()
        mockTask.originalRequest = URLRequest(url: URL(string: "ws://mock.com")!)
        let mockNetwork = MockNetwork()
        let mockAccountManager = MockUserAccountManager()
        let client = WebSocketClientTask(task: mockTask,
                                         network: mockNetwork,
                                         accountManager: mockAccountManager)
        let expectation = self.expectation(description: "Error received")
        
        // When
        client.listen { result in
            switch result {
            case .success(let message):
                // Then
                XCTAssertNotNil(message)
                expectation.fulfill()
            default:
                XCTFail("Expected Success")
            }
        }
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testListenReceivesFailureAndPerformRetryToFailure() {
        // Given
        let mockTask = MockWebSocketTask()
        mockTask.shouldError.toggle()
        mockTask.originalRequest = URLRequest(url: URL(string: "ws://mock.com")!)
        let mockAccountManager = MockUserAccountManager()
        mockAccountManager.shouldError.toggle()
        let mockNetwork = MockNetwork()
        mockNetwork.shouldError.toggle()
        let client = WebSocketClientTask(task: mockTask,
                                         network: mockNetwork,
                                         accountManager: mockAccountManager)
        let expectation = self.expectation(description: "Error received")
        
        // When
        client.listen { result in
            switch result {
            case .failure(let error):
                // Then
                XCTAssertNotNil(error)
                expectation.fulfill()
            default:
                XCTFail("Expected Failure")
            }
        }
        wait(for: [expectation], timeout: 1.0)
    }
}
