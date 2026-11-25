//
//  QueueSyncUpTarget.swift
//  MobileSync
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

import Foundation
import SalesforceSDKCore
import SmartStore

/// An entry of the sync-up queue (`mobilesync_queue`) as read by the replay.
struct QueueEntry {
    /// `_soupEntryId` of the entry in the queue soup.
    let entryId: NSNumber
    let raw: [String: Any]
    let sequence: Int
    let soupName: String
    let recordId: String
    let sobjectType: String?
    let kind: SyncQueue.Kind?
    let changes: [String: Any]
    let status: String
    let attempts: Int
    let parentRef: String?

    init?(_ raw: [String: Any]) {
        guard let entryId = raw[SmartStore.soupEntryId] as? NSNumber,
              let soupName = raw[SyncQueue.soupNameField] as? String,
              let recordId = raw[SyncQueue.recordIdField] as? String else {
            return nil
        }
        self.entryId = entryId
        self.raw = raw
        self.soupName = soupName
        self.recordId = recordId
        self.sequence = (raw[SyncQueue.sequenceField] as? NSNumber)?.intValue ?? 0
        self.sobjectType = raw[SyncQueue.sobjectTypeField] as? String
        self.kind = (raw[SyncQueue.kindField] as? String).flatMap { SyncQueue.Kind(rawValue: $0) }
        self.changes = raw[SyncQueue.changesField] as? [String: Any] ?? [:]
        self.status = raw[SyncQueue.statusField] as? String ?? SyncQueue.Status.pending.rawValue
        self.attempts = (raw[SyncQueue.attemptsField] as? NSNumber)?.intValue ?? 0
        self.parentRef = raw[SyncQueue.parentRefField] as? String
    }
}

/// A sync-up target that replays the entries of the sync-up queue (`mobilesync_queue`) in `sequence` order,
/// one at a time, building each request from the entry (not from the dirty flags of the record).
///
/// Use it with `SyncManager.syncUp` and `soupName` set to `SyncQueue.soupName`; the record soup of each entry
/// is the one named by the entry. `fieldlist`, `createFieldlist`, `updateFieldlist` and `mergeMode` of the sync
/// are ignored (the changes recorded in the entry decide what is sent); `externalIdFieldName` is honored for
/// creates. Syncs are replayed by `QueueSyncUpTask`, which `SyncManager` picks for this target.
///
/// A record soup must use either the queue or flag-based sync up, never both.
@objc(SFQueueSyncUpTarget)
public class QueueSyncUpTarget: SyncUpTarget {

    override public class func build(dict: [AnyHashable: Any]?) -> Self {
        return self.init(dict: dict ?? Dictionary())
    }

    override public init() {
        super.init(createFieldlist: nil, updateFieldlist: nil)
    }

    /// Construct the target from json.
    override required public init(dict: [AnyHashable: Any]) {
        super.init(dict: dict)
    }

    /// The queue replaces the dirty-flag selection: this target never touches flagged records without entries.
    override public func getIdsOfRecords(toSyncUp syncManager: SyncManager, soupName: String) -> [Any] {
        return []
    }

    // MARK: Requests

