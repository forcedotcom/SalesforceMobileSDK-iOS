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

@objc(SFSDKWebViewStateManager)
public class WebViewStateManager: NSObject {
    private static var processPool: WKProcessPool?
    private static var sessionCookieManagementDisabled = false

    @objc
    @MainActor
    public static func removeSession() {
        sharedProcessPool = nil

        if sessionCookieManagementDisabled {
            SFSDKCoreLogger.d(WebViewStateManager.self, message: "[\(Self.self) removeSession]: Cookie Management disabled. Will do nothing.")
            return
        }
        
        // Perform async cleanup without blocking the current thread
        Task {
            await removeWKWebViewCookies()
        }
    }

    @objc
    @MainActor
    public static func removeSessionForcefully() async {
        sharedProcessPool = nil
        await removeWKWebViewCookies()
    }

    @objc
    public static func resetSessionCookie() async {
        if sessionCookieManagementDisabled {
            SFSDKCoreLogger.d(WebViewStateManager.self, message: "[\(Self.self) resetSessionCookie]: Cookie Management disabled. Will do nothing.")
            return
        }
        await removeWKWebViewCookies()
    }

    @MainActor
    private static func removeWKWebViewCookies() async {
        await withCheckedContinuation { continuation in
            let dataStore = WKWebsiteDataStore.default()
            let websiteDataTypes: Set<String> = [WKWebsiteDataTypeCookies]
            dataStore.removeData(ofTypes: websiteDataTypes, modifiedSince: Date.distantPast) {
                continuation.resume()
            }
        }
        
    }

    @objc
    @MainActor
    public static var sharedProcessPool: WKProcessPool? {
        get {
            if processPool == nil {
                SFSDKCoreLogger.i(WebViewStateManager.self, message: "[\(Self.self) sharedProcessPool]: No process pool exists. Creating new instance.")
                processPool = WKProcessPool()
            }
            return processPool
        }
        set {
            if newValue !== processPool {
                SFSDKCoreLogger.i(WebViewStateManager.self, message: "[\(Self.self) setSharedProcessPool]: Changing from \(String(describing: processPool)) to \(String(describing: newValue))")
                processPool = newValue
            }
        }
    }

    @objc
    public static func setSessionCookieManagementDisabled(_ disabled: Bool) {
        sessionCookieManagementDisabled = disabled
    }

    @objc
    public static func isSessionCookieManagementDisabled() -> Bool {
        return sessionCookieManagementDisabled
    }
}
