/*
 RestApiTestView.swift
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

struct RestApiTestView: View {
    enum AlertType {
        case success
        case error(String)
    }
    
    @State private var isLoading = false
    @State private var lastRequestResult: String = ""
    @State private var isResultExpanded = false
    @State private var alertType: AlertType?
    
    let onRequestCompleted: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: {
                Task {
                    await makeRestRequest()
                }
            }) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    Text(isLoading ? "Making Request..." : "Make REST API Request")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(isLoading ? Color.gray : Color.blue)
                .cornerRadius(8)
            }
            .disabled(isLoading)
            
            // Response details section - collapsible
            if !lastRequestResult.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Button(action: {
                        withAnimation {
                            isResultExpanded.toggle()
                        }
                    }) {
                        HStack {
                            Text("Response Details")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: isResultExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(8)
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(6)
                    }
                    
                    if isResultExpanded {
                        ScrollView([.vertical, .horizontal], showsIndicators: true) {
                            Text(lastRequestResult)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.primary)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                        .frame(minHeight: 200, maxHeight: 400)
                        .background(Color(.systemGray6))
                        .cornerRadius(4)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
        .alert(item: Binding(
            get: { alertType.map { AlertItem(type: $0) } },
            set: { alertType = $0?.type }
        )) { alertItem in
            switch alertItem.type {
            case .success:
                return Alert(
                    title: Text("Request Successful"),
                    message: Text("The REST API request completed successfully. Expand 'Response Details' below to see the full response."),
                    dismissButton: .default(Text("OK"))
                )
            case .error(let message):
                return Alert(
                    title: Text("Request Failed"),
                    message: Text(message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    struct AlertItem: Identifiable {
        let id = UUID()
        let type: AlertType
    }
    
    // MARK: - REST API Request
    
    @MainActor
    private func makeRestRequest() async {
        isLoading = true
        lastRequestResult = ""
        isResultExpanded = false // Start collapsed
        
        do {
            let request = RestClient.shared.cheapRequest("v63.0")
            let response = try await RestClient.shared.send(request: request)
            
            // Request succeeded - pretty print the JSON
            let prettyJSON = prettyPrintJSON(response.asString())
            lastRequestResult = prettyJSON
            alertType = .success
            // Response starts collapsed - user can expand to see details
            
            // Notify parent to refresh fields
            onRequestCompleted()
        } catch {
            // Request failed
            lastRequestResult = error.localizedDescription
            alertType = .error(error.localizedDescription)
            // Error details start collapsed - user can expand to see details
        }
        
        isLoading = false
    }
    
    private func prettyPrintJSON(_ jsonString: String) -> String {
        guard let jsonData = jsonString.data(using: .utf8) else {
            return jsonString
        }
        
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: [])
            let prettyData = try JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys])
            
            if let prettyString = String(data: prettyData, encoding: .utf8) {
                return prettyString
            }
        } catch {
            // If parsing fails, return original string
            return jsonString
        }
        
        return jsonString
    }
}

