/*
 InfoRowView.swift
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

struct InfoRowView: View {
    let label: String
    let value: String
    var isSensitive: Bool = false
    
    @State private var isRevealed = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if isSensitive && !isRevealed && !value.isEmpty {
                HStack {
                    Text(maskedValue)
                        .font(.system(.caption, design: .monospaced))
                    Spacer()
                    Button(action: { isRevealed.toggle() }) {
                        Image(systemName: "eye")
                            .foregroundColor(.blue)
                    }
                }
            } else {
                HStack {
                    Text(value.isEmpty ? "(empty)" : value)
                        .font(.system(.caption, design: .monospaced))
                    Spacer()
                    if isSensitive && !value.isEmpty {
                        Button(action: { isRevealed.toggle() }) {
                            Image(systemName: "eye.slash")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("\(label)_row")
    }
    
    // MARK: - Computed Properties
    
    private var maskedValue: String {
        guard value.count >= 10 else {
            return "••••••••"
        }
        
        let firstFive = value.prefix(5)
        let lastFive = value.suffix(5)
        return "\(firstFive)...\(lastFive)"
    }
}

