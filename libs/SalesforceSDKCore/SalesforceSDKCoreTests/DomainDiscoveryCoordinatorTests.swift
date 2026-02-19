import XCTest
@testable import SalesforceSDKCore
import WebKit

/// Tests for DomainDiscoveryCoordinator. We avoid creating WKWebView and calling load(_:)
/// in the parsing tests because WKWebView initialization in a unit test context can be
/// fragile and cause intermittent crashes. Instead we build a MockNavigationAction
/// and call coordinator.handle(action:) directly.
@MainActor
final class DomainDiscoveryCoordinatorTests: XCTestCase {

    func testCallbackSuccess() async throws {
        // Given
        let coordinator = DomainDiscoveryCoordinator()
        let expectedDomain = "foo.my.salesforce.com"
        let mockDomain = "https://\(expectedDomain)"
        let expectedLoginHint = "testuser@example.com"
        let encodedDomain = try XCTUnwrap(mockDomain.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed))
        let encodedHint = try XCTUnwrap(expectedLoginHint.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed))
        let callbackURLString = "sfdc://discocallback?my_domain=\(encodedDomain)&login_hint=\(encodedHint)"
        let callbackURL = try XCTUnwrap(URL(string: callbackURLString))
        let action = MockNavigationAction(url: callbackURL)

        // When
        let results = coordinator.handle(action: action)

        // Then
        XCTAssertEqual(results?.myDomain, expectedDomain)
        XCTAssertEqual(results?.loginHint, expectedLoginHint)
    }

    func testMissingMyDomain() async throws {
        // Given
        let coordinator = DomainDiscoveryCoordinator()
        let expectedLoginHint = "testuser@example.com"
        let encodedHint = try XCTUnwrap(expectedLoginHint.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed))
        let callbackURLString = "sfdc://discocallback?login_hint=\(encodedHint)"
        let callbackURL = try XCTUnwrap(URL(string: callbackURLString))
        let action = MockNavigationAction(url: callbackURL)

        // When
        let results = coordinator.handle(action: action)

        // Then
        XCTAssertNil(results)
    }

    func testMissingLoginHint() async throws {
        // Given
        let coordinator = DomainDiscoveryCoordinator()
        let expectedDomain = "foo.my.salesforce.com"
        let mockDomain = "https://\(expectedDomain)"
        let encodedDomain = try XCTUnwrap(mockDomain.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed))
        let callbackURLString = "sfdc://discocallback?my_domain=\(encodedDomain)"
        let callbackURL = try XCTUnwrap(URL(string: callbackURLString))
        let action = MockNavigationAction(url: callbackURL)

        // When
        let results = coordinator.handle(action: action)

        // Then
        XCTAssertNil(results)
    }

    func testMalformedCallbackURL() async throws {
        // Given
        let coordinator = DomainDiscoveryCoordinator()
        let callbackURLString = "sfdc://discocallback?my_domain=&login_hint="
        let callbackURL = try XCTUnwrap(URL(string: callbackURLString))
        let action = MockNavigationAction(url: callbackURL)

        // When
        let results = coordinator.handle(action: action)

        // Then
        XCTAssertEqual(results?.myDomain, "")
        XCTAssertEqual(results?.loginHint, "")
    }

    func testNonCallbackURL() async throws {
        // Given
        let coordinator = DomainDiscoveryCoordinator()
        let nonCallbackURL = try XCTUnwrap(URL(string: "https://example.com"))
        let action = MockNavigationAction(url: nonCallbackURL)

        // When
        let results = coordinator.handle(action: action)

        // Then
        XCTAssertNil(results)
    }

    func testSpecialCharactersInLoginHint() async throws {
        // Given
        let coordinator = DomainDiscoveryCoordinator()
        let expectedDomain = "foo.my.salesforce.com"
        let mockDomain = "https://\(expectedDomain)"
        let expectedLoginHint = "user+test@example.com"
        let encodedDomain = try XCTUnwrap(mockDomain.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed))
        let encodedHint = try XCTUnwrap(expectedLoginHint.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed))
        let callbackURLString = "sfdc://discocallback?my_domain=\(encodedDomain)&login_hint=\(encodedHint)"
        let callbackURL = try XCTUnwrap(URL(string: callbackURLString))
        let action = MockNavigationAction(url: callbackURL)

        // When
        let results = coordinator.handle(action: action)

        // Then
        XCTAssertEqual(results?.myDomain, expectedDomain)
        XCTAssertEqual(results?.loginHint, expectedLoginHint)
    }

    func testExtraQueryParameters() async throws {
        // Given
        let coordinator = DomainDiscoveryCoordinator()
        let expectedDomain = "foo.my.salesforce.com"
        let mockDomain = "https://\(expectedDomain)"
        let expectedLoginHint = "testuser@example.com"
        let encodedDomain = try XCTUnwrap(mockDomain.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed))
        let encodedHint = try XCTUnwrap(expectedLoginHint.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed))
        let callbackURLString = "sfdc://discocallback?my_domain=\(encodedDomain)&login_hint=\(encodedHint)&extra=foo&another=bar"
        let callbackURL = try XCTUnwrap(URL(string: callbackURLString))
        let action = MockNavigationAction(url: callbackURL)

        // When
        let results = try XCTUnwrap(coordinator.handle(action: action))

        // Then
        XCTAssertEqual(results.myDomain, expectedDomain)
        XCTAssertEqual(results.loginHint, expectedLoginHint)
    }

}
