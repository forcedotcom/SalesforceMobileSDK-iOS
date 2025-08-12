import XCTest
@testable import SalesforceSDKCore

class SFOAuthCoordinatorTests: XCTestCase {
    func testDecidePolicyForNavigationAction_DomainDiscoveryCallback() {
        // Given
        let expectedLoginHint = "testuser@example.com"
        let mockDomain = "mydomain.example.com"
        let callbackURLString = "sfdc://discocallback?my_domain=\(mockDomain.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)&login_hint=\(expectedLoginHint.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)"
        guard let callbackURL = URL(string: callbackURLString) else {
            XCTFail("Failed to create callback URL")
            return
        }
        let mockNavigationAction = MockNavigationAction(url: callbackURL)
        let coordinator = SFOAuthCoordinator()
        coordinator.delegate = self
        let credentials = OAuthCredentials(identifier: "test",
                                           clientId: "client",
                                           encrypted: false)
        credentials?.testDomain = "foo.bar.com/discovery"
        credentials?.testRedirectURI = "sfdc://callback"
        coordinator.credentials = credentials
        
        // When
        coordinator.authenticate(with: credentials!)
        
        // Then
        var didCallDecisionHandlerPolicy: WKNavigationActionPolicy = .allow
        coordinator.webView(WKWebView(), decidePolicyFor: mockNavigationAction, decisionHandler: { policy in
            didCallDecisionHandlerPolicy = policy
        })
        
        // Assert
        XCTAssertEqual(didCallDecisionHandlerPolicy, .cancel)
        XCTAssertEqual(coordinator.testLoginHint, expectedLoginHint)
        XCTAssertEqual(coordinator.credentials?.domain, mockDomain)
    }
}

// MARK: - SFOAuthCoordinatorDelegate conformance for tests
extension SFOAuthCoordinatorTests: SFOAuthCoordinatorDelegate {
    func oauthCoordinator(_ coordinator: SFOAuthCoordinator, didBeginAuthenticationWith view: WKWebView) {}
    func oauthCoordinator(_ coordinator: SFOAuthCoordinator, didBeginAuthenticationWith session: ASWebAuthenticationSession) {}
    func oauthCoordinatorDidBeginNativeAuthentication(_ coordinator: SFOAuthCoordinator) {}
    func oauthCoordinatorDidCancelBrowserAuthentication(_ coordinator: SFOAuthCoordinator) {}
}

// MARK: - Test-only extension for SFOAuthCredentials to set domain
@testable import SalesforceSDKCore

extension OAuthCredentials {
    var testDomain: String? {
        get { return self.domain }
        set { self.setValue(newValue, forKey: "domain") }
    }
    
    var testRedirectURI: String? {
        get { return self.redirectUri }
        set { self.setValue(newValue, forKey: "redirectUri") }
    }
}

// MARK: - Test-only extension for SFOAuthCoordinator to get loginHint
extension SFOAuthCoordinator {
    var testLoginHint: String? {
        get { self.value(forKey: "loginHint") as? String }
        set { self.setValue(newValue, forKey: "loginHint") }
    }
}
