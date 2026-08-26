@testable import SalesforceSDKCore

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

    // Add tracking for test verification
    var sendCallCount = 0
    var lastRequest: RestRequest?
    var allRequests: [RestRequest] = []
    var onSend: ((RestRequest) -> Void)?

    override func send(_ request: RestRequest, failureBlock: @escaping RestRequestFailBlock, successBlock: @escaping RestResponseBlock) {
        sendCallCount += 1
        lastRequest = request
        allRequests.append(request)
        onSend?(request)

        let mockURLResponse = HTTPURLResponse(url: URL(string: "https://example.com")!,
                                              mimeType: "application/json",
                                              expectedContentLength: 0,
                                              textEncodingName: "utf-8")
        if let error = mockError {
            failureBlock(jsonResponse, error, mockURLResponse)
            return
        }
        successBlock(jsonResponse, mockURLResponse)
    }
}
