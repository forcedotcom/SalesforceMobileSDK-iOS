import Foundation

public typealias SFRestRequestFailBlock = (_ response: Any?, _ error: Error?, _ rawResponse: URLResponse?) -> Void
public typealias SFRestDictionaryResponseBlock = (_ dict: [String: Any]?, _ rawResponse: URLResponse?) -> Void
public typealias SFRestArrayResponseBlock = (_ array: [Any]?, _ rawResponse: URLResponse?) -> Void
public typealias SFRestDataResponseBlock = (_ data: Data?, _ rawResponse: URLResponse?) -> Void
public typealias SFRestResponseBlock = (_ response: Any?, _ rawResponse: URLResponse?) -> Void
public typealias SFRestCompositeResponseBlock = (_ response: CompositeResponse, _ rawResponse: URLResponse?) -> Void
public typealias SFRestBatchResponseBlock = (_ response: BatchResponse, _ rawResponse: URLResponse?) -> Void

extension RestClient {
    @objc(errorWithDescription:)
    public static func error(withDescription description: String) -> NSError {
        let userInfo: [String: Any] = [
            NSLocalizedDescriptionKey: description,
            NSFilePathErrorKey: ""
        ]
        return NSError(domain: "API Error", code: 42, userInfo: userInfo)
    }

    @objc
    public func sendRequest(_ request: RestRequest) async throws -> (Any?, URLResponse?) {
        try await withCheckedThrowingContinuation { continuation in
            self.send(request, failureBlock: { response, error, rawResponse in
                continuation.resume(throwing: error ?? RestClient.error(withDescription: "Unknown error"))
            }, successBlock: { response, rawResponse in
                continuation.resume(returning: (response, rawResponse))
            })
        }
    }

    @objc
    public func sendCompositeRequest(_ request: CompositeRequest) async throws -> (CompositeResponse, URLResponse?) {
        let (response, rawResponse) = try await sendRequest(request)
        guard let dict = response as? [AnyHashable: Any] else {
            throw RestClient.error(withDescription: "CompositeResponse format invalid")
        }
        let compositeResponse = CompositeResponse(dict)
        return (compositeResponse, rawResponse)
    }

    @objc
    public func sendBatchRequest(_ request: BatchRequest) async throws -> (BatchResponse, URLResponse?) {
        let (response, rawResponse) = try await sendRequest(request)
        guard let dict = response as? [AnyHashable: Any] else {
            throw RestClient.error(withDescription: "BatchResponse format invalid")
        }
        let batchResponse = BatchResponse(dict)
        return (batchResponse, rawResponse)
    }
}
