//
//  DPoPMigrationManager.swift
//  SalesforceSDKCore
//
//  Copyright (c) 2026-present, salesforce.com, inc. All rights reserved.
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

import Foundation

/// Headless helper that upgrades the current user's session from a Bearer (non-DPoP) refresh
/// token to a DPoP-bound one.
///
/// New logins are DPoP-bound by default, but users who logged in with an earlier SDK version (or
/// with DPoP disabled) keep a Bearer refresh token until the app migrates it. The SDK primitive is
/// `UserAccountManager.upgradeToDPoP(_:success:failure:)`; this class adds the "when and how":
///
///  - It is a no-op when there is no current user or the credentials are already DPoP-bound. The
///    credentials' token type is the only source of truth; no state is persisted.
///  - At most one upgrade is in flight. Callers arriving meanwhile are queued and completed
///    together with the same outcome.
///  - On failure nothing is persisted and the existing session is left intact, so the next call
///    (typically the next launch) retries. There is no automatic retry and no logout.
///
/// The upgrade may present the SDK's web-based approve/deny screen. This class has no UI of its
/// own: the app decides when to call it and what to show while it runs.
///
/// ```swift
/// switch await DPoPMigrationManager.shared.migrateIfNeeded() {
/// case .notNeeded, .migrated: break
/// case .failed(let error): print("Not migrated: \(error)")
/// }
/// ```
///
/// Only the current user is ever migrated; other users are migrated once they become current.
public final class DPoPMigrationManager {

    /// Result of a call to `migrateIfNeeded`.
    public enum Outcome {
        /// No current user, or the user's session is already DPoP-bound. Nothing was done.
        case notNeeded
        /// The session was upgraded and is now DPoP-bound.
        case migrated
        /// The upgrade failed. The existing session is untouched; a later call retries.
        case failed(Error)
    }

    /// Shared instance, bound to `UserAccountManager.shared`.
    public static let shared = DPoPMigrationManager()

    typealias UpgradeBlock = (_ user: UserAccount,
                              _ success: @escaping () -> Void,
                              _ failure: @escaping (Error) -> Void) -> Void

    private let currentUser: () -> UserAccount?
    private let upgrade: UpgradeBlock

    /// Main-queue only. Non-nil while an upgrade is in flight; holds every waiting completion.
    private var pendingCompletions: [(Outcome) -> Void]?

    private convenience init() {
        self.init(currentUser: { UserAccountManager.shared.currentUserAccount },
                  upgrade: { user, success, failure in
            UserAccountManager.shared.upgradeToDPoP(user, success: { _, _ in success() },
                                                    failure: { _, error in failure(error) })
        })
    }

    /// Seam for unit tests; not part of the public API.
    init(currentUser: @escaping () -> UserAccount?, upgrade: @escaping UpgradeBlock) {
        self.currentUser = currentUser
        self.upgrade = upgrade
    }

    // MARK: - Public API

    /// Whether `migrateIfNeeded` would start an upgrade right now, i.e. there is a current user
    /// whose credentials are not DPoP-bound. Cheap and side-effect free; use it to decide whether
    /// to show a progress screen.
    public var isMigrationNeeded: Bool {
        guard let user = currentUser() else { return false }
        return !DPoPRequestDecorator.isDPoPTokenType(user.credentials.tokenType)
    }

    /// Upgrades the current user to DPoP if needed.
    ///
    /// Concurrent calls share a single upgrade and all receive its outcome. The upgrade may
    /// present the SDK's approve/deny web screen.
    ///
    /// - Returns: The outcome. Failures are reported as `.failed`, never thrown.
    public func migrateIfNeeded() async -> Outcome {
        await withCheckedContinuation { continuation in
            migrateIfNeeded { continuation.resume(returning: $0) }
        }
    }

    /// Completion-handler variant of `migrateIfNeeded()`.
    ///
    /// - Parameter completion: Called exactly once, always on the main queue. When no migration is
    ///   needed and the caller is on the main queue it is called synchronously.
    public func migrateIfNeeded(completion: @escaping (Outcome) -> Void) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.migrateIfNeeded(completion: completion) }
            return
        }

        if pendingCompletions != nil {
            SFSDKCoreLogger.i(Self.self, message: "DPoPMigration: upgrade already in flight, joining it")
            pendingCompletions?.append(completion)
            return
        }

        guard let user = currentUser() else {
            SFSDKCoreLogger.i(Self.self, message: "DPoPMigration: not needed, no current user")
            completion(.notNeeded)
            return
        }
        guard !DPoPRequestDecorator.isDPoPTokenType(user.credentials.tokenType) else {
            SFSDKCoreLogger.i(Self.self, message: "DPoPMigration: not needed, already DPoP-bound")
            completion(.notNeeded)
            return
        }

        pendingCompletions = [completion]
        SFSDKCoreLogger.i(Self.self, message: "DPoPMigration: upgrade started")
        upgrade(user, {
            DispatchQueue.main.async {
                SFSDKCoreLogger.i(Self.self, message: "DPoPMigration: upgrade succeeded")
                self.finish(.migrated)
            }
        }, { error in
            DispatchQueue.main.async {
                SFSDKCoreLogger.w(Self.self, message: "DPoPMigration: upgrade failed: \((error as NSError).domain) \((error as NSError).code)")
                self.finish(.failed(error))
            }
        })
    }

    // MARK: - Private

    private func finish(_ outcome: Outcome) {
        let completions = pendingCompletions ?? []
        pendingCompletions = nil
        completions.forEach { $0(outcome) }
    }
}
