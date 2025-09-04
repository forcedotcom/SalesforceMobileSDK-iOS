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
    
    /// For Salesforce Identity UI Bridge API support, an overriding front door bridge URL to use in place of the default initial URL.
    @objc public var frontdoorBridgeUrl: URL?
    
    /// For Salesforce Identity UI Bridge API support, the optional web server flow code verifier accompanying the front door bridge URL.  This can only be used with `overrideWithfrontDoorBridgeUrl`.
    @objc public var codeVerifier: String?
    
    /// For Salesforce Identity UI Bridge API support, indicates if the overriding front door bridge URL has a consumer key value that matches the app config, which is also known as the boot config.
    @objc public var matchesConsumerKey: Bool = false
    
    /// For Salesforce Identity UI Bridge API support, indicates if the overriding front door bridge URL has a host that matches the app's selected login host.
    @objc public var matchesLoginHost: Bool = false
    
    @objc public init(frontdoorBridgeUrl: URL, codeVerifier: String?) {
        super.init()
        
        guard let frontdoorBridgeUrlComponents = URLComponents(url: frontdoorBridgeUrl, resolvingAgainstBaseURL: true),
              let frontdoorBridgeUrlQueryItems = frontdoorBridgeUrlComponents.queryItems else {
            return
        }
        
        // Extract startURL from query parameters
        guard let startUrlQueryItem = frontdoorBridgeUrlQueryItems.first(where: { $0.name == "startURL" }),
              let startUrlString = startUrlQueryItem.value,
              let startUrl = URL(string: startUrlString) else {
            return
        }
        
        // Parse the startURL to get client_id
        guard let startUrlComponents = URLComponents(url: startUrl, resolvingAgainstBaseURL: true),
              let startUrlQueryItems = startUrlComponents.queryItems else {
            return
        }
        
        // Extract client_id from startURL query parameters
        guard let clientIdQueryItem = startUrlQueryItems.first(where: { $0.name == "client_id" }),
              let frontdoorBridgeUrlClientId = clientIdQueryItem.value else {
            return
        }
        
        // Check if the client_id matches the app's consumer key
        guard let appConsumerKey = SalesforceManager.shared.bootConfig?.remoteAccessConsumerKey else {
            return
        }
        self.matchesConsumerKey = frontdoorBridgeUrlClientId == appConsumerKey
        
        // Check if the front door URL host matches the app's selected login host
        var appLoginHost = appLoginHostForFrontdoorBridgeUrl(frontdoorBridgeUrl)
        if (appLoginHost == nil && addingAndSwitchingLoginHostsAllowed) {
            appLoginHost = frontdoorBridgeUrl.host()
        }
        if let appLoginHost = appLoginHost {
            self.matchesLoginHost = true
            UserAccountManager.shared.loginHost = appLoginHost
        }
        
        // Only set the properties if the front door URL host and the start URL consumer key match the app's current values.
        if self.matchesLoginHost && self.matchesConsumerKey {
            self.codeVerifier = codeVerifier
            self.frontdoorBridgeUrl = frontdoorBridgeUrl
        }
    }
    
    private var addingAndSwitchingLoginHostsAllowed: Bool {
        !SFManagedPreferences.shared().onlyShowAuthorizedHosts && SFManagedPreferences.shared().loginHosts.count == 0
    }
    
    private var loginHostStorage: SFSDKLoginHostStorage {
        SFSDKLoginHostStorage.sharedInstance()
    }
    
    private func appLoginHostForFrontdoorBridgeUrl(_ frontdoorBridgeUrl: URL) -> String? {
        guard let frontdoorBridgeUrlHost = frontdoorBridgeUrl.host() else {
            return nil
        }
        
        let frontdoorBridgeUrlIsMyDomain = frontdoorBridgeUrlHost.contains(".my.")
        
        var eligibleAppLoginHosts : [String] = []
        if (addingAndSwitchingLoginHostsAllowed) {
            for i in 0..<loginHostStorage.numberOfLoginHosts() {
                eligibleAppLoginHosts.append(loginHostStorage.loginHost(at: i).host)
            }
        }
        else {
            eligibleAppLoginHosts = [UserAccountManager.shared.loginHost]
        }
        
        if (frontdoorBridgeUrlIsMyDomain) {
            guard let startIndex = frontdoorBridgeUrlHost.range(of: ".my.")?.upperBound else { return nil }
            let frontdoorBridgeUrlMyDomainSuffix = frontdoorBridgeUrlHost.suffix(from: startIndex)
            
            for eligibleAppLoginHost in eligibleAppLoginHosts {
                if (eligibleAppLoginHost.hasSuffix(frontdoorBridgeUrlMyDomainSuffix)) {
                    return eligibleAppLoginHost
                }
            }
        }
        
        else {
            
            for eligibleAppLoginHost in eligibleAppLoginHosts {
                if (frontdoorBridgeUrlHost == eligibleAppLoginHost) {
                    return eligibleAppLoginHost
                }
            }
        }
        
        return nil
    }
}
