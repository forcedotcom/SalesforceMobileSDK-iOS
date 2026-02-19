/*
 Copyright (c) 2026-present, salesforce.com, inc. All rights reserved.

 Redistribution and use of this software in source and binary forms, with or without modification,
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
import SwiftUI
@testable import SalesforceSDKCore

class DiscoveryResultEditorTests: XCTestCase {

    func testApplySimulatedResultWithHostAndUserCallsCallbackWithResult() {
        var loginHost = "mycompany.my.salesforce.com"
        var userName = "user@company.com"
        var receivedResult: DomainDiscoveryResult?

        let view = DiscoveryResultEditor(
            loginHost: Binding(get: { loginHost }, set: { loginHost = $0 }),
            userName: Binding(get: { userName }, set: { userName = $0 }),
            onUseForSimulation: { receivedResult = $0 }
        )

        view.applySimulatedResult()

        XCTAssertNotNil(receivedResult, "Callback should receive a result when host and user are set")
        XCTAssertEqual(receivedResult?.myDomain, "mycompany.my.salesforce.com")
        XCTAssertEqual(receivedResult?.loginHint, "user@company.com")
    }

    func testApplySimulatedResultWithEmptyHostCallsCallbackWithNil() {
        var loginHost = ""
        var userName = "user@company.com"
        var receivedResult: DomainDiscoveryResult?

        let view = DiscoveryResultEditor(
            loginHost: Binding(get: { loginHost }, set: { loginHost = $0 }),
            userName: Binding(get: { userName }, set: { userName = $0 }),
            onUseForSimulation: { receivedResult = $0 }
        )

        view.applySimulatedResult()

        XCTAssertNil(receivedResult, "Callback should receive nil when login host is empty")
    }

    func testApplySimulatedResultWithHostOnlyAllowsEmptyLoginHint() {
        var loginHost = "mycompany.my.salesforce.com"
        var userName = ""
        var receivedResult: DomainDiscoveryResult?

        let view = DiscoveryResultEditor(
            loginHost: Binding(get: { loginHost }, set: { loginHost = $0 }),
            userName: Binding(get: { userName }, set: { userName = $0 }),
            onUseForSimulation: { receivedResult = $0 }
        )

        view.applySimulatedResult()

        XCTAssertNotNil(receivedResult, "Callback should receive a result when only host is set")
        XCTAssertEqual(receivedResult?.myDomain, "mycompany.my.salesforce.com")
        XCTAssertEqual(receivedResult?.loginHint, "")
    }

}
