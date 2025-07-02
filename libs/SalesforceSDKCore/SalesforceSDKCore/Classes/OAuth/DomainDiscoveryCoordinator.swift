import Foundation
import WebKit

/// Coordinator for My Domain discovery via WebView before OAuth login.
public enum DomainDiscoveryConstants {
    public static let callbackURL = "sfdc://discocallback"
}

@objcMembers
public class DomainDiscoveryCoordinator: NSObject {
    private var webView: WKWebView
    
    @objc(init)
    public convenience override init() {
        let webView = WKWebView()
        self.init(webView: webView)
    }

    public init(webView: WKWebView = WKWebView()) {
        self.webView = webView
        super.init()
        self.webView.navigationDelegate = self
    }

    private var continuation: CheckedContinuation<(String, String), Error>?

    @MainActor
    @objc(runDomainDiscoveryWithCredentials:completion:)
    public func runMyDomainDiscovery(
        credentials: OAuthCredentials
    ) async throws -> (String, String) {
        
        guard webView != nil else {
            throw NSError(domain: "DomainDiscoveryCoordinator", code: 1000, userInfo: [NSLocalizedDescriptionKey: "Missing webView"])
        }
        // 1. Build the discovery URL
        let discoveryHost = credentials.domain ?? "welcome.salesforce.com"
        guard let clientId = credentials.clientId,
              let clientVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            throw NSError(domain: "DomainDiscoveryCoordinator", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Missing required credentials"])
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = discoveryHost
        components.path = ""
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "client_version", value: clientVersion),
            URLQueryItem(name: "callback_url", value: DomainDiscoveryConstants.callbackURL)
        ]
        guard let url = components.url else {
            throw NSError(domain: "DomainDiscoveryCoordinator", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Failed to construct discovery URL"])
        }

        // 2. Load the URL in the webView and wait for callback
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            self.webView.load(URLRequest(url: url))
        }
    }
}

extension DomainDiscoveryCoordinator: WKNavigationDelegate {
    /// Decides whether to allow or cancel a navigation action.
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        defer { decisionHandler(.allow) }
        guard let url = navigationAction.request.url else { return }

        // Use the constant for callback URL matching
        if url.absoluteString.hasPrefix(DomainDiscoveryConstants.callbackURL) {
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let myDomain = components?.queryItems?.first(where: { $0.name == "my_domain" })?.value?.removingPercentEncoding
            let loginHint = components?.queryItems?.first(where: { $0.name == "login_hint" })?.value?.removingPercentEncoding

            if let myDomain, let loginHint, !myDomain.isEmpty, !loginHint.isEmpty {
                continuation?.resume(returning: (myDomain, loginHint))
            } else {
                let error = NSError(domain: "DomainDiscoveryCoordinator", code: 1003, userInfo: [NSLocalizedDescriptionKey: "Missing or malformed parameters in callback"])
                continuation?.resume(throwing: error)
            }
            continuation = nil
        }
    }

    /// Called when navigation starts.
    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        // TODO: Handle navigation start if needed
    }

    /// Called when navigation finishes successfully.
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // TODO: Handle navigation finish if needed
    }

    /// Called when navigation fails.
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        // TODO: Handle navigation failure
    }
}
