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

    override func send(_ request: RestRequest, requestDelegate: RestRequestDelegate?) {
        let mockURLResponse = HTTPURLResponse(url: URL(string: "https://example.com")!,
                                              mimeType: "application/json",
                                              expectedContentLength: 0,
                                              textEncodingName: "utf-8")
        
        if let error = mockError {
            requestDelegate?.request?(request, didSucceed: error, rawResponse: mockURLResponse)
            return
        }
        
        requestDelegate?.request?(request, didSucceed: jsonResponse, rawResponse: mockURLResponse)
    }
    
    override func send(_ request: RestRequest, failureBlock: @escaping RestRequestFailBlock, successBlock: @escaping RestResponseBlock) {
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
