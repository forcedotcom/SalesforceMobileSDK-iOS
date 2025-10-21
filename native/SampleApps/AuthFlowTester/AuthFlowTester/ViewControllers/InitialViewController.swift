/*
 InitialViewController.swift
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

struct InitialView: View {
    @State private var isLoading = false
    let onConfigurationCompleted: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            // App name label
            Text(appName)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .padding(.top, 100)
            
            Spacer()
            
            // Buttons container
            VStack(spacing: 20) {
                // Static bootconfig button
                Button(action: handleStaticBootconfig) {
                    Text("Use static bootconfig")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 200, height: 44)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                .disabled(isLoading)
                
                // Dynamic bootconfig button
                Button(action: handleDynamicBootconfig) {
                    Text("Use dynamic bootconfig")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 200, height: 44)
                        .background(Color.green)
                        .cornerRadius(8)
                }
                .disabled(isLoading)
            }
            
            Spacer()
            
            // Loading indicator
            if isLoading {
                ProgressView("Authenticating...")
                    .padding()
            }
        }
        .background(Color(.systemBackground))
        .onAppear {
            // Any setup that needs to happen when the view appears
        }
    }
    
    // MARK: - Computed Properties
    
    private var appName: String {
        guard let info = Bundle.main.infoDictionary,
              let name = info[kCFBundleNameKey as String] as? String else {
            return "AuthFlowTester"
        }
        return name
    }
    
    // MARK: - Button Actions
    
    private func handleStaticBootconfig() {
        isLoading = true
        
        SalesforceManager.shared.revertToBootConfig()
        
        // Use static bootconfig - no additional setup needed
        onConfigurationCompleted()
    }
    
    private func handleDynamicBootconfig() {
        isLoading = true
        
        // Use the dynamic bootconfig method
        SalesforceManager.shared.overrideBootConfig(
            // ECA without refresh scope
            consumerKey: "3MVG9SemV5D80oBcXZ2EUzbcJw.BPBV7Nd7htOt2IMVa3r5Zb_UgI92gVmxnVoCLfysf3.tIkrYAJF8mHsJxB",
            callbackUrl: "testsfdc:///mobilesdk/detect/oauth/done"
        )
        
        // Proceed with login
        onConfigurationCompleted()
    }
}

// MARK: - UIViewControllerRepresentable

struct InitialViewController: UIViewControllerRepresentable {
    let onConfigurationCompleted: () -> Void
    
    func makeUIViewController(context: Context) -> UIHostingController<InitialView> {
        return UIHostingController(rootView: InitialView(onConfigurationCompleted: onConfigurationCompleted))
    }
    
    func updateUIViewController(_ uiViewController: UIHostingController<InitialView>, context: Context) {
        // No updates needed
    }
}
