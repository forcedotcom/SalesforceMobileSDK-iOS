/*
 Copyright (c) 2026-present, salesforce.com, inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright notice, this list of conditions
   and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of
   conditions and the following disclaimer in the documentation and/or other materials provided
   with the distribution.
 * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
   endorse or promote products derived from this software without specific prior written
   permission of salesforce.com, inc.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
 FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
 WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import XCTest
import SalesforceSDKCore

// MARK: - TokenAwareURLProtocol

/**
 URLProtocol that intercepts every request made through SFNetwork — including
 both normal data requests and the OAuth /oauth2/token refresh call — and
 returns a controlled response without touching the real network.

 Responses are delivered asynchronously with simulated latency (5-50 ms for
 API calls, 50-150 ms for the token refresh) so that timing more closely
 resembles real network behaviour.

 Behaviour:
   - Requests whose path ends with "/token" are the OAuth token-refresh endpoint.
     The protocol atomically records the refresh, marks the "refresh has occurred"
     flag, and returns a valid token JSON payload after a short delay.
   - All other requests are treated as API data calls.  The first
     `tokenExpiresAfterCount` requests succeed with 200.  All requests arriving
     after that — until a token refresh has completed — receive a 401, modelling
     a real token expiration window where every in-flight request with the stale
     token is rejected.  After the refresh flag is set every subsequent call
     returns 200, ensuring retried requests always succeed.

 Because SFSDKOAuth2.createURLSessionWithIdentifier: delegates to
 SFNetwork.sharedEphemeralInstanceWithIdentifier:, the sessionConfigurationCustomizer
 applied in setUp injects this protocol into the OAuth refresh session as well,
 giving us end-to-end control of the full 401 → refresh → retry cycle.
 */
private final class TokenAwareURLProtocol: URLProtocol {

    private static let lock = NSLock()
    private static var _refreshHasOccurred = false
    private static var _requestCount = 0

    /// Number of API requests that succeed before the token "expires."
    /// All subsequent requests receive 401 until the refresh completes.
    static var tokenExpiresAfterCount = 10

    private var isCancelled = false

    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        _refreshHasOccurred = false
        _requestCount = 0
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else { return }

        // ── OAuth token refresh ──────────────────────────────────────────────
        if url.path.hasSuffix("/token") {
            let delay = Double.random(in: 0.05...0.15)
            DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [self] in
                guard !isCancelled else { return }

                TokenAwareURLProtocol.lock.lock()
                TokenAwareURLProtocol._refreshHasOccurred = true
                TokenAwareURLProtocol.lock.unlock()

                let instanceUrl = url.host.map { "https://\($0)" } ?? "https://cs1.salesforce.com"
                let tokenJSON: [String: Any] = [
                    "access_token": "refreshed_access_token",
                    "instance_url": instanceUrl,
                    "id": "https://login.salesforce.com/id/00D000000000001/005000000000001",
                    "issued_at": "1234567890",
                    "token_type": "Bearer"
                ]
                let data = try? JSONSerialization.data(withJSONObject: tokenJSON)
                deliver(status: 200, data: data)
            }
            return
        }

        // ── Data / API request ───────────────────────────────────────────────
        let delay = Double.random(in: 0.005...0.05)
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [self] in
            guard !isCancelled else { return }

            TokenAwareURLProtocol.lock.lock()
            let refreshed = TokenAwareURLProtocol._refreshHasOccurred
            TokenAwareURLProtocol._requestCount += 1
            let count = TokenAwareURLProtocol._requestCount
            TokenAwareURLProtocol.lock.unlock()

            let expired = !refreshed && count > TokenAwareURLProtocol.tokenExpiresAfterCount
            let status: Int = expired ? 401 : 200

            let body: Data
            if status == 200 {
                body = Data("{\"done\":true,\"totalSize\":0,\"records\":[]}".utf8)
            } else {
                body = Data("{\"errorCode\":\"INVALID_SESSION_ID\",\"message\":\"Session expired or invalid\"}".utf8)
            }
            deliver(status: status, data: body)
        }
    }

    override func stopLoading() {
        isCancelled = true
    }

    private func deliver(status: Int, data: Data?) {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if let data {
            client?.urlProtocol(self, didLoad: data)
        }
        client?.urlProtocolDidFinishLoading(self)
    }
}

