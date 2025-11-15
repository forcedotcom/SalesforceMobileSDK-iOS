/*
 BootConfigPickerViewController.swift
 SalesforceSDKCore

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

import SwiftUI
import UIKit

public struct BootConfigPickerView: View {
    @State internal var staticConsumerKey = ""
    @State internal var staticCallbackUrl = ""
    @State internal var staticScopes = ""
    @State internal var dynamicConsumerKey = ""
    @State internal var dynamicCallbackUrl = ""
    @State internal var dynamicScopes = ""
    @Environment(\.dismiss) private var dismiss
    
    let onConfigurationCompleted: () -> Void
    
    public init(onConfigurationCompleted: @escaping () -> Void) {
        self.onConfigurationCompleted = onConfigurationCompleted
    }
    
    // Internal initializer for testing with pre-set state values
    internal init(
        onConfigurationCompleted: @escaping () -> Void,
        staticConsumerKey: String = "",
        staticCallbackUrl: String = "",
        staticScopes: String = "",
        dynamicConsumerKey: String = "",
        dynamicCallbackUrl: String = "",
        dynamicScopes: String = ""
    ) {
        self.onConfigurationCompleted = onConfigurationCompleted
        self._staticConsumerKey = State(initialValue: staticConsumerKey)
        self._staticCallbackUrl = State(initialValue: staticCallbackUrl)
        self._staticScopes = State(initialValue: staticScopes)
        self._dynamicConsumerKey = State(initialValue: dynamicConsumerKey)
        self._dynamicCallbackUrl = State(initialValue: dynamicCallbackUrl)
        self._dynamicScopes = State(initialValue: dynamicScopes)
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Custom title bar with close button
            TitleBarView(title: "Login Options", onDismiss: {
                dismiss()
            })
            
            // Content
            ScrollView {
                    VStack(spacing: 30) {
                        // Flow types section
                        AuthFlowTypesView()
                            .padding(.top, 20)
                        
                        Divider()
                        
                        // Static config section
                        BootConfigEditor(
                            title: "Static Configuration",
                            buttonLabel: "Use static config",
                            buttonColor: .blue,
                            consumerKey: $staticConsumerKey,
                            callbackUrl: $staticCallbackUrl,
                            scopes: $staticScopes,
                            isLoading: false,
                            onUseConfig: handleStaticConfig,
                            initiallyExpanded: false
                        )
                        
                        Divider()
                        
                        // Dynamic config section
                        BootConfigEditor(
                            title: "Dynamic Configuration",
                            buttonLabel: "Use dynamic config",
                            buttonColor: .green,
                            consumerKey: $dynamicConsumerKey,
                            callbackUrl: $dynamicCallbackUrl,
                            scopes: $dynamicScopes,
                            isLoading: false,
                            onUseConfig: handleDynamicBootconfig,
                            initiallyExpanded: false
                        )
                    }
                    .padding(.bottom, 40)
                }
                .background(Color(.systemBackground))
            }
        .onAppear {
            loadConfigDefaults()
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadConfigDefaults() {
        // Load static config from bootconfig.plist (via SalesforceManager)
        if let config = SalesforceManager.shared.bootConfig {
            staticConsumerKey = config.remoteAccessConsumerKey
            staticCallbackUrl = config.oauthRedirectURI
            staticScopes = config.oauthScopes.sorted().joined(separator: " ")
        }
        
        // Load dynamic config defaults from bootconfig2.plist
        if let config = BootConfig("/bootconfig2.plist") {
            dynamicConsumerKey = config.remoteAccessConsumerKey
            dynamicCallbackUrl = config.oauthRedirectURI
            dynamicScopes = config.oauthScopes.sorted().joined(separator: " ")
        }
    }
    
    // MARK: - Button Actions
    
    internal func handleStaticConfig() {
        // Parse scopes from space-separated string
        let scopesArray = staticScopes
            .split(separator: " ")
            .map { String($0) }
            .filter { !$0.isEmpty }
        
        // Create BootConfig with values from the editor
        var configDict: [String: Any] = [
            "remoteAccessConsumerKey": staticConsumerKey,
            "oauthRedirectURI": staticCallbackUrl,
            "shouldAuthenticate": true
        ]
        
        // Only add scopes if not empty
        if !scopesArray.isEmpty {
            configDict["oauthScopes"] = scopesArray
        }
        
        // Set as the bootConfig
        SalesforceManager.shared.bootConfig = BootConfig(configDict)
        SalesforceManager.shared.bootConfigRuntimeSelector = nil
        
        // Update UserAccountManager properties
        UserAccountManager.shared.oauthClientID = staticConsumerKey
        UserAccountManager.shared.oauthCompletionURL = staticCallbackUrl
        UserAccountManager.shared.scopes = scopesArray.isEmpty ? [] : Set(scopesArray)
        
        // Proceed with login
        onConfigurationCompleted()
    }
    
    internal func handleDynamicBootconfig() {
        SalesforceManager.shared.bootConfigRuntimeSelector = { _, callback in
            // Create dynamic BootConfig from user-entered values
            // Parse scopes from space-separated string
            let scopesArray = self.dynamicScopes
                .split(separator: " ")
                .map { String($0) }
                .filter { !$0.isEmpty }
            
            var configDict: [String: Any] = [
                "remoteAccessConsumerKey": self.dynamicConsumerKey,
                "oauthRedirectURI": self.dynamicCallbackUrl,
                "shouldAuthenticate": true
            ]
            
            // Only add scopes if not empty
            if !scopesArray.isEmpty {
                configDict["oauthScopes"] = scopesArray
            }
            
            callback(BootConfig(configDict))
        }
        
        // Proceed with login
        onConfigurationCompleted()
    }
}

// MARK: - Title Bar View

struct TitleBarView: View {
    let title: String
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            Color(UIColor.salesforceBlue)
            
            HStack {
                Spacer()
                
                Text(title)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            HStack {
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .padding(12)
                }
            }
        }
        .frame(height: 44)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Objective-C Bridge

@objc public class BootConfigPickerViewController: NSObject {
    
    @objc public static func makeViewController(onConfigurationCompleted: @escaping () -> Void) -> UIViewController {
        let view = BootConfigPickerView(onConfigurationCompleted: onConfigurationCompleted)
        let hostingController = UIHostingController(rootView: view)
        
        // Use pageSheet for slide-up presentation
        #if !os(visionOS)
        if let sheet = hostingController.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 16
        }
        #endif
        
        return hostingController
    }
}

