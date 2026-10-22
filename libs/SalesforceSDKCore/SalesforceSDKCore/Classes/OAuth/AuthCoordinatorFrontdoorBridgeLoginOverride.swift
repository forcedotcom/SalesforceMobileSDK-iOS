/*
 Copyright (c) 2025-present, salesforce.com, inc. All rights reserved.
 
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

import Foundation

@objc(SFSDKAuthCoordinatorFrontdoorBridgeLoginOverride)
public class AuthCoordinatorFrontdoorBridgeLoginOverride: NSObject {
    
    /**
     A Salesforce Identity UI Bridge URL on a My Domain or explicitly configured
     login host that replaces the initial login URL. Invalid values read as nil.
     */
    @objc public var frontdoorBridgeUrl: URL? {
        get { validatedSnapshot?.url }
        set {
            stateLock.lock()
            suppliedURL = newValue
            stateLock.unlock()
        }
    }
    
    /**
     The optional web server flow code verifier accompanying the bridge URL.
     Available only when the bridge URL is valid.
     */
    @objc public var codeVerifier: String? {
        get { validatedSnapshot?.codeVerifier }
        set {
            stateLock.lock()
            suppliedCodeVerifier = newValue
            stateLock.unlock()
        }
    }
    
    /**
     Whether the initial bridge URL's consumer key matches the boot config.
     This public identifier check does not establish trust in the URL.
     */
    @objc public var matchesConsumerKey: Bool = false

    private var suppliedURL: URL?
    private var suppliedCodeVerifier: String?
    private let stateLock = NSLock()

    @objc var validatedSnapshot: FrontdoorBridgeLoginSnapshot? {
        stateLock.lock()
        let url = suppliedURL
        let codeVerifier = suppliedCodeVerifier
        stateLock.unlock()

        guard let url, isValidURL(url) else { return nil }
        return FrontdoorBridgeLoginSnapshot(url: url, codeVerifier: codeVerifier)
    }

    /*
     Validate on use because the public properties remain writable for API
     compatibility. A public consumer key identifies an app, not a trusted host.
     */
    @objc var isValid: Bool {
        validatedSnapshot != nil
    }

    private func isValidURL(_ url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.isHTTPS,
              let host = components.host?.lowercased(),
              components.user == nil, components.password == nil,
              components.port == nil || components.port == 443,
              components.fragment == nil,
              isTrustedHost(host),
              isEndpointPath(components.percentEncodedPath, endpoint: "/secur/frontdoor.jsp"),
              let startURL = startURLComponents(in: url),
              startURL.fragment == nil,
              isEndpointPath(startURL.percentEncodedPath, endpoint: "/services/oauth2/authorize"),
              let clientID = consumerKey(in: startURL),
              let appConsumerKey = SalesforceManager.shared.bootConfig?.remoteAccessConsumerKey,
              !appConsumerKey.isEmpty, clientID == appConsumerKey else {
            return false
        }

        /*
         UI Bridge uses relative start URLs. Also accept an absolute authorize
         URL on the same origin for existing programmatic integrations.
         */
        if startURL.scheme != nil || startURL.host != nil {
            return startURL.isHTTPS
                && startURL.host?.lowercased() == host
                && startURL.user == nil && startURL.password == nil
                && (startURL.port ?? 443) == (components.port ?? 443)
        }
        return !startURL.percentEncodedPath.hasPrefix("//")
    }

    private func isTrustedHost(_ host: String) -> Bool {
        if SFSDKAuthConfigUtil.isMyDomainHost(host) {
            return true
        }
        if isConfiguredHost(UserAccountManager.shared.loginHost, matching: host) {
            return true
        }
        let storage = SFSDKLoginHostStorage.sharedInstance()
        return (0..<storage.numberOfLoginHosts()).contains {
            isConfiguredHost(storage.loginHost(at: $0).host, matching: host)
        }
    }

    private func isConfiguredHost(_ address: String, matching host: String) -> Bool {
        let urlString = address.contains("://")
            ? address : "\(NSURLProtectionSpaceHTTPS)://\(address)"
        guard let components = URLComponents(string: urlString),
              components.isHTTPS,
              components.user == nil, components.password == nil,
              components.port == nil || components.port == 443,
              components.query == nil, components.fragment == nil else {
            return false
        }
        return components.host?.lowercased() == host
    }

    private func isEndpointPath(_ path: String, endpoint: String) -> Bool {
        let absolutePath = path.hasPrefix("/") ? path : "/" + path
        let segments = absolutePath.split(separator: "/", omittingEmptySubsequences: false)
        return absolutePath.hasSuffix(endpoint)
            && !absolutePath.contains("%") && !absolutePath.contains("\\")
            && !absolutePath.contains("//")
            && !segments.contains(".") && !segments.contains("..")
    }

    private func startURLComponents(in url: URL) -> URLComponents? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = components.queryItems?.filter({ $0.name == "startURL" }),
              items.count == 1, let value = items.first?.value,
              !value.isEmpty else { return nil }
        return URLComponents(string: value)
    }

    private func consumerKey(in components: URLComponents) -> String? {
        let items = components.queryItems?.filter { $0.name == "client_id" }
        guard items?.count == 1, let value = items?.first?.value,
              !value.isEmpty else { return nil }
        return value
    }

    @objc public init(frontdoorBridgeUrl: URL, codeVerifier: String?) {
        super.init()
        
        suppliedURL = frontdoorBridgeUrl
        suppliedCodeVerifier = codeVerifier
        if let startURL = startURLComponents(in: frontdoorBridgeUrl),
           let clientID = consumerKey(in: startURL),
           let appConsumerKey = SalesforceManager.shared.bootConfig?.remoteAccessConsumerKey {
            matchesConsumerKey = !appConsumerKey.isEmpty && clientID == appConsumerKey
        }
    }
}

@objc(SFSDKFrontdoorBridgeLoginSnapshot)
final class FrontdoorBridgeLoginSnapshot: NSObject {
    @objc let url: URL
    @objc let codeVerifier: String?

    init(url: URL, codeVerifier: String?) {
        self.url = url
        self.codeVerifier = codeVerifier
        super.init()
    }
}

@objc(SFSDKFrontdoorBridgeLoginAttempt)
final class FrontdoorBridgeLoginAttempt: NSObject {
    private let stateLock = NSLock()
    private var rejected = false

    @objc var isRejected: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return rejected
    }

    @objc func reject() {
        stateLock.lock()
        rejected = true
        stateLock.unlock()
    }
}

private extension URLComponents {
    var isHTTPS: Bool {
        scheme?.caseInsensitiveCompare(NSURLProtectionSpaceHTTPS) == .orderedSame
    }
}
