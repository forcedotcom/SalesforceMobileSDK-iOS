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

public struct FrontdoorBridgeUrlAppLoginHostMatch {
    
    let frontdoorBridgeUrl: URL
    let loginHostStore: SFSDKLoginHostStoring
    let addingAndSwitchingLoginHostsAllowed: Bool
    let selectedAppLoginHost: String
    
    internal lazy var appLoginHostMatch: String? = {
        return appLoginHostForFrontdoorBridgeUrl(
            frontdoorBridgeUrl,
            loginHostStore: loginHostStore,
            addingAndSwitchingLoginHostsAllowed: addingAndSwitchingLoginHostsAllowed,
            selectedAppLoginHost: selectedAppLoginHost)
    }()
    
    private func appLoginHostForFrontdoorBridgeUrl(
        _ frontdoorBridgeUrl: URL,
        loginHostStore: SFSDKLoginHostStoring,
        addingAndSwitchingLoginHostsAllowed: Bool,
        selectedAppLoginHost: String
    ) -> String?
    {
        guard let frontdoorBridgeUrlHost = frontdoorBridgeUrl.host() else {
            return nil
        }
        
        let frontdoorBridgeUrlIsMyDomain = frontdoorBridgeUrlHost.contains(".my.")
        
        let eligibleAppLoginHosts = eligibleAppLoginHostsForFrontdoorBridgeUrl(
            loginHostStore: loginHostStore,
            addingAndSwitchingLoginHostsAllowed: addingAndSwitchingLoginHostsAllowed,
            selectedAppLoginHost: selectedAppLoginHost
        )
        
        if (frontdoorBridgeUrlIsMyDomain) {
            guard let startIndex = frontdoorBridgeUrlHost.range(of: ".my.")?.upperBound else { return nil }
            let frontdoorBridgeUrlMyDomainSuffix = frontdoorBridgeUrlHost.suffix(from: startIndex)
            if (frontdoorBridgeUrlMyDomainSuffix.isEmpty) {
                return nil
            }
            
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
    
    private func eligibleAppLoginHostsForFrontdoorBridgeUrl(
        loginHostStore: SFSDKLoginHostStoring,
        addingAndSwitchingLoginHostsAllowed: Bool,
        selectedAppLoginHost: String
    ) -> [String] {
        var results : [String] = []
        if (addingAndSwitchingLoginHostsAllowed) {
            for i in 0..<loginHostStore.numberOfLoginHosts() {
                results.append(loginHostStore.loginHost(at: i).host)
            }
        }
        else {
            results = [selectedAppLoginHost]
        }
        
        return results
    }
}
