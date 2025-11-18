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

// MARK: - Data Model

struct DevInfoRow: Identifiable {
    let id = UUID()
    let headline: String
    let text: String
}

struct DevInfoSection: Identifiable {
    let id = UUID()
    let title: String?
    let rows: [DevInfoRow]
}

// MARK: - SwiftUI View

public struct DevInfoView: View {
    @Environment(\.dismiss) private var dismiss
    
    let sections: [DevInfoSection]
    let title: String
    
    @State private var showingAlert = false
    @State private var alertTitle: String?
    @State private var alertMessage = ""
    
    public init(infoData: [String], title: String) {
        self.sections = Self.extractSections(from: infoData)
        self.title = title
    }
    
    private static func extractSections(from infoData: [String]) -> [DevInfoSection] {
        var sections: [DevInfoSection] = []
        var currentSectionTitle: String? = nil
        var currentRows: [DevInfoRow] = []
        var index = 0
        
        while index < infoData.count {
            let item = infoData[index]
            
            // Check if this is a section marker
            if item.hasPrefix("section:") {
                // Save previous section if it has rows
                if !currentRows.isEmpty {
                    sections.append(DevInfoSection(title: currentSectionTitle, rows: currentRows))
                    currentRows = []
                }
                
                // Extract section title (everything after "section:")
                let sectionTitle = String(item.dropFirst("section:".count))
                currentSectionTitle = sectionTitle.isEmpty ? nil : sectionTitle
                index += 1
            } else {
                // This should be a headline, followed by text
                if index + 1 < infoData.count {
                    let headline = infoData[index]
                    let text = infoData[index + 1]
                    currentRows.append(DevInfoRow(headline: headline, text: text))
                    index += 2
                } else {
                    // Odd number of items, skip the last one
                    index += 1
                }
            }
        }
        
        // Add the last section if it has rows
        if !currentRows.isEmpty {
            sections.append(DevInfoSection(title: currentSectionTitle, rows: currentRows))
        }
        
        return sections
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Custom Title Bar
            DevInfoTitleBarView(title: title) {
                dismiss()
            }
            
            // Info List with Sections
            List {
                ForEach(sections) { section in
                    if let sectionTitle = section.title {
                        // Section with title - collapsible
                        DisclosureGroup {
                            ForEach(section.rows) { row in
                                rowView(for: row)
                            }
                        } label: {
                            Text(sectionTitle)
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                    } else {
                        // Title-less section - no header
                        ForEach(section.rows) { row in
                            rowView(for: row)
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
    
    @ViewBuilder
    private func rowView(for row: DevInfoRow) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(row.headline)
                .font(.headline)
            Text(row.text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            alertTitle = nil
            alertMessage = row.text
            showingAlert = true
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

@objc(SFSDKDevInfoViewController)
public class DevInfoViewController: NSObject {
    
    @objc public static func makeViewController() -> UIViewController {
        let infoData = SalesforceManager.shared.devSupportInfoList()
        let title = SalesforceManager.shared.devInfoTitleString()
        let view = DevInfoView(infoData: infoData, title: title)
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

