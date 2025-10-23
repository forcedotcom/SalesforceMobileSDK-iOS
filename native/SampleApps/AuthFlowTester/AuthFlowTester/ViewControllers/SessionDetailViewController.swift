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
    @State private var showNotImplementedAlert = false
    @State private var showLogoutConfigPicker = false
    
    var onChangeConsumerKey: () -> Void
    var onSwitchUser: () -> Void
    var onLogout: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // REST API Request Section (moved to top)
                RestApiTestView(onRequestCompleted: {
                    refreshTrigger = UUID()
                })
                
                // OAuth Configuration Section
                OAuthConfigurationView()
                    .id(refreshTrigger)
                                
                // User Credentials Section
                UserCredentialsView()
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
                    showNotImplementedAlert = true
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
        .alert("Change Consumer Key", isPresented: $showNotImplementedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Not implemented yet!")
        }
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
