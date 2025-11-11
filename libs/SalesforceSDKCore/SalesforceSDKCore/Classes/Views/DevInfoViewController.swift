/*
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

// MARK: - SwiftUI View

public struct SFSDKDevInfoView: View {
    @Environment(\.dismiss) private var dismiss
    
    let infoData: [String]
    let title: String
    
    @State private var showingAlert = false
    @State private var alertTitle: String?
    @State private var alertMessage = ""
    
    public init(infoData: [String], title: String) {
        self.infoData = infoData
        self.title = title
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Custom Title Bar
            DevInfoTitleBarView(title: title) {
                dismiss()
            }
            
            // Info List
            List {
                ForEach(0..<(infoData.count / 2), id: \.self) { index in
                    let labelIndex = index * 2
                    let valueIndex = index * 2 + 1
                    
                    if labelIndex < infoData.count && valueIndex < infoData.count {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(infoData[labelIndex])
                                .font(.headline)
                            Text(infoData[valueIndex])
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            alertTitle = nil
                            alertMessage = infoData[valueIndex]
                            showingAlert = true
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
        .alert(alertTitle ?? "", isPresented: $showingAlert) {
            Button(SFSDKResourceUtils.localizedString("devInfoOKKey")) {
                showingAlert = false
            }
        } message: {
            Text(alertMessage)
        }
    }
}

// MARK: - Title Bar View

struct DevInfoTitleBarView: View {
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

@objc public class SFSDKDevInfoViewController: NSObject {
    
    @objc public static func makeViewController() -> UIViewController {
        let infoData = SalesforceManager.shared.devSupportInfoList()
        let title = SalesforceManager.shared.devInfoTitleString()
        let view = SFSDKDevInfoView(infoData: infoData, title: title)
        let hostingController = UIHostingController(rootView: view)
        
        // Use pageSheet for slide-up presentation
        if let sheet = hostingController.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 16
        }
        
        return hostingController
    }
}

