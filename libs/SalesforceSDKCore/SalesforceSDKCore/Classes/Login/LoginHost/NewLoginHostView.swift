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
class NewLoginHostViewController: NSObject {
    @objc public static func viewController(saveAction: @escaping ((String, String?) -> Void)) -> UIViewController {
        let view = NewLoginHostView(saveAction: saveAction)
        return UIHostingController(rootView: view)
    }
}

struct NewLoginHostField: View {
    let fieldLabel: String
    let fieldPlaceholder: String
    @Binding var fieldValue: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(fieldLabel)
            TextField(fieldPlaceholder, text: $fieldValue)
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
    @State var label = ""
    private var saveAction: ((String, String?) -> Void)
    
    init(saveAction: @escaping ((String, String?) -> Void)) {
        self.saveAction = saveAction
    }
    
    func save() {
        var hostToSave = host.trimmingCharacters(in: .whitespaces)
        if let httpsRange = hostToSave.range(of: "://") {
            hostToSave = String(host[...httpsRange.upperBound])
        }
        saveAction(hostToSave, label.trimmingCharacters(in: .whitespaces))
    }
    
    var body: some View {
        List {
            NewLoginHostField(fieldLabel: SFSDKResourceUtils.localizedString("LOGIN_SERVER_URL"),
                              fieldPlaceholder: SFSDKResourceUtils.localizedString("LOGIN_SERVER_URL_PLACEHOLDER"),
                              fieldValue: $host)
                .keyboardType(.URL)
                .autocapitalization(.none)
                .listRowSeparator(.hidden)

            NewLoginHostField(fieldLabel: SFSDKResourceUtils.localizedString("LOGIN_SERVER_NAME"),
                              fieldPlaceholder: SFSDKResourceUtils.localizedString("LOGIN_SERVER_NAME_PLACEHOLDER"),
                              fieldValue: $label)
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
                    Text("Done").bold()
                }
                .disabled(host.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }.tint(.white)
    }
}

#Preview {
    NewLoginHostView {_,_ in }
}
