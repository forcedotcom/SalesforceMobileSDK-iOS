import XCTest
@testable import SalesforceSDKCore

class MockWebSocket: WebSocketClientTaskProtocol {
    func send(_ message: URLSessionWebSocketTask.Message) async throws {
        sentMessages.append(message)
    }
    
    func receive() async throws -> URLSessionWebSocketTask.Message {
        guard keepReceivingMessages else {
            throw CancellationError()
        }
        
        if shouldError {
            throw NSError(domain: "test", code: 1, userInfo: nil)
        } else {
            return .string("incoming")
        }
    }
    
    var sentMessages: [URLSessionWebSocketTask.Message] = []
    var didCancel = false
    var originalRequest: URLRequest?
    var shouldError = false
    var keepReceivingMessages: Bool = true
    
    func send(_ message: URLSessionWebSocketTask.Message, completionHandler: @escaping @Sendable ((any Error)?) -> Void) {
        sentMessages.append(message)
        completionHandler(nil)
    }
    
    func receive(completionHandler: @escaping @Sendable (Result<URLSessionWebSocketTask.Message, any Error>) -> Void) {
        
        guard keepReceivingMessages else { return }
        
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
    var mockWebSocket: MockWebSocket?
    
    func webSocketTask(with request: URLRequest) -> any SalesforceSDKCore.WebSocketClientTaskProtocol {
        if let mockWebSocket {
            mockWebSocket.shouldError = false
            return mockWebSocket
        }
        let task = MockWebSocket()
        task.originalRequest = request
        task.shouldError = shouldError
        return task
    }
}

final class WebSocketClientTests: XCTestCase {
    
    func testSendMessageSuccess() async {
        // Given
        let mockTask = MockWebSocket()
        let client = WebSocketClient(task: mockTask)
        let message = URLSessionWebSocketTask.Message.string("test")
        
        // When
        do {
            try await client.send(message)
            XCTAssertEqual(mockTask.sentMessages.count, 1)
        } catch {
            XCTFail("Shouldn't send message: \(error)")
        }
    }
    
    func testCancelTask() {
        // Given
        let mockTask = MockWebSocket()
        let client = WebSocketClient(task: mockTask)
        
        // When
        client.cancel()
        
        // Then
        XCTAssertTrue(mockTask.didCancel)
    }
    
    func testListenReceivesSuccessMessage() {
        
        // Given
        let mockTask = MockWebSocket()
        let client = WebSocketClient(task: mockTask)
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
        let mockTask = MockWebSocket()
        mockTask.shouldError.toggle()
        mockTask.originalRequest = URLRequest(url: URL(string: "ws://mock.com")!)
        let mockNetwork = MockNetwork()
        mockNetwork.mockWebSocket = mockTask
        let mockAccountManager = MockUserAccountManager()
        let client = WebSocketClient(task: mockTask,
                                     network: mockNetwork,
                                     accountManager: mockAccountManager)
        let expectation = self.expectation(description: "Success received")
        
        // When
        client.listen { result in
            mockTask.keepReceivingMessages.toggle()
            switch result {
            case .success(let message):
                // Then
                XCTAssertNotNil(message)
                expectation.fulfill()
            default: break
            }
        }
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testListenReceivesFailureAndPerformRetryToFailure() {
        // Given
        let mockTask = MockWebSocket()
        mockTask.shouldError.toggle()
        mockTask.originalRequest = URLRequest(url: URL(string: "ws://mock.com")!)
        let mockAccountManager = MockUserAccountManager()
        mockAccountManager.shouldError.toggle()
        let mockNetwork = MockNetwork()
        mockNetwork.shouldError.toggle()
        let client = WebSocketClient(task: mockTask,
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
