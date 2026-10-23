/*
 NativeLoginDebugSettings.swift
 SalesforceSDKCore

 Copyright (c) 2026-present, salesforce.com, inc. All rights reserved.

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
import Combine

/// How the SDK presents login when the debug Login Options select it.
@objc(SFSDKAuthenticationMode)
public enum AuthenticationMode: Int, CaseIterable, Identifiable {
    /// The SDK's web/browser login, configured by the boot config and the browser options.
    case browser
    /// The SDK's debug Native Login form, configured by `NativeLoginDebugConfig`.
    case native

    public var id: Int { rawValue }

    /// The JSON value of the mode: `browser` or `native`.
    public var name: String {
        switch self {
        case .browser: return "browser"
        case .native: return "native"
        }
    }

    /// Parses a JSON value (case-insensitive).
    public init?(name: String) {
        guard let mode = Self.allCases.first(where: { $0.name == name.lowercased() }) else { return nil }
        self = mode
    }
}

/// The External Client App used by the debug Native Login form. Kept apart from the boot config,
/// which the browser login (including the Native Login browser fallback) keeps using.
public struct NativeLoginDebugConfig: Codable, Equatable {
    /// The consumer key of an External Client App enabled for headless login.
    public var consumerKey: String
    /// The callback URL of that app, an HTTPS URL.
    public var redirectUri: String
    /// The Experience Cloud site URL, including its path, used for Native Login.
    public var communityUrl: String
    /// True to bind Native Login sessions with DPoP.
    public var useDPoP: Bool
    /// True to request hybrid tokens from the Native Login token exchange.
    public var useHybridFlow: Bool

    public init(consumerKey: String = "", redirectUri: String = "", communityUrl: String = "",
                useDPoP: Bool = true, useHybridFlow: Bool = true) {
        self.consumerKey = consumerKey
        self.redirectUri = redirectUri
        self.communityUrl = communityUrl
        self.useDPoP = useDPoP
        self.useHybridFlow = useHybridFlow
    }

    /// The first problem with this configuration, or nil when Native Login can use it.
    public var validationError: String? {
        if consumerKey.trimmingCharacters(in: .whitespaces).isEmpty {
            return SFSDKResourceUtils.localizedString("NATIVE_LOGIN_DEBUG_ERROR_CLIENT_ID_REQUIRED")
        }
        if !Self.isHttpsUrl(redirectUri) {
            return SFSDKResourceUtils.localizedString("NATIVE_LOGIN_DEBUG_ERROR_CALLBACK_URL_HTTPS")
        }
        if !Self.isHttpsUrl(communityUrl) {
            return SFSDKResourceUtils.localizedString("NATIVE_LOGIN_DEBUG_ERROR_COMMUNITY_URL_HTTPS")
        }
        return nil
    }

    /// True when Native Login can use this configuration.
    public var isComplete: Bool { validationError == nil }

    private static func isHttpsUrl(_ value: String) -> Bool {
        guard let url = URL(string: value.trimmingCharacters(in: .whitespaces)),
              url.scheme?.lowercased() == "https",
              let host = url.host, !host.isEmpty else {
            return false
        }
        return true
    }
}

/// Errors thrown by `NativeLoginDebugSettings.apply(json:)`.
public enum NativeLoginDebugSettingsError: LocalizedError, Equatable {
    case unavailable
    case malformedJSON
    case wrongType(key: String)
    case unknownAuthenticationMode(String)
    case invalidConfiguration(String)

    public var errorDescription: String? {
        switch self {
        case .unavailable: return SFSDKResourceUtils.localizedString("NATIVE_LOGIN_DEBUG_ERROR_UNAVAILABLE")
        case .malformedJSON: return SFSDKResourceUtils.localizedString("NATIVE_LOGIN_DEBUG_ERROR_MALFORMED_JSON")
        case .wrongType(let key): return String(format: SFSDKResourceUtils.localizedString("NATIVE_LOGIN_DEBUG_ERROR_WRONG_TYPE"), key)
        case .unknownAuthenticationMode(let name): return String(format: SFSDKResourceUtils.localizedString("NATIVE_LOGIN_DEBUG_ERROR_UNKNOWN_MODE"), name)
        case .invalidConfiguration(let message): return message
        }
    }
}

/// Debug-only choice between browser login and the SDK's built-in Native Login form, edited in the
/// Login Options screen and persisted across launches, apart from the browser configuration.
///
/// The settings are inert, and `mode` always reads `.browser`, unless developer support is enabled
/// and the app registered no Native Login view controller of its own (`useNativeLogin`). When
/// Native mode is selected with a complete configuration, the SDK presents its debug Native Login
/// form instead of the browser login. Mode and configuration changes made in Login Options restart
/// authentication when the screen closes.
///
/// The Native Login DPoP and hybrid choices live in `config`; they do not change
/// `SalesforceManager.usesDPoP` or `useHybridAuthentication`, which stay the browser login values.
@objc(SFSDKNativeLoginDebugSettings)
public final class NativeLoginDebugSettings: NSObject, ObservableObject {

    /// JSON keys, shared with Android and with the Login Options import button.
    public enum JSONKeys {
        public static let consumerKey = "consumerKey"
        public static let redirectUri = "redirectUri"
        public static let communityUrl = "communityUrl"
        public static let useDPoP = "useDPoP"
        public static let useHybridFlow = "useHybridFlow"
        public static let authenticationMode = "authenticationMode"
    }

    @objc public static let shared = NativeLoginDebugSettings()

    static let suiteName = "com.salesforce.mobilesdk.nativeLoginDebugSettings"
    private static let modeKey = "mode"
    private static let configKey = "config"

    private let defaults: UserDefaults
    private let isDevSupportEnabled: () -> Bool
    private let isAppNativeLoginRegistered: () -> Bool

    private override convenience init() {
        self.init(defaults: UserDefaults(suiteName: NativeLoginDebugSettings.suiteName) ?? .standard,
                  isDevSupportEnabled: { SalesforceManager.shared.isDevSupportEnabled },
                  isAppNativeLoginRegistered: {
                      // Internal Objective-C property (SalesforceSDKManager+Internal.h), not visible to Swift.
                      (SalesforceManager.shared.value(forKey: "appRegisteredNativeLogin") as? Bool) ?? false
                  })
    }

    internal init(defaults: UserDefaults,
                  isDevSupportEnabled: @escaping () -> Bool,
                  isAppNativeLoginRegistered: @escaping () -> Bool) {
        self.defaults = defaults
        self.isDevSupportEnabled = isDevSupportEnabled
        self.isAppNativeLoginRegistered = isAppNativeLoginRegistered
        super.init()
    }

    /// True when the settings apply: developer support is on and the app has no native login of its own.
    @objc public var isAvailable: Bool {
        isDevSupportEnabled() && !isAppNativeLoginRegistered()
    }

    /// The selected authentication mode. Writes are ignored when the settings are not `isAvailable`.
    @objc public var mode: AuthenticationMode {
        get {
            guard isAvailable else { return .browser }
            return defaults.string(forKey: Self.modeKey).flatMap(AuthenticationMode.init(name:)) ?? .browser
        }
        set {
            guard isAvailable else { return }
            objectWillChange.send()
            defaults.set(newValue.name, forKey: Self.modeKey)
        }
    }

    /// The Native Login External Client App. Writes are ignored when the settings are not `isAvailable`.
    public var config: NativeLoginDebugConfig {
        get {
            guard let data = defaults.data(forKey: Self.configKey),
                  let stored = try? JSONDecoder().decode(NativeLoginDebugConfig.self, from: data) else {
                return NativeLoginDebugConfig()
            }
            return stored
        }
        set {
            guard isAvailable else { return }
            objectWillChange.send()
            var trimmed = newValue
            trimmed.consumerKey = trimmed.consumerKey.trimmingCharacters(in: .whitespaces)
            trimmed.redirectUri = trimmed.redirectUri.trimmingCharacters(in: .whitespaces)
            trimmed.communityUrl = trimmed.communityUrl.trimmingCharacters(in: .whitespaces)
            defaults.set(try? JSONEncoder().encode(trimmed), forKey: Self.configKey)
        }
    }

    /// True when the SDK should present its debug Native Login form: available, Native mode and a
    /// complete configuration.
    @objc public var isNativeLoginActive: Bool {
        mode == .native && config.isComplete
    }

    /// Applies a JSON configuration with the keys `consumerKey`, `redirectUri`, `communityUrl`,
    /// `useDPoP`, `useHybridFlow` and `authenticationMode` (`native` or `browser`). Absent keys keep
    /// their current value. Nothing is saved when the JSON or the resulting Native Login
    /// configuration is invalid.
    ///
    /// Does not restart an authentication already in progress; apply settings before login starts,
    /// or change them in Login Options.
    @objc(applyJSON:error:)
    public func apply(json: String) throws {
        guard isAvailable else { throw NativeLoginDebugSettingsError.unavailable }
        guard let data = json.data(using: .utf8),
              let values = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw NativeLoginDebugSettingsError.malformedJSON
        }
        func string(_ key: String) throws -> String? {
            guard let value = values[key] else { return nil }
            guard let string = value as? String else { throw NativeLoginDebugSettingsError.wrongType(key: key) }
            return string.trimmingCharacters(in: .whitespaces)
        }
        func bool(_ key: String) throws -> Bool? {
            guard let value = values[key] else { return nil }
            // JSONSerialization decodes both booleans and numbers to NSNumber; accept only booleans.
            guard let number = value as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() else {
                throw NativeLoginDebugSettingsError.wrongType(key: key)
            }
            return number.boolValue
        }
        let current = config
        let updated = NativeLoginDebugConfig(
            consumerKey: try string(JSONKeys.consumerKey) ?? current.consumerKey,
            redirectUri: try string(JSONKeys.redirectUri) ?? current.redirectUri,
            communityUrl: try string(JSONKeys.communityUrl) ?? current.communityUrl,
            useDPoP: try bool(JSONKeys.useDPoP) ?? current.useDPoP,
            useHybridFlow: try bool(JSONKeys.useHybridFlow) ?? current.useHybridFlow)
        var updatedMode = mode
        if let name = try string(JSONKeys.authenticationMode) {
            guard let parsed = AuthenticationMode(name: name) else {
                throw NativeLoginDebugSettingsError.unknownAuthenticationMode(name)
            }
            updatedMode = parsed
        }
        if updatedMode == .native, let error = updated.validationError {
            throw NativeLoginDebugSettingsError.invalidConfiguration(error)
        }
        config = updated
        mode = updatedMode
    }

    /// Restores the defaults: browser mode and no Native Login configuration.
    @objc public func reset() {
        objectWillChange.send()
        defaults.removeObject(forKey: Self.modeKey)
        defaults.removeObject(forKey: Self.configKey)
    }

    // MARK: - Objective-C accessors used by the SDK's login routing

    @objc public var nativeConsumerKey: String { config.consumerKey }
    @objc public var nativeRedirectUri: String { config.redirectUri }
    @objc public var nativeCommunityUrl: String { config.communityUrl }
    @objc public var nativeUseDPoP: Bool { config.useDPoP }
    @objc public var nativeUseHybridFlow: Bool { config.useHybridFlow }
}

public extension SalesforceManager {
    /// Debug-only Native Login settings (Login Options Authentication Mode). See `NativeLoginDebugSettings`.
    var debugLoginSettings: NativeLoginDebugSettings { NativeLoginDebugSettings.shared }
}
