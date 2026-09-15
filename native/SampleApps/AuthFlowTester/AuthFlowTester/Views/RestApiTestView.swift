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
import UIKit

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
            let request = RestClient.shared.cheapRequest(nil)
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

// MARK: - Concurrent REST Requests

private enum ConcurrentRequestKind: String, CaseIterable {
    case resources
    case limits
    case describeGlobal
    case intentionalFailure

    var title: String {
        switch self {
        case .resources: return "API Resources"
        case .limits: return "Limits"
        case .describeGlobal: return "Describe Global"
        case .intentionalFailure: return "Intentional Failure"
        }
    }
}

private enum ConcurrentRequestState: String {
    case queued
    case inFlight
    case succeeded
    case failed

    var color: Color {
        switch self {
        case .queued: return .gray
        case .inFlight: return .blue
        case .succeeded: return .green
        case .failed: return .red
        }
    }

    var accessibilityValue: String {
        switch self {
        case .queued: return "Queued"
        case .inFlight: return "In flight"
        case .succeeded: return "Succeeded"
        case .failed: return "Failed"
        }
    }
}

private enum ConcurrentRequestInterruption: String, CaseIterable, Identifiable {
    case manual
    case revoke
    case logout

    var id: String { rawValue }

    var title: String {
        switch self {
        case .manual: return "Manual"
        case .revoke: return "Revoke in flight"
        case .logout: return "Logout in flight"
        }
    }
}

private enum ConcurrentInterruptionState: String {
    case idle
    case requested
    case completed
    case failed

    var title: String {
        switch self {
        case .idle: return "Not requested"
        case .requested: return "Requested"
        case .completed: return "Completed"
        case .failed: return "Failed"
        }
    }
}

private struct ConcurrentRequestFailure: Identifiable {
    let requestNumber: Int
    let kind: ConcurrentRequestKind
    let endpoint: String
    let statusCode: Int?
    let message: String
    let responseBody: String?

    var id: Int { requestNumber }

    var copyText: String {
        var lines = [
            "Request: \(requestNumber)",
            "Type: \(kind.title)",
            "Endpoint: \(endpoint)",
            "Status: \(statusCode.map(String.init) ?? "Unavailable")",
            "Error: \(message)"
        ]
        if let responseBody, !responseBody.isEmpty {
            lines.append("Response: \(responseBody)")
        }
        return lines.joined(separator: "\n")
    }
}

private struct ConcurrentRequestItem: Identifiable {
    let id: Int
    let kind: ConcurrentRequestKind
    let endpoint: String
    var state: ConcurrentRequestState
    var failure: ConcurrentRequestFailure?
}

private struct ConcurrentRequestWorkItem {
    let index: Int
    let kind: ConcurrentRequestKind
    let request: RestRequest
}

struct ConcurrentRestApiTestView: View {
    private static let requestCountChoices = [5, 10, 20, 50]
    private static let automaticInterruptionThreshold = 5

    @State private var isOptionsExpanded = false
    @State private var requestCount = 20
    @State private var interruption = ConcurrentRequestInterruption.manual
    @State private var interruptionState = ConcurrentInterruptionState.idle
    @State private var interruptionError: String?
    @State private var requestItems: [ConcurrentRequestItem] = []
    @State private var activeRunID: UUID?
    @State private var didTriggerInterruption = false
    @State private var didLogout = false
    @State private var peakInFlight = 0
    @State private var selectedFailure: ConcurrentRequestFailure?

    let onRequestCompleted: () -> Void
    let onLogout: (UserAccount) -> Void

