import Foundation
import WebKit

enum DomainDiscovery: String {
    /// The callback URL used for domain discovery.
    case callbackURL = "sfdc://discocallback"
    
    enum URLComponent: String {
        case path = "/discovery"
        case scheme = "https"
        
        enum QueryItem: String {
            case clientID = "client_id"
            case clientVersion = "client_version"
            case callbackURL = "callback_url"
        }
    }
}

/// Represents the result of a domain discovery operation.
@objc(SFDomainDiscoveryResult)
public class DomainDiscoveryResult: NSObject {
    /// The login hint returned from domain discovery.
    @objc public let loginHint: String
    /// The discovered My Domain value.
    @objc public let myDomain: String
    
    init(loginHint: String, myDomain: String) {
        self.loginHint = loginHint
        self.myDomain = myDomain
    }
}

/// Coordinator for My Domain discovery via WKWebView before OAuth login.
///
/// This class loads a discovery URL in a WKWebView and waits for a callback URL to be hit, returning the discovered domain and login hint.
@objc(SFDomainDiscoveryCoordinator)
public class DomainDiscoveryCoordinator: NSObject {
    /// Starts the domain discovery process by loading the discovery URL in the provided WKWebView.
    ///
    /// - Parameters:
    ///   - webview: The WKWebView in which to load the discovery URL for domain discovery.
    ///   - credentials: The OAuth credentials containing clientId and domain.
    ///
    /// This method loads the discovery URL in the given webview. The result of the discovery should be handled by monitoring navigation actions and calling `handle(webAction:)`.
    @MainActor
    @objc public func runMyDomainsDiscovery(on webview: WKWebView,
                                      with credentials: OAuthCredentials) {
        guard let clientId = credentials.clientId,
              let clientVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
              let domain = credentials.domain else {
            SFSDKCoreLogger.e(classForCoder, message: "Missing required credentials")
            return
        }
        guard let url = Self.buildDiscoveryURL(clientId: clientId, clientVersion: clientVersion, domain: domain) as URL? else {
            SFSDKCoreLogger.e(classForCoder, message: "Failed to construct discovery URL")
            return
        }
        webview.load(URLRequest(url: url))
    }
    
    /// Handles a navigation action and checks if it matches the domain discovery callback URL.
    ///
    /// - Parameter action: The action to inspect.
    /// - Returns: A `DomainDiscoveryResult` if the callback URL is detected and parsed; otherwise, `nil`.
    ///
    /// Call this from your WKNavigationDelegate when a navigation action occurs to detect and extract the result from the domain discovery callback URL.
    @objc(handleWithWebAction:)
    public func handle(action: WKNavigationAction) -> DomainDiscoveryResult? {
        guard let url = action.request.url else {
            return nil
        }
        if isDomainDiscoveryCallbackURL(url) {
            let result = parseDiscoveryCallbackURL(url)
            return result
        }
        return nil
    }
    
    @objc
    @available(*, deprecated, renamed: "isDiscoveryDomain(domain:)")
    public func isDiscoveryDomain(_ domain: String?, clientId: String?) -> Bool {
       return isDiscoveryDomain(domain)
    }
    
    @objc
    public func isDiscoveryDomain(_ domain: String?) -> Bool {
        guard let domain = domain else { return false }
        let isDiscovery = domain.lowercased().contains(DomainDiscovery.URLComponent.path.rawValue)
        return isDiscovery
    }
}

extension DomainDiscoveryCoordinator {
    private static func buildDiscoveryURL(clientId: String, clientVersion: String, domain: String, callbackURL: String = DomainDiscovery.callbackURL.rawValue) -> NSURL? {
        var components = URLComponents()
        components.scheme = DomainDiscovery.URLComponent.scheme.rawValue
        components.host = domain.components(separatedBy: "/").first
        components.path = DomainDiscovery.URLComponent.path.rawValue
        components.queryItems = [
            URLQueryItem(name: DomainDiscovery.URLComponent.QueryItem.clientID.rawValue, value: clientId),
            URLQueryItem(name: DomainDiscovery.URLComponent.QueryItem.clientVersion.rawValue, value: clientVersion),
            URLQueryItem(name: DomainDiscovery.URLComponent.QueryItem.callbackURL.rawValue, value: callbackURL)
        ]
        return components.url as NSURL?
    }
    
    private func isDomainDiscoveryCallbackURL(_ url: URL?) -> Bool {
        guard let url = url as URL? else { return false }
        return url.absoluteString.lowercased().hasPrefix(DomainDiscovery.callbackURL.rawValue.lowercased())
    }
    
    private func parseDiscoveryCallbackURL(_ url: URL?) -> DomainDiscoveryResult? {
        guard let url = url else { return nil }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        guard let loginHint = components?.queryItems?.first(where: { $0.name == "login_hint" })?.value,
              let myDomainRaw = components?.queryItems?.first(where: { $0.name == "my_domain" })?.value else {
            SFSDKCoreLogger.e(classForCoder, message: "Domain discovery callback URL is missing required parameter(s): login_hint and/or my_domain.")
            return nil
        }
        let myDomain = myDomainRaw.hasPrefix("https://") ? String(myDomainRaw.dropFirst("https://".count)) : myDomainRaw
        return DomainDiscoveryResult(loginHint: loginHint, myDomain: myDomain)
    }
}
