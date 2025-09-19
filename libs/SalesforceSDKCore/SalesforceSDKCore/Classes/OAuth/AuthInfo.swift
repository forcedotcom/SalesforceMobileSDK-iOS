//
// AuthInfo.swift
// SalesforceSDKCore
//
// Copyright (c) 2012-present, salesforce.com, inc. All rights reserved.
//
// Redistribution and use of this software in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
// * Redistributions of source code must retain the above copyright notice, this list of conditions
//   and the following disclaimer.
// * Redistributions in binary form must reproduce the above copyright notice, this list of
//   conditions and the following disclaimer in the documentation and/or other materials provided
//   with the distribution.
// * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
//   endorse or promote products derived from this software without specific prior written
//   permission of salesforce.com, inc.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
// IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
// FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
// CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
// WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
// WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

import Foundation

@objc(SFOAuthType)
public enum AuthType: Int {
    case unknown = 0
    case userAgent
    case refresh
    case advancedBrowser
    case jwtTokenExchange
    case IDP
    case webServer
    case native

    public var description: String {
        switch self {
        case .userAgent: return "SFOAuthTypeUserAgent"
        case .webServer: return "SFOAuthTypeWebServer"
        case .refresh: return "SFOAuthTypeRefresh"
        case .advancedBrowser: return "SFOAuthTypeAdvancedBrowser"
        case .jwtTokenExchange: return "SFOAuthTypeJwtTokenExchange"
        case .native: return "SFOAuthTypeNative"
        case .IDP: return "SFOAuthTypeIDP"
        case .unknown: fallthrough
        @unknown default: return "SFOAuthTypeUnknown"
        }
    }

    // Static constants for Objective-C bridging
    public static let SFOAuthTypeUnknown = AuthType.unknown
    public static let SFOAuthTypeUserAgent = AuthType.userAgent
    public static let SFOAuthTypeRefresh = AuthType.refresh
    public static let SFOAuthTypeAdvancedBrowser = AuthType.advancedBrowser
    public static let SFOAuthTypeJwtTokenExchange = AuthType.jwtTokenExchange
    public static let SFOAuthTypeIDP = AuthType.IDP
    public static let SFOAuthTypeWebServer = AuthType.webServer
    public static let SFOAuthTypeNative = AuthType.native
}

@objc(SFOAuthInfo)
@objcMembers
public class AuthInfo: NSObject {
    public let authType: AuthType

    public var authTypeDescription: String {
        return authType.description
    }

    // Main Swift initializer
    @objc(initWithAuthType:)
    public init(authType: AuthType) {
        self.authType = authType
        super.init()
    }

    // Default initializer for Swift and Objective-C
    @objc public override init() {
        self.authType = .unknown
        super.init()
    }

    // Objective-C class factory method
    @objc(infoWithAuthType:)
    public class func info(withAuthType authType: AuthType) -> AuthInfo {
        return AuthInfo(authType: authType)
    }

    // Expose the raw value for Objective-C
    @objc public var authTypeRawValue: Int {
        return authType.rawValue
    }

    // Expose the description for Objective-C
    @objc public override var description: String {
        return "<SFOAuthInfo: \(Unmanaged.passUnretained(self).toOpaque()), authType=\(authTypeDescription)>"
    }
}