    private var isRunning: Bool { activeRunID != nil }
    private var queuedCount: Int { requestItems.filter { $0.state == .queued }.count }
    private var inFlightCount: Int { requestItems.filter { $0.state == .inFlight }.count }
    private var succeededCount: Int { requestItems.filter { $0.state == .succeeded }.count }
    private var failedCount: Int { requestItems.filter { $0.state == .failed }.count }
    private var completedCount: Int { succeededCount + failedCount }
    private var interruptionThreshold: Int {
        min(Self.automaticInterruptionThreshold, requestCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Concurrent REST Requests")
                .font(.headline)

            DisclosureGroup(isExpanded: $isOptionsExpanded) {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Request count", selection: $requestCount) {
                        ForEach(Self.requestCountChoices, id: \.self) { count in
                            Text("\(count)").tag(count)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(isRunning)
                    .accessibilityIdentifier("manyRequestsCountPicker")

                    Picker("Interruption", selection: $interruption) {
                        ForEach(ConcurrentRequestInterruption.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(isRunning)
                    .accessibilityIdentifier("manyRequestsInterruptionPicker")

                    if interruption != .manual {
                        Text("Runs after \(interruptionThreshold) requests enter flight.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 8)
            } label: {
                Text("Options: \(requestCount) requests · Mixed · \(interruption.title)")
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
            .accessibilityIdentifier("manyRequestsOptions")

            Button(action: {
                Task {
                    await makeManyRequests()
                }
            }) {
                HStack {
                    if isRunning {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    Text(isRunning ? "Making Requests..." : "Make Many Requests")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(isRunning ? Color.gray : Color.blue)
                .cornerRadius(8)
            }
            .disabled(isRunning)
            .accessibilityIdentifier("makeManyRestRequestsButton")

            if !requestItems.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 30), spacing: 8)], spacing: 8) {
                    ForEach(requestItems) { item in
                        Button(action: {
                            selectedFailure = item.failure
                        }) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(item.state.color)
                                .frame(width: 30, height: 30)
                                .overlay {
                                    Text("\(item.id)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                }
                        }
                        .buttonStyle(.plain)
                        .disabled(item.failure == nil)
                        .accessibilityIdentifier("manyRequestSquare-\(item.id)")
                        .accessibilityLabel("Request \(item.id), \(item.kind.title)")
                        .accessibilityValue(item.state.accessibilityValue)
                    }
                }
                .accessibilityIdentifier("manyRequestsGrid")

                HStack(spacing: 10) {
                    countLabel("Queued", value: queuedCount, identifier: "manyRequestsQueuedCount")
                    countLabel("In flight", value: inFlightCount, identifier: "manyRequestsInFlightCount")
                    countLabel("Succeeded", value: succeededCount, identifier: "manyRequestsSucceededCount")
                    countLabel("Failed", value: failedCount, identifier: "manyRequestsFailedCount")
                }
                .font(.caption)

                Text("\(completedCount) / \(requestItems.count) completed")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("manyRequestsCompletedSummary")

                Text("Peak in flight: \(peakInFlight)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier("manyRequestsPeakInFlight")

                if interruption != .manual {
                    Text("Interruption: \(interruptionState.title)")
                        .font(.caption)
                        .foregroundColor(interruptionState == .failed ? .red : .secondary)
                        .accessibilityIdentifier("manyRequestsInterruptionState")
                    if let interruptionError {
                        Text(interruptionError)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
        .sheet(item: $selectedFailure) { failure in
            NavigationView {
                List {
                    detailRow("Request", value: String(failure.requestNumber), identifier: "manyRequestErrorNumber")
                    detailRow("Type", value: failure.kind.title, identifier: "manyRequestErrorType")
                    detailRow("Endpoint", value: failure.endpoint, identifier: "manyRequestErrorEndpoint")
                    detailRow("HTTP Status", value: failure.statusCode.map(String.init) ?? "Unavailable", identifier: "manyRequestErrorStatus")
                    detailRow("Error", value: failure.message, identifier: "manyRequestErrorMessage")
                    if let responseBody = failure.responseBody, !responseBody.isEmpty {
                        detailRow("Response Body", value: responseBody, identifier: "manyRequestErrorResponseBody")
                    }
                }
                .navigationTitle("Request Error")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Copy") {
                            UIPasteboard.general.string = failure.copyText
                        }
                        .accessibilityIdentifier("manyRequestErrorCopyButton")
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            selectedFailure = nil
                        }
                        .accessibilityIdentifier("manyRequestErrorDoneButton")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func countLabel(_ title: String, value: Int, identifier: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .fontWeight(.semibold)
                .accessibilityIdentifier(identifier)
            Text(title)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private func detailRow(_ title: String, value: String, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.body)
                .textSelection(.enabled)
                .accessibilityIdentifier(identifier)
        }
    }

    // MARK: Batch execution

    @MainActor
    private func makeManyRequests() async {
        guard !isRunning,
              let account = UserAccountManager.shared.currentUserAccount,
              let restClient = RestClient.restClient(for: account) else {
            return
        }

        let runID = UUID()
        activeRunID = runID
        didTriggerInterruption = false
        didLogout = false
        peakInFlight = 0
        interruptionState = .idle
        interruptionError = nil
        selectedFailure = nil

        let workItems = (1...requestCount).map { requestNumber in
            let kind = requestKind(for: requestNumber)
            let request = makeRequest(kind: kind, client: restClient)
            return ConcurrentRequestWorkItem(index: requestNumber - 1, kind: kind, request: request)
        }

        requestItems = workItems.map { workItem in
            return ConcurrentRequestItem(
                id: workItem.index + 1,
                kind: workItem.kind,
                endpoint: workItem.request.path,
                state: .queued,
                failure: nil
            )
        }

        await withTaskGroup(of: Void.self) { group in
            for workItem in workItems {
                group.addTask {
                    let shouldInterrupt = await markInFlight(index: workItem.index, runID: runID)
                    if shouldInterrupt {
                        await performAutomaticInterruption(account: account, client: restClient, runID: runID)
                    }

                    do {
                        _ = try await restClient.send(request: workItem.request)
                        await markSucceeded(index: workItem.index, runID: runID)
                    } catch {
                        await markFailed(error, index: workItem.index, runID: runID)
                    }
                }
            }
        }

        guard activeRunID == runID else { return }
        activeRunID = nil
        if !didLogout {
            onRequestCompleted()
        }
    }

    @MainActor
    private func markInFlight(index: Int, runID: UUID) -> Bool {
        guard activeRunID == runID, requestItems.indices.contains(index) else { return false }
        requestItems[index].state = .inFlight
        peakInFlight = max(peakInFlight, inFlightCount)

        guard interruption != .manual,
              !didTriggerInterruption,
              peakInFlight >= interruptionThreshold else {
            return false
        }
        didTriggerInterruption = true
        interruptionState = .requested
        return true
    }

    @MainActor
    private func performAutomaticInterruption(account: UserAccount, client: RestClient, runID: UUID) async {
        guard activeRunID == runID else { return }

        // Keep the requested state visible to UI automation and give the already-submitted
        // children an opportunity to enter URLSession before cleanup/revocation begins.
        try? await Task.sleep(nanoseconds: 300_000_000)
        guard activeRunID == runID else { return }

        switch interruption {
        case .manual:
            return
        case .revoke:
            guard let request = client.requestForRevokeAccessToken(user: account) else {
                interruptionState = .failed
                interruptionError = "Token revoke request couldn't be generated"
                return
            }
            do {
                _ = try await client.send(request: request)
                interruptionState = .completed
            } catch {
                interruptionState = .failed
                interruptionError = error.localizedDescription
            }
        case .logout:
            didLogout = true
            interruptionState = .completed
            onLogout(account)
        }
    }

    @MainActor
    private func markSucceeded(index: Int, runID: UUID) {
        guard activeRunID == runID,
              requestItems.indices.contains(index),
              requestItems[index].state == .inFlight else { return }
        requestItems[index].state = .succeeded
    }

    @MainActor
    private func markFailed(_ error: Error, index: Int, runID: UUID) {
        guard activeRunID == runID,
              requestItems.indices.contains(index),
              requestItems[index].state == .inFlight else { return }

        let item = requestItems[index]
        let details = errorDetails(error)
        requestItems[index].failure = ConcurrentRequestFailure(
            requestNumber: item.id,
            kind: item.kind,
            endpoint: item.endpoint,
            statusCode: details.statusCode,
            message: details.message,
            responseBody: details.responseBody
        )
        requestItems[index].state = .failed
    }

    private func requestKind(for requestNumber: Int) -> ConcurrentRequestKind {
        #if DEBUG
        if forcedFailureRequestNumber == requestNumber {
            return .intentionalFailure
        }
        #endif
        let mix: [ConcurrentRequestKind] = [.resources, .limits, .describeGlobal]
        return mix[(requestNumber - 1) % mix.count]
    }

    private func makeRequest(kind: ConcurrentRequestKind, client: RestClient) -> RestRequest {
        switch kind {
        case .resources:
            return client.cheapRequest(nil)
        case .limits:
            return client.request(forLimits: nil)
        case .describeGlobal:
            return client.request(forDescribeGlobal: nil)
        case .intentionalFailure:
            return RestRequest(
                method: .GET,
                path: "/\(client.apiVersion)/auth-flow-tester-intentional-failure",
                queryParams: nil
            )
        }
    }

    private func errorDetails(_ error: Error) -> (statusCode: Int?, message: String, responseBody: String?) {
        guard case let RestClientError.apiFailed(response, underlyingError, urlResponse) = error else {
            return (nil, error.localizedDescription, nil)
        }

        let body: String?
        if let data = response as? Data {
            body = String(data: data, encoding: .utf8)
        } else if let response {
            body = String(describing: response)
        } else {
            body = nil
        }
        return ((urlResponse as? HTTPURLResponse)?.statusCode, underlyingError.localizedDescription, body)
    }

    #if DEBUG
    private var forcedFailureRequestNumber: Int? {
        let prefix = "--failManyRequestAtIndex="
        guard let argument = CommandLine.arguments.first(where: { $0.hasPrefix(prefix) }) else {
            return nil
        }
        return Int(argument.dropFirst(prefix.count))
    }
    #endif
}