    /// Sends the request of an entry: `POST` for a create (or an upsert on `externalIdFieldName`), `PATCH` for an
    /// update, `DELETE` for a delete. Nothing is sent for an invalid entry (no kind or no object type): `onFail`
    /// is called instead. The request code is the one of `SyncUpTarget`, so subclasses overriding
    /// `createOnServer`, `updateOnServer` or `deleteOnServer` see the calls.
    func sendRequest(_ syncManager: SyncManager,
                     entry: QueueEntry,
                     onComplete: @escaping ([AnyHashable: Any]?) -> Void,
                     onFail: @escaping (NSError) -> Void) {
        guard let kind = entry.kind else {
            return onFail(QueueSyncUpTarget.recordError("Unknown entry kind"))
        }
        guard let sobjectType = entry.sobjectType, !sobjectType.isEmpty else {
            return onFail(QueueSyncUpTarget.recordError("The entry has no object type"))
        }
        let fail: (Error) -> Void = { onFail($0 as NSError) }

        // Record-shaped map for the request helpers: the object type, the id and the changed fields
        var record = entry.changes
        // One validated external id value decides the request, the body and the lookup
        let externalId = upsertExternalId(of: entry)
        let externalField = upsertField(of: entry)
        var fieldlist = Array(entry.changes.keys)
        if let field = externalField {
            if externalId != nil {
                // The server refuses an upsert body that contains the external id field (it is in the path)
                fieldlist.removeAll { $0 == field }
            } else if !(entry.changes[field] as? String).map({ SyncTarget.isLocalId($0) && QueueSyncUpTarget.isNonBlank($0) }).orFalse {
                // null, blank or not a string: no upsert key. The value is left out of the plain POST, and the
                // request code must not see it (it takes any non-nil value for an external id)
                record.removeValue(forKey: field)
                fieldlist.removeAll { $0 == field }
            }
        }
        record["attributes"] = ["type": sobjectType]
        record[idFieldName] = entry.recordId
        switch kind {
        case .create:
            // An upsert on an existing record answers 204 without a body (a 201 has the id in its body): the id is looked up
            let complete: ([AnyHashable: Any]?) -> Void = { [self] response in
                // a blank id is not an id: the replay treats the answer as unexpected
                if response?[kCreatedId] is String { return onComplete(response) }
                guard let field = externalField, let value = externalId else {
                    return onComplete(response)
                }
                lookupIdOnServer(sobjectType, externalIdField: field, externalId: value, onComplete: onComplete, onFail: onFail)
            }
            createOnServer(syncManager: syncManager, record: record, fieldlist: fieldlist, onComplete: complete, onFail: fail)
        case .update:
            updateOnServer(syncManager: syncManager, record: record, fieldlist: Array(entry.changes.keys), onComplete: onComplete, onFail: fail)
        case .delete:
            deleteOnServer(syncManager: syncManager, record: record, onComplete: onComplete, onFail: fail)
        }
    }

    /// Same request as the one of `SyncUpTarget` for an upsert, with the external id value encoded in the path.
    @objc(upsertOnServer:fields:externalId:completionBlock:failBlock:)
    func upsertOnServer(_ objectType: String,
                        fields: NSDictionary,
                        externalId: String,
                        completionBlock: @escaping ([AnyHashable: Any]?) -> Void,
                        failBlock: @escaping (NSError?) -> Void) {
        let request = RestClient.shared.requestForUpsert(withObjectType: objectType,
                                                         externalIdField: externalIdFieldName,
                                                         externalId: QueueSyncUpTarget.pathEncoded(externalId),
                                                         fields: fields as? [String: Any] ?? [:],
                                                         apiVersion: nil)
        NetworkUtils.sendRequest(withMobileSyncUserAgent: request) { _, error, _ in
            failBlock(error as NSError?)
        } successBlock: { response, _ in
            completionBlock(response as? [AnyHashable: Any])
        }
    }