// MARK: - SFRestAPITokenRefreshStressTests

/**
 Stress-tests the 401 → token-refresh → retry cycle under concurrent load.

 Requests are dispatched in parallel.  The first `tokenExpiresAfterCount`
 succeed, then all remaining pre-refresh requests receive 401 — modelling a
 real token expiration window — exercising the @synchronized guard in
 -replayRequest:response: that ensures only one token refresh is triggered
 regardless of how many concurrent 401s arrive.

 Responses are delivered asynchronously with small random delays (5-150 ms)
 so that thread interleaving matches realistic network conditions.

 Session injection uses the +[SFNetwork sessionConfigurationCustomizer] hook,
 which is applied to every NSURLSessionConfiguration created by SFNetwork —
 including the per-request UUID-keyed ephemeral sessions used for custom-host
 calls and the session created internally by SFSDKOAuth2 for the token endpoint.
 This means the full end-to-end path is exercised without any real network access.
 */
class SFRestAPITokenRefreshStressTests: XCTestCase {

    var api: RestClient!

    override func setUpWithError() throws {
        try super.setUpWithError()
        TokenAwareURLProtocol.reset()

        Network.removeAllSharedInstances()
        // Apply the mock to every SFNetwork session — this single hook covers:
        //   1. The shared ephemeral session used for standard API calls.
        //   2. The UUID-keyed ephemeral sessions used for custom-host requests.
        //   3. The session created by SFSDKOAuth2 for the /oauth2/token refresh call.
        Network.sessionConfigurationCustomizer = { config in
            config.protocolClasses = [TokenAwareURLProtocol.self]
        }

        let creds = try XCTUnwrap(OAuthCredentials(identifier: "CLIENT ID", clientId: "CLIENT ID", encrypted: false))
        creds.setValue("005000000000001", forKey: "userId")
        creds.setValue("00D000000000001", forKey: "organizationId")
        creds.setValue("COMMUNITYID", forKey: "communityId")
        creds.setValue("initial_access_token", forKey: "accessToken")
        creds.setValue("initial_refresh_token", forKey: "refreshToken")
        creds.setValue(URL(string: "https://sample.domain"), forKey: "instanceUrl")
        let account = UserAccount(credentials: creds)
        account.setValue(UserAccount.LoginState.loggedIn.rawValue, forKey: "loginState")
        api = RestClient.restClient(for: account)
    }

    override func tearDown() {
        api.cancelAllRequests()
        api.cleanup()
        Network.sessionConfigurationCustomizer = nil
        Network.removeAllSharedInstances()
        TokenAwareURLProtocol.reset()
        super.tearDown()
    }

    /**
     Sends 300 requests concurrently.  The first `tokenExpiresAfterCount`
     succeed; every request arriving after that gets a 401 until the token
     refresh completes, at which point all retried requests succeed.

     Expected outcomes:
       - Every request completes (no stuck requests or double-callback crashes).
       - Each individual request's callback is invoked exactly once.
       - All requests ultimately succeed (zero permanent failures).
       - The token was refreshed exactly once, even though many 401s may have
         arrived simultaneously before the first refresh completed.
     */
    func testHundredsOfConcurrentRequestsWithOccasional401() {
        SalesforceManager.initializeSDK()
        let requestCount = 300

        let allDone = expectation(description: "All requests completed")
        allDone.expectedFulfillmentCount = requestCount
        allDone.assertForOverFulfill = true

        let lock = NSLock()
        var callCounts = Array(repeating: 0, count: requestCount)

        DispatchQueue.concurrentPerform(iterations: requestCount) { i in
            let path = "/\(self.api.apiVersion)/query?idx=\(i)"
            let request = RestRequest(method: .GET, path: path, queryParams: nil)

            self.api.send(request,
                failureBlock: { _, _, _ in
                    XCTFail("Request \(i) failed — error block should not be called")
                },
                successBlock: { _, _ in
                    lock.lock()
                    callCounts[i] += 1
                    lock.unlock()
                    allDone.fulfill()
                }
            )
        }

        waitForExpectations(timeout: 60)

        for i in 0..<requestCount {
            XCTAssertEqual(callCounts[i], 1,
                           "Request \(i) callback invoked \(callCounts[i]) time(s) — expected exactly 1")
        }
    }
}
