//
//  NativeLoginSettings.swift
//  AuthFlowTester
//
//  Copyright (c) 2025-present, salesforce.com, inc. All rights reserved.
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
//

import Foundation
import UIKit
import SalesforceSDKCore

/// How the app authenticates users. Chosen once per launch (see `NativeLoginSettings.activeMode`).
enum AuthenticationMode: String, CaseIterable, Identifiable {
    case browser
    case native

    var id: String { rawValue }
    var title: String { self == .browser ? "Browser" : "Native" }
}

/// Native Login client settings. The JSON keys match the import dialogs on iOS and Android.
struct NativeLoginConfig: Codable, Equatable {
    var clientId: String = ""
    var callbackUrl: String = ""
    var communityUrl: String = ""
    var useDPoP: Bool = false
    var useHybridFlow: Bool = true

    enum JSONKeys {
        static let consumerKey = "consumerKey"
        static let redirectUri = "redirectUri"
        static let communityUrl = "communityUrl"
        static let useDPoP = "useDPoP"
        static let useHybridFlow = "useHybridFlow"
    }

    /// Applies the keys present in `json`; returns false when it isn't a JSON object.
    mutating func apply(json: String) -> Bool {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }
        if let value = object[JSONKeys.consumerKey] as? String { clientId = value }
        if let value = object[JSONKeys.redirectUri] as? String { callbackUrl = value }
        if let value = object[JSONKeys.communityUrl] as? String { communityUrl = value }
        if let value = object[JSONKeys.useDPoP] as? Bool { useDPoP = value }
        if let value = object[JSONKeys.useHybridFlow] as? Bool { useHybridFlow = value }
        return true
    }
}

/// App-owned Native Login state. Native and browser settings are stored separately: browser state
/// stays in the SDK, native state lives in its own `UserDefaults` suite.
///
/// The SDK can enable Native Login but cannot disable it in-process, so the mode is fixed for the
/// life of a launch: `--authenticationMode=native|browser` (DEBUG) or the mode saved by the options
/// sheet. Changing the mode in the sheet takes effect on the next launch.
final class NativeLoginSettings: ObservableObject {
    static let shared = NativeLoginSettings()
    static let launchArgumentPrefix = "--authenticationMode="

    private static let suiteName = "AuthFlowTester.nativeLogin"
    private static let savedModeKey = "savedMode"
    private static let configKey = "config"
    private static let defaultCommunityUrl = "https://login.salesforce.com"

    private let defaults: UserDefaults

    /// Mode in effect for this launch.
    let activeMode: AuthenticationMode

    /// Mode that will be in effect on the next launch.
    @Published var savedMode: AuthenticationMode {
        didSet { defaults.set(savedMode.rawValue, forKey: Self.savedModeKey) }
    }

    @Published private(set) var config: NativeLoginConfig

    /// Scene-owned view controllers registered with the SDK, so a settings change can re-register.
    private var registrations: [String: (scene: UIScene, controller: NativeLoginViewController)] = [:]

    var relaunchRequired: Bool { savedMode != activeMode }

    private init() {
        let defaults = UserDefaults(suiteName: Self.suiteName) ?? .standard
        self.defaults = defaults
        #if DEBUG
        if CommandLine.arguments.contains("--resetSDKForUITesting") {
            defaults.removePersistentDomain(forName: Self.suiteName)
        }
        #endif
        let saved = defaults.string(forKey: Self.savedModeKey).flatMap(AuthenticationMode.init(rawValue:)) ?? .browser
        var active = saved
        #if DEBUG
        if let argument = CommandLine.arguments.first(where: { $0.hasPrefix(Self.launchArgumentPrefix) }),
           let mode = AuthenticationMode(rawValue: String(argument.dropFirst(Self.launchArgumentPrefix.count))) {
            active = mode
        }
        #endif
        activeMode = active
        savedMode = active
        if let data = defaults.data(forKey: Self.configKey),
           let stored = try? JSONDecoder().decode(NativeLoginConfig.self, from: data) {
            config = stored
        } else {
            config = NativeLoginConfig(clientId: SalesforceManager.shared.bootConfig?.remoteAccessConsumerKey ?? "",
                                       callbackUrl: SalesforceManager.shared.bootConfig?.oauthRedirectURI ?? "",
                                       communityUrl: Self.defaultCommunityUrl)
        }
        if activeMode == .native {
            SalesforceManager.shared.usesDPoP = config.useDPoP
            SalesforceManager.shared.useHybridAuthentication = config.useHybridFlow
        }
    }

    /// Saves `newConfig`, applies the DPoP and hybrid choices, and re-registers Native Login so the
    /// next attempt uses the new client settings.
    func update(_ newConfig: NativeLoginConfig) {
        let changed = newConfig != config
        config = newConfig
        defaults.set(try? JSONEncoder().encode(newConfig), forKey: Self.configKey)
        SalesforceManager.shared.usesDPoP = newConfig.useDPoP
        SalesforceManager.shared.useHybridAuthentication = newConfig.useHybridFlow
        guard activeMode == .native else { return }
        for registration in registrations.values {
            register(controller: registration.controller, scene: registration.scene)
        }
        if changed { restartAuthentication() }
    }

    /// The SDK captures the native client, login host and DPoP choice in the authentication session it
    /// creates when the login screen is presented, and rejects attempts that no longer match it.
    /// After a change, stop that session and present login again so the new settings take effect.
    private func restartAuthentication() {
        let scenes = registrations.values.map { $0.scene }
        UserAccountManager.shared.stopCurrentAuthentication { _ in
            DispatchQueue.main.async {
                for scene in scenes {
                    AuthHelper.loginIfRequired(scene) { }
                }
                if UserAccountManager.shared.currentUserAccount != nil {
                    UserAccountManager.shared.switchToNewUserAccount { _ in }
                }
            }
        }
    }

    /// Registers the scene's Native Login view controller. Must run before `loginIfRequired(scene)`.
    func applyIfNative(scene: UIScene) {
        guard activeMode == .native else { return }
        let controller = NativeLoginViewController()
        registrations[scene.session.persistentIdentifier] = (scene, controller)
        register(controller: controller, scene: scene)
    }

    func release(scene: UIScene) {
        registrations.removeValue(forKey: scene.session.persistentIdentifier)
    }

    private func register(controller: NativeLoginViewController, scene: UIScene) {
        _ = SalesforceManager.shared.useNativeLogin(withConsumerKey: config.clientId,
                                                    callbackUrl: config.callbackUrl,
                                                    communityUrl: config.communityUrl,
                                                    nativeLoginViewController: controller,
                                                    scene: scene)
    }
}
