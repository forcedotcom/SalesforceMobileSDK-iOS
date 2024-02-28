//
//  ScreenLockUIView.swift
//  SalesforceSDKCore
//
//  Created by Brandon Page on 9/9/21.
//  Copyright (c) 2021-present, salesforce.com, inc. All rights reserved.
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

import SwiftUI
import LocalAuthentication

struct ScreenLockUIView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var hasError = false
    @State private var canEvaluatePolicy = false
    @State private var errorText = ""
    
    var body: some View {
        VStack(alignment: .center, content: {
            HStack {
                if hasError {
                    Button(action: { logout() },
                           label: {
                        Text(SFSDKResourceUtils.localizedString("logoutButtonTitle"))
                            .foregroundColor(Color(UIColor.salesforceBlue))
                    }).padding()
                }
                Spacer()
            }
            Spacer()
            
            Image(uiImage: getIcon())
                .resizable()
                .frame(width: 125, height: 125, alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/)
                .offset(y: getImageOffset())
                .padding()
            
            if hasError {
                Text(errorText)
                    .padding()
                    .offset(y: -175)
               
                if canEvaluatePolicy {
                    Button(action: showBiometic) {
                        Text(SFSDKResourceUtils.localizedString("retryButtonTitle"))
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color(UIColor.salesforceBlue).cornerRadius(5))
                    .offset(y: -175)
                }
            }
        })
        .onAppear(perform: {
            showBiometic()
        })
    }
    
    func showBiometic() {
        let context = LAContext()
        var error: NSError?
        
        hasError = false
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            canEvaluatePolicy = true
            let reason = SFSDKResourceUtils.localizedString("biometricReason")
            
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, error in
                if success {
                    DispatchQueue.main.async {
                        ScreenLockManagerInternal.shared.unlock()
                    }
                } else {
                    errorText = error?.localizedDescription ?? SFSDKResourceUtils.localizedString("fallbackErrorMessage")
                    hasError = true
                }
            }
        } else {
            errorText = String(format: SFSDKResourceUtils.localizedString("setUpPasscodeMessage"), SalesforceManager.shared.appDisplayName)
            hasError = true
            canEvaluatePolicy = false
        }
    }
    
    private func getImageOffset() -> CGFloat {
        return hasError ? -350 : -470
    }
}

private func getIcon() -> UIImage {
    let fallbackIcon = SFSDKResourceUtils.imageNamed("salesforce-logo")
    if let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
                let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
                let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
                let lastIcon = iconFiles.last {
        return UIImage(named: lastIcon) ?? fallbackIcon
    }
    
    return fallbackIcon
}

private func logout() {
    ScreenLockManagerInternal.shared.logoutScreenLockUsers();

    if(UIAccessibility.isVoiceOverRunning) {
        UIAccessibility.post(notification: UIAccessibility.Notification.screenChanged, argument: SFSDKResourceUtils.localizedString("accessibilityLoggedOutAnnouncement"))
    }
}

struct ScreenLockUIView_Previews: PreviewProvider {
    static var previews: some View {
        ScreenLockUIView()
    }
}