    private static func pathEncoded(_ value: String) -> String {
        return value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))) ?? value
    }

    /// `GET /sobjects/<type>/<externalIdField>/<value>?fields=Id`: gets the server id of the record that an upsert updated.
    /// Calls `onComplete` with `["id": <Id>]`, or with the response as it is when it has no `Id`.
    @objc func lookupIdOnServer(_ objectType: String,
                                externalIdField: String,
                                externalId: String,
                                onComplete: @escaping ([AnyHashable: Any]?) -> Void,
                                onFail: @escaping (NSError) -> Void) {
        let encoded = QueueSyncUpTarget.pathEncoded(externalId)
        let request = RestClient.shared.requestForRetrieve(withObjectType: objectType, objectId: "\(externalIdField)/\(encoded)", fieldList: idFieldName, apiVersion: nil)
        NetworkUtils.sendRequest(withMobileSyncUserAgent: request) { response, error, _ in
            onFail((error ?? QueueSyncUpTarget.recordError("The id lookup failed")) as NSError)
        } successBlock: { response, _ in
            if let id = (response as? [AnyHashable: Any])?[self.idFieldName] as? String, QueueSyncUpTarget.isNonBlank(id) {
                onComplete([kCreatedId: id])
            } else {
                onComplete(response as? [AnyHashable: Any])
            }
        }
    }

    /// The external id value if `entry` is a create that this target sends as an upsert (an upsert can update any
    /// existing record of the object type).
    func upsertExternalId(of entry: QueueEntry) -> String? {
        guard let field = upsertField(of: entry),
              let value = entry.changes[field] as? String, QueueSyncUpTarget.isNonBlank(value), !SyncTarget.isLocalId(value) else {
            return nil
        }
        return value
    }

    /// The external id field if `entry` is a create sent as an upsert.
    func upsertField(of entry: QueueEntry) -> String? {
        guard entry.kind == .create,
              let field = value(forKey: "externalIdFieldName") as? String, !field.isEmpty else { return nil }
        return field
    }

    /// Whether a server id has content (a whitespace-only string is not an id).
    static func isNonBlank(_ id: String) -> Bool {
        return !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: Errors

    /// Domain of the HTTP errors of the REST client; `code` is the HTTP status.
    private static var restErrorDomain: String { return SFRestErrorDomain }

    static func recordError(_ message: String) -> NSError {
        return NSError(domain: kSFMobileSyncErrorDomain, code: LocalWriteError.invalidRecord.rawValue, userInfo: [NSLocalizedDescriptionKey: message])
    }

    /// Whether a failed request is a transport error, which fails the sync (the entry stays at the head of the queue
    /// and the next sync retries it). Record-level errors, which only fail their entry, are the errors of this target
    /// and the HTTP errors below 500 that are not 401, 408, 429 or `REQUEST_LIMIT_EXCEEDED`. Everything else is transport:
    /// no response, authentication failure, cancelled request, unparseable response, HTTP 401, 408, 429 and 500 and above.
    static func isTransportError(_ error: NSError) -> Bool {
        if error.domain == kSFMobileSyncErrorDomain {
            return false
        }
        guard error.domain == restErrorDomain, !RestRequest.isNetworkError(error) else {
            return true
        }
        return error.code >= 500 || error.code == 401 || error.code == 408 || error.code == 429 || describeJson(error.userInfo).contains("REQUEST_LIMIT_EXCEEDED")
    }

    /// Whether the server answered that the record does not exist.
    static func isNotFound(_ error: NSError) -> Bool {
        return error.domain == restErrorDomain && error.code == 404
    }

    /// The error of a failed request as JSON-compatible data: the parsed error body (`userInfo`) or the message.
    static func lastError(_ error: NSError) -> [String: Any] {
        var result = jsonSafe(error.userInfo) as? [String: Any] ?? [:]
        if result.isEmpty {
            result["message"] = error.localizedDescription
        }
        return result
    }

    private static func describeJson(_ value: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: jsonSafe(value), options: [.fragmentsAllowed]) else {
            return String(describing: value)
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// Converts a value to JSON-compatible data (anything that is not JSON becomes its description).
    static func jsonSafe(_ value: Any) -> Any {
        switch value {
        case let dict as [AnyHashable: Any]:
            return Dictionary(uniqueKeysWithValues: dict.map { (String(describing: $0.key), jsonSafe($0.value)) })
        case let array as [Any]:
            return array.map { jsonSafe($0) }
        case is NSNull, is NSNumber, is String:
            return value
        default:
            return String(describing: value)
        }
    }

    // MARK: Temp-id remapping

    /// Applies the `localId -> serverId` map to an entry: `recordId`, `parentRef` and the top-level string values of
    /// `changes` that are exactly a known local id. Unknown local ids are left as they are.
    /// - Returns: the new raw entry, or nil if nothing changes.
    static func remapped(_ raw: [String: Any], using idMap: [String: String]) -> [String: Any]? {
        return remapped(raw, own: idMap, refs: idMap)
    }

    /// Same as `remapped(_:using:)` with two maps: `own` applies to the entry's own `recordId` (the replayed create lives
    /// in the soup of the entry only), `refs` to `parentRef` and `changes` values (local ids are unique store-wide).
    static func remapped(_ raw: [String: Any], own: [String: String], refs: [String: String]) -> [String: Any]? {
        guard !own.isEmpty || !refs.isEmpty else { return nil }
        var result = raw
        var changed = false
        if let value = raw[SyncQueue.recordIdField] as? String, SyncTarget.isLocalId(value), let serverId = own[value] {
            result[SyncQueue.recordIdField] = serverId
            changed = true
        }
        if let value = raw[SyncQueue.parentRefField] as? String, SyncTarget.isLocalId(value), let serverId = refs[value] {
            result[SyncQueue.parentRefField] = serverId
            changed = true
        }
        if var changes = raw[SyncQueue.changesField] as? [String: Any] {
            for (field, value) in changes {
                if let string = value as? String, SyncTarget.isLocalId(string), let serverId = refs[string] {
                    changes[field] = serverId
                    changed = true
                }
            }
            result[SyncQueue.changesField] = changes
        }
        return changed ? result : nil
    }
}

private extension Optional where Wrapped == Bool {
    var orFalse: Bool { return self ?? false }
}
