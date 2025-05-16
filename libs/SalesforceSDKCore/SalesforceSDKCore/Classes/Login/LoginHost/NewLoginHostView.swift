//
//  NewLoginHostView.swift
//  SalesforceSDKCore
//
//  Created by Brianna Birman on 12/19/24.
//  Copyright (c) 2024-present, salesforce.com, inc. All rights reserved.
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

@objc(SFSDKNewLoginHostViewController)
public class NewLoginHostViewController: NSObject {
    @objc public static func viewController(config: SFSDKViewControllerConfig?, saveAction: @escaping ((String, String?) -> Void)) -> UIViewController {
        let view = NewLoginHostView(viewControllerConfig: config, saveAction: saveAction)
        return UIHostingController(rootView: view)
    }
}

struct NewLoginHostField: View {
    let fieldLabel: String
    let fieldLabelAccessibilityID: String
    let fieldPlaceholder: String
    let fieldInputAccessibilityID: String
    @Binding var fieldValue: String
    
    func placeholderText() -> Text {
        let dynamicColor = Color(lightStyle: Color(red: 118/255, green: 118/255, blue: 118/255),
                                 darkStyle: Color(red: 132/255, green: 132/255, blue: 132/255))
       
        return Text(fieldPlaceholder).foregroundStyle(dynamicColor)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(fieldLabel)
                .accessibilityIdentifier(fieldLabelAccessibilityID)
            TextField("", text: $fieldValue, prompt: placeholderText())
                .accessibilityIdentifier(fieldInputAccessibilityID)
                .autocorrectionDisabled()
                .padding()
                .background(
                    RoundedRectangle(cornerSize: CGSize(width: 10, height: 10))
                        .stroke(Color(uiColor: .label), lineWidth: 0.5)
                )
        }
    }
}

struct NewLoginHostView: View {
    @State var host = ""
    @State var hostLabel = ""
    private var saveAction: ((String, String?) -> Void)
    private var navBarTintColor: Color
    
    init(viewControllerConfig: SFSDKViewControllerConfig?, saveAction: @escaping ((String, String?) -> Void)) {
        self.saveAction = saveAction
        if let navBarTintColor =  viewControllerConfig?.navigationBarTintColor {
            self.navBarTintColor = Color(uiColor: navBarTintColor)
        } else {
            self.navBarTintColor = Color(uiColor: UIColor.salesforceNavBarTint)
        }
    }
    
    func save() {
        var hostToSave = host.trimmingCharacters(in: .whitespaces)
        if hostToSave.contains("://"),
           let components = URLComponents(string: hostToSave) {
            let scheme = components.scheme ?? ""
            hostToSave = String(hostToSave.dropFirst("\(scheme)://".count))
        }
        saveAction(hostToSave, hostLabel.trimmingCharacters(in: .whitespaces))
    }
    
    var body: some View {
        List {
            NewLoginHostField(fieldLabel: SFSDKResourceUtils.localizedString("LOGIN_SERVER_URL"),
                              fieldLabelAccessibilityID: "addconn_hostLabel",
                              fieldPlaceholder: SFSDKResourceUtils.localizedString("LOGIN_SERVER_URL_PLACEHOLDER"),
                              fieldInputAccessibilityID: "addconn_hostInput",
                              fieldValue: $host)
                .keyboardType(.URL)
                .autocapitalization(.none)
                .listRowSeparator(.hidden)

            NewLoginHostField(fieldLabel: SFSDKResourceUtils.localizedString("LOGIN_SERVER_NAME"),
                              fieldLabelAccessibilityID: "addconn_nameLabel",
                              fieldPlaceholder: SFSDKResourceUtils.localizedString("LOGIN_SERVER_NAME_PLACEHOLDER"),
                              fieldInputAccessibilityID: "addconn_nameInput",
                              fieldValue: $hostLabel)
                .listRowSeparator(.hidden)
                .padding(.bottom)
        }
        
        .background(Color(uiColor: .secondarySystemBackground))
        .scrollDisabled(true)
        .listStyle(.plain)
        .navigationTitle(SFSDKResourceUtils.localizedString("LOGIN_ADD_SERVER"))
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    save()
                } label: {
                    Text(SFSDKResourceUtils.localizedString("DONE_BUTTON")).bold()
                }
                .tint(navBarTintColor)
                .disabled(host.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
}

#Preview {
    NewLoginHostView(viewControllerConfig: nil) {_,_ in }
}
