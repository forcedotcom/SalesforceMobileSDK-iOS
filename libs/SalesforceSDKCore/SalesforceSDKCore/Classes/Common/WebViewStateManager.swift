//  Copyright (c) 2020-present, salesforce.com, inc. All rights reserved.
//
//  Redistribution and use of this software in source and binary forms, with or without modification,
//  are permitted provided that the following conditions are met:
//  * Redistributions of source code must retain the above copyright notice, this list of conditions
//  and the following disclaimer.
//  * Redistributions in binary form must reproduce the above copyright notice, this list of
//  conditions and the following disclaimer in the documentation and/or other materials provided
//  with the distribution.
//  * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
//  endorse or promote products derived from this software without specific prior written
//  permission of salesforce.com, inc.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
//  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
//  FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
//  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
//  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
//  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
//  WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import Foundation
import WebKit

public class SFSDKWebViewStateManager: NSObject {
    private static var managementDisabled = false
    
    @objc
    public static var sessionCookieManagementDisabled: Bool {
        get {
            return managementDisabled
        }
        set {
            managementDisabled = newValue
        }
    }

    @objc
    @MainActor
    @available(*, deprecated, renamed: "resetSessionCookie", message: "Deprecated in Salesforce Mobile SDK 13.2 and will be removed in Salesforce Mobile SDK 14.0. Use resetSessionCookie instead.")
    public static func removeSession() {
        if sessionCookieManagementDisabled {
            SFSDKCoreLogger.d(SFSDKWebViewStateManager.self, message: "[\(Self.self) removeSession]: Cookie Management disabled. Will do nothing.")
            return
        }
        
        Task {
            await removeWKWebViewCookies()
        }
    }

    @objc
    @MainActor
    public static func resetSessionCookie() {
        if sessionCookieManagementDisabled {
            SFSDKCoreLogger.d(SFSDKWebViewStateManager.self, message: "[\(Self.self) resetSessionCookie]: Cookie Management disabled. Will do nothing.")
            return
        }
        
        Task {
            await removeWKWebViewCookies()
        }
    }
    
    @objc
    @MainActor
    public static func clearCache() async {
        let dataStore = WKWebsiteDataStore.default()
        let websiteDataTypes: Set<String> = [WKWebsiteDataTypeFetchCache, WKWebsiteDataTypeMemoryCache, WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeOfflineWebApplicationCache]
        await dataStore.removeData(ofTypes: websiteDataTypes, modifiedSince: Date.distantPast)
    }
    
    @objc
    @MainActor
    public static func removeSessionForcefully() async {
        await removeWKWebViewCookies()
    }

    
    @available(*, deprecated, message: "Deprecated in Salesforce Mobile SDK 13.2 and will be removed in Salesforce Mobile SDK 14.0. WKProcessPool creation has no effect on iOS 15+ and this property will be removed.")
    @objc
    @MainActor
    public static var sharedProcessPool: WKProcessPool? {
        get {
            // WKProcessPool creation is deprecated since iOS 15 and has no effect.
            return nil
        }
        set {
            // Do nothing
        }
    }

    @MainActor
    private static func removeWKWebViewCookies() async {
        let dataStore = WKWebsiteDataStore.default()
        let websiteDataTypes: Set<String> = [WKWebsiteDataTypeCookies]
        await dataStore.removeData(ofTypes: websiteDataTypes, modifiedSince: Date.distantPast)
    }    
}
