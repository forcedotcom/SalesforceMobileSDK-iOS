/*
 SessionDetailViewController.swift
 AuthFlowTester

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
import SalesforceSDKCore

struct SessionDetailView: View {
    @State private var refreshTrigger = UUID()
    @State private var showMigrateRefreshToken = false
    @State private var showLogoutConfigPicker = false
    @State private var isUserCredentialsExpanded = false
    @State private var isJwtDetailsExpanded = false
    @State private var isOAuthConfigExpanded = false
    @State private var migrateConsumerKey = ""
    @State private var migrateCallbackUrl = ""
    @State private var migrateScopes = ""
    @State private var isMigrating = false
    @State private var migrationError: String?
    @State private var showMigrationError = false
    
    var onChangeConsumerKey: () -> Void
    var onSwitchUser: () -> Void
    var onLogout: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Revoke Access Token Section
                RevokeView(onRevokeCompleted: {
                    refreshTrigger = UUID()
                })
                
                // REST API Request Section
                RestApiTestView(onRequestCompleted: {
                    refreshTrigger = UUID()
                })
                
                // User Credentials Section
                UserCredentialsView(isExpanded: $isUserCredentialsExpanded)
                    .id(refreshTrigger)
                
                // JWT Access Token Details Section (if applicable)
                if let credentials = UserAccountManager.shared.currentUserAccount?.credentials,
                   credentials.tokenFormat?.lowercased() == "jwt",
                   let accessToken = credentials.accessToken,
                   let jwtToken = try? JwtAccessToken(jwt: accessToken) {
                    JwtAccessView(jwtToken: jwtToken, isExpanded: $isJwtDetailsExpanded)
                        .id(refreshTrigger)
                }

                // OAuth Configuration Section
                OAuthConfigurationView(isExpanded: $isOAuthConfigExpanded)
                    .id(refreshTrigger)
                                
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .navigationTitle("AuthFlowTester")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button(action: {
                    loadCurrentCredentials()
                    showMigrateRefreshToken = true
                }) {
                    Label("Change Key", systemImage: "key.horizontal.fill")
                }
                
                Spacer()
                
                Button(action: {
                    onSwitchUser()
                }) {
                    Label("Switch User", systemImage: "person.2.fill")
                }
                
                Spacer()
                
                Button(action: {
                    showLogoutConfigPicker = true
                }) {
                    Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        }
        .sheet(isPresented: $showLogoutConfigPicker) {
            NavigationView {
                ConfigPickerView(onConfigurationCompleted: {
                    showLogoutConfigPicker = false
                    onLogout()
                })
                .navigationTitle("Select Config for Re-login")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showLogoutConfigPicker = false
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showMigrateRefreshToken) {
            NavigationView {
                VStack {
                    BootConfigEditor(
                        title: "New App Configuration",
                        buttonLabel: "Migrate refresh token",
                        buttonColor: .blue,
                        consumerKey: $migrateConsumerKey,
                        callbackUrl: $migrateCallbackUrl,
                        scopes: $migrateScopes,
                        isLoading: isMigrating,
                        onUseConfig: {
                            handleMigrateRefreshToken()
                        },
                        initiallyExpanded: true
                    )
                    .padding()
                    Spacer()
                }
                .navigationTitle("Migrate to New App")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showMigrateRefreshToken = false
                        }
                    }
                }
            }
        }
        .alert("Migration Error", isPresented: $showMigrationError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(migrationError ?? "Unknown error occurred")
        }
    }
    
    private func loadCurrentCredentials() {
        guard let credentials = UserAccountManager.shared.currentUserAccount?.credentials else {
            return
        }
        
        let currentClientId = credentials.clientId ?? ""
        let currentRedirectUri = credentials.redirectUri ?? ""
        let currentScopes = credentials.scopes?.joined(separator: " ") ?? ""
        
        // Load static config
        let bootconfig = SalesforceManager.shared.bootConfig
        let bootconfigClientId = bootconfig?.remoteAccessConsumerKey ?? ""
        let bootconfigRedirectUri = bootconfig?.oauthRedirectURI ?? ""
        let bootconfigScopes = bootconfig?.oauthScopes.sorted().joined(separator: " ") ?? ""
        
        // Load bootconfig2.plist (dynamic config)
        let bootconfig2 = BootConfig("/bootconfig2.plist")
        let bootconfig2ClientId = bootconfig2?.remoteAccessConsumerKey ?? ""
        let bootconfig2RedirectUri = bootconfig2?.oauthRedirectURI ?? ""
        let bootconfig2Scopes = bootconfig2?.oauthScopes.sorted().joined(separator: " ") ?? ""
        
        // If current credentials match bootconfig.plist, populate with bootconfig2.plist
        if currentClientId == bootconfigClientId && 
           currentRedirectUri == bootconfigRedirectUri {
            migrateConsumerKey = bootconfig2ClientId
            migrateCallbackUrl = bootconfig2RedirectUri
            migrateScopes = bootconfig2Scopes
        } 
        // Otherwise populate with static config
        else {
            migrateConsumerKey = bootconfigClientId
            migrateCallbackUrl = bootconfigRedirectUri
            migrateScopes = bootconfigScopes
        }
    }
    
    private func handleMigrateRefreshToken() {
        guard let user = UserAccountManager.shared.currentUserAccount else {
            migrationError = "No current user found"
            showMigrationError = true
            return
        }
        
        // Parse scopes from space-separated string
        let scopesArray = migrateScopes
            .split(separator: " ")
            .map { String($0) }
            .filter { !$0.isEmpty }
        
        // Build config dictionary
        var configDict: [String: Any] = [
            "remoteAccessConsumerKey": migrateConsumerKey,
            "oauthRedirectURI": migrateCallbackUrl,
            "shouldAuthenticate": true
        ]
        
        // Only add scopes if not empty
        if !scopesArray.isEmpty {
            configDict["oauthScopes"] = scopesArray
        }
        
        guard let newAppConfig = BootConfig(configDict) else {
            migrationError = "Failed to create app configuration"
            showMigrationError = true
            return
        }
        
        isMigrating = true
        
        UserAccountManager.shared.migrateRefreshToken(
            for: user,
            newAppConfig: newAppConfig,
            success: { [self] _, _ in
                DispatchQueue.main.async {
                    isMigrating = false
                    showMigrateRefreshToken = false
                    refreshTrigger = UUID()
                }
            },
            failure: { [self] _, error in
                DispatchQueue.main.async {
                    isMigrating = false
                    migrationError = error.localizedDescription
                    showMigrationError = true
                }
            }
        )
    }
}

class SessionDetailViewController: UIHostingController<SessionDetailView> {
    
    init() {
        super.init(rootView: SessionDetailView(
            onChangeConsumerKey: {},
            onSwitchUser: {},
            onLogout: {}
        ))
        
        // Update the rootView with actual closures after init
        self.rootView = SessionDetailView(
            onChangeConsumerKey: { [weak self] in
                // Alert is handled in SwiftUI
            },
            onSwitchUser: { [weak self] in
                self?.handleSwitchUser()
            },
            onLogout: { [weak self] in
                self?.handleLogout()
            }
        )
    }
    
    @objc required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Show the toolbar so the bottom bar is visible
        navigationController?.isToolbarHidden = false
    }
    
    private func handleSwitchUser() {
        let umvc = SalesforceUserManagementViewController.init(completionBlock: { [weak self] _ in
            self?.dismiss(animated: true, completion: nil)
        })
        self.present(umvc, animated: true, completion: nil)
    }
    
    private func handleLogout() {
        // Perform the actual logout - config has already been selected by the user
        UserAccountManager.shared.logout(SFLogoutReason.userInitiated)
    }
}
