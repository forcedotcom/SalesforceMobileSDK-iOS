# MobileSync — Salesforce Mobile SDK for iOS

This document covers the MobileSync library in `libs/MobileSync`. Classes are prefixed with `SF` (Obj-C) or live in the `MobileSync` Swift module.

For cross-platform concepts (architecture, data flows, conflict resolution) see the [workspace-level MobileSync doc](../../../SalesforceMobileSDK-Workspace/docs/mobilesync/README.md).

---

## Table of Contents

1. [File Structure](#file-structure)
2. [SFMobileSyncSyncManager](#sfmobilesyncsyncmanager)
3. [SFSyncState](#sfsyncstate)
4. [SFSyncOptions](#sfsyncoptions)
5. [Sync-Down Targets](#sync-down-targets)
6. [Sync-Up Targets](#sync-up-targets)
7. [Sync-Up Queue and Local Write API](#sync-up-queue-and-local-write-api)
8. [Layout and Metadata Sync](#layout-and-metadata-sync)
9. [Swift Extensions and Combine Support](#swift-extensions-and-combine-support)
10. [JSON-Driven Configuration](#json-driven-configuration)
11. [Testing](#testing)

---

## File Structure

```
libs/MobileSync/Classes/
├── Manager/           SFMobileSyncSyncManager, task classes, LayoutSyncManager, MetadataSyncManager
├── Target/            All sync target classes
├── Model/             SFLayout, SFMetadata, SFObject, SFMobileSyncPersistableObject
├── Config/            SFSDKSyncsConfig
├── Util/              SFSyncState, SFSyncOptions, SFParentInfo, SFChildrenInfo,
│                      BriefcaseObjectInfo, SFSDKSoqlMutator, SFMobileSyncConstants,
│                      SyncQueue (Swift)
├── BatchSyncUpTarget.swift
├── CollectionSyncUpTarget.swift
├── Target/QueueSyncUpTarget.swift   (replays the sync-up queue)
├── Manager/QueueSyncUpTask.swift    (task run for QueueSyncUpTarget)
└── SyncTarget.swift   (Swift helpers on SyncDownTarget)
Extensions/
├── MobileSync.swift   (Swift/Combine extensions on SFMobileSyncSyncManager)
└── SyncManager+LocalWrite.swift   (createLocal / updateLocal / deleteLocal)
```

---

## SFMobileSyncSyncManager

`Manager/SFMobileSyncSyncManager.h`

Central coordinator. One instance per user + SmartStore. Work is dispatched on a serial queue (`com.salesforce.mobilesync.manager.syncmanager.QUEUE`).

### Singleton Access

```objc
+ (instancetype)sharedInstance:(SFUserAccount *)user;

+ (instancetype)sharedInstanceForStore:(nullable NSString *)storeName
                           userAccount:(SFUserAccount *)userAccount;

+ (nullable instancetype)sharedInstanceForStore:(SFSmartStore *)store;
```

### Manager State Machine

```objc
typedef NS_ENUM(NSInteger, SFSyncManagerState) {
    SFSyncManagerStateAcceptingSyncs,  // normal
    SFSyncManagerStateStopRequested,   // stop called, active syncs finishing
    SFSyncManagerStateStopped          // all active syncs done
};
```

`stop:` → `StopRequested`. Each active task checks `shouldStop` and moves its sync to `STOPPED`. When the last active sync finishes, the manager moves to `Stopped`.

`restart:restartStoppedSyncs:updateBlock:error:` → back to `AcceptingSyncs`. Pass `restartStoppedSyncs=YES` to automatically re-run all `STOPPED` syncs.

### Key Sync Methods

```objc
// Create without running
- (SFSyncState *)createSyncDown:(SFSyncDownTarget *)target
                        options:(SFSyncOptions *)options
                       soupName:(NSString *)soupName
                       syncName:(nullable NSString *)syncName;

// Create and run
- (nullable SFSyncState *)syncDownWithTarget:(SFSyncDownTarget *)target
                                     options:(SFSyncOptions *)options
                                    soupName:(NSString *)soupName
                                    syncName:(nullable NSString *)syncName
                                 updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock
                                       error:(NSError **)error;

- (nullable SFSyncState *)syncUpWithTarget:(SFSyncUpTarget *)target
                                   options:(SFSyncOptions *)options
                                  soupName:(NSString *)soupName
                                  syncName:(nullable NSString *)syncName
                               updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock
                                     error:(NSError **)error;

// Re-run (incremental)
- (nullable SFSyncState *)reSync:(NSNumber *)syncId
                     updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock
                           error:(NSError **)error;

- (nullable SFSyncState *)reSyncByName:(NSString *)syncName
                           updateBlock:(SFSyncSyncManagerUpdateBlock)updateBlock
                                 error:(NSError **)error;

// Ghost cleanup
- (BOOL)cleanResyncGhosts:(NSNumber *)syncId
     completionStatusBlock:(SFSyncSyncManagerCompletionStatusBlock)completionStatusBlock
                     error:(NSError **)error;
```

Block type:
```objc
typedef void (^SFSyncSyncManagerUpdateBlock)(SFSyncState *sync);
typedef void (^SFSyncSyncManagerCompletionStatusBlock)(SFSyncStateStatus syncStatus, NSInteger numRecords);
```

### Query / Management

```objc
- (nullable SFSyncState *)getSyncStatus:(NSNumber *)syncId;
- (nullable SFSyncState *)getSyncStatusByName:(NSString *)name;
- (BOOL)hasSyncWithName:(NSString *)name;
- (void)deleteSync:(NSNumber *)syncId;
- (void)deleteSyncByName:(NSString *)name;
```

### Error Constants

| Constant | Meaning |
|---|---|
| `kSFSyncManagerStoppedError` | Manager not accepting syncs |
| `kSFSyncManagerCannotRestartError` | Restart failed |
| `kSFSyncAlreadyRunningError` | Sync already in progress |
| `kSFSyncNotExistError` | No sync with given id/name |
| `kSFSyncManagerCanOnlyRunCleanGhostsForSyncDown` | Ghost cleanup attempted on a sync-up |

---

## SFSyncState

`Util/SFSyncState.h`

Persisted as entries in `syncs_soup` (JSON1 indexes on `type`, `name`, `status`).

### Key Properties

```objc
@property (nonatomic, readonly) NSInteger syncId;
@property (nonatomic, strong, readonly) NSString *name;          // nil for anonymous syncs
@property (nonatomic, readonly) SFSyncStateSyncType type;        // syncDown | syncUp
@property (nonatomic, strong, readonly) NSString *soupName;
@property (nonatomic, strong, readonly) SFSyncTarget *target;
@property (nonatomic, strong, readonly) SFSyncOptions *options;
@property (nonatomic) SFSyncStateStatus status;
@property (nonatomic) NSInteger progress;                        // 0–100
@property (nonatomic) NSInteger totalSize;                       // −1 until known
@property (nonatomic) long long maxTimeStamp;                    // epoch ms; incremental sync watermark
@property (nonatomic, readonly) NSInteger startTime;
@property (nonatomic, readonly) NSInteger endTime;
@property (nonatomic) NSString *error;                           // JSON string
```

`mergeMode` is a computed property delegating to `self.options.mergeMode`.

### Status Enum

```objc
typedef NS_ENUM(NSInteger, SFSyncStateStatus) {
    SFSyncStateStatusNew,
    SFSyncStateStatusRunning,
    SFSyncStateStatusDone,
    SFSyncStateStatusFailed,
    SFSyncStateStatusStopped
};
```

`NEW` → `RUNNING` → `DONE` / `FAILED` / `STOPPED`  
`STOPPED` → `RUNNING` (via `reSync`)

### Merge Mode Enum

```objc
typedef NS_ENUM(NSInteger, SFSyncStateMergeMode) {
    SFSyncStateMergeModeOverwrite,
    SFSyncStateMergeModeLeaveIfChanged
};
```

### Factory and Lookup

```objc
+ (SFSyncState *)newSyncDownWithOptions:(SFSyncOptions *)options
                                 target:(SFSyncDownTarget *)target
                               soupName:(NSString *)soupName
                                   name:(nullable NSString *)name
                                  store:(SFSmartStore *)store;

+ (SFSyncState *)newSyncUpWithOptions:(SFSyncOptions *)options
                               target:(SFSyncUpTarget *)target
                             soupName:(NSString *)soupName
                                 name:(nullable NSString *)name
                                store:(SFSmartStore *)store;

+ (nullable SFSyncState *)byId:(NSNumber *)syncId store:(SFSmartStore *)store;
+ (nullable SFSyncState *)byName:(NSString *)name store:(SFSmartStore *)store;

+ (void)setupSyncsSoupIfNeeded:(SFSmartStore *)store;
+ (void)cleanupSyncsSoupIfNeeded:(SFSmartStore *)store;  // RUNNING → STOPPED on startup
```

---

## SFSyncOptions

`Util/SFSyncOptions.h`

```objc
@property (nonatomic, strong, readonly) NSArray *fieldlist;          // sync-up fields
@property (nonatomic, readonly) SFSyncStateMergeMode mergeMode;
```

### Factory Methods

```objc
+ (SFSyncOptions *)newSyncOptionsForSyncDown:(SFSyncStateMergeMode)mergeMode;
+ (SFSyncOptions *)newSyncOptionsForSyncUp:(NSArray *)fieldlist;
+ (SFSyncOptions *)newSyncOptionsForSyncUp:(NSArray *)fieldlist
                                 mergeMode:(SFSyncStateMergeMode)mergeMode;
```

---

## Sync-Down Targets

### Target Class Hierarchy

```
SFSyncDownTarget (abstract)
├── SFSoqlSyncDownTarget
│   └── SFParentChildrenSyncDownTarget
├── SFSoslSyncDownTarget
├── SFMruSyncDownTarget
├── SFRefreshSyncDownTarget
├── BriefcaseSyncDownTarget   (Swift)
├── SFLayoutSyncDownTarget
└── SFMetadataSyncDownTarget
```

Custom targets: add `iOSImpl` key to the target JSON with the Obj-C class name. `SFSyncDownTarget.newFromDict:` uses it for deserialization.

### Dirty-Flag Constants (on all soup records)

| Constant | Field | Meaning |
|---|---|---|
| `kSyncTargetLocal` | `__local__` | Has unsynchronized changes |
| `kSyncTargetLocallyCreated` | `__locally_created__` | Created offline |
| `kSyncTargetLocallyUpdated` | `__locally_updated__` | Updated offline |
| `kSyncTargetLocallyDeleted` | `__locally_deleted__` | Pending deletion |
| `kSyncTargetSyncId` | `__sync_id__` | Which sync last wrote this record |
| `kSyncTargetLastError` | `__last_error__` | Last server error JSON |

---

### SFSoqlSyncDownTarget

```objc
+ (instancetype)newSyncTarget:(NSString *)query;
+ (instancetype)newSyncTarget:(NSString *)query maxBatchSize:(NSInteger)maxBatchSize;
+ (instancetype)newSyncTargetWithIdFieldName:(NSString *)idFieldName
                    modificationDateFieldName:(NSString *)modificationDateFieldName
                                        query:(NSString *)query
                                 maxBatchSize:(NSInteger)maxBatchSize;
```

Query is auto-mutated at construction: `Id`, `LastModifiedDate`, and an ORDER BY clause are injected if absent.

`isSyncDownSortedByLatestModification` returns `YES` when ORDER BY is `LastModifiedDate`. When `YES`, `SFSyncDownTask` updates `maxTimeStamp` incrementally per page.

**reSync filter:**
```objc
+ (NSString *)addFilterForReSync:(NSString *)query
                modDateFieldName:(NSString *)modDateFieldName
                    maxTimeStamp:(long long)maxTimeStamp;
// Appends: WHERE/AND LastModifiedDate > <ISO8601>
```

---

### SFSoslSyncDownTarget

```objc
+ (instancetype)newSyncTarget:(NSString *)query;
```

One-shot — no pagination, no incremental timestamp.

---

### SFMruSyncDownTarget

```objc
+ (instancetype)newSyncTarget:(NSArray *)fieldlist objectType:(NSString *)objectType;
```

Fetches `recentItems` from `/sobjects/<objectType>` describe, then runs SOQL `WHERE Id IN (...)`. No incremental sync.

---

### SFRefreshSyncDownTarget

```objc
+ (instancetype)newSyncTarget:(NSArray *)fieldlist
                   objectType:(NSString *)objectType
                     soupName:(NSString *)soupName;

+ (instancetype)newSyncTarget:(NSArray *)fieldlist
                   objectType:(NSString *)objectType
                     soupName:(NSString *)soupName
              countIdsPerSoql:(NSUInteger)countIdsPerSoql;  // default 500
```

Paginates local IDs. First run fetches all; `reSync` fetches only records changed since the local max timestamp.

---

### BriefcaseSyncDownTarget (Swift)

```swift
@objc(SFBriefcaseSyncDownTarget)
public class BriefcaseSyncDownTarget: SyncDownTarget {
    @objc public init(infos: [BriefcaseObjectInfo])
}
```

`BriefcaseObjectInfo` fields: `sobjectType`, `fieldlist`, `idFieldName`, `modificationDateFieldName`, `soupName`.

Uses `/connect/briefcase/priming-records` with relay-token pagination. `totalSize` is an estimate: the number of ids discovered so far, plus one while the server has more pages, so the sync only completes once the target has returned its last page (`SFSyncDownTask` re-reads `target.totalSize` after each fetch). Fetches full records via Collection Retrieve. Routes records to different soups based on `attributes.type`. Ghost cleanup paginates the priming API without a timestamp filter.

---

### SFParentChildrenSyncDownTarget

```objc
+ (instancetype)newSyncTargetWithParentInfo:(SFParentInfo *)parentInfo
                            parentFieldlist:(NSArray<NSString *> *)parentFieldlist
                           parentSoqlFilter:(NSString *)parentSoqlFilter
                               childrenInfo:(SFChildrenInfo *)childrenInfo
                          childrenFieldlist:(NSArray<NSString *> *)childrenFieldlist
                           relationshipType:(SFParentChildrenRelationshipType)relationshipType;
```

`SFParentInfo` properties: `sobjectType`, `soupName`, `idFieldName`, `modificationDateFieldName`, `externalIdFieldName`.

`SFChildrenInfo` extends `SFParentInfo` with: `sobjectTypePlural`, `parentIdFieldName`.

Generates a nested SOQL with a subquery and a semi-join reSync filter. Saves parents and children to separate soups in one transaction.

`SFParentChildrenRelationshipType` enum: `SFParentChildrenRelationshipTypeLookup`, `SFParentChildrenRelationshipTypeMasterDetail`.

---

### SFLayoutSyncDownTarget

```objc
+ (instancetype)newSyncTarget:(NSString *)objectAPIName
                   formFactor:(nullable NSString *)formFactor
                   layoutType:(nullable NSString *)layoutType
                         mode:(nullable NSString *)mode
                 recordTypeId:(nullable NSString *)recordTypeId;
```

Fetches `/ui-api/layout/<objectAPIName>`. SmartStore key: `"<objectAPIName>-<formFactor>-<layoutType>-<mode>-<recordTypeId>"`. Ghost cleanup is a no-op.

---

### SFMetadataSyncDownTarget

```objc
+ (instancetype)newSyncTarget:(NSString *)objectType;
```

Fetches `/sobjects/<objectType>/describe`. SmartStore key = `objectType`. Ghost cleanup is a no-op.

---

## Sync-Up Targets

### Target Class Hierarchy

```
SFSyncUpTarget (base, Obj-C)
├── SFBatchSyncUpTarget    (Composite Batch API; max 25/call; Obj-C + Swift)
│   └── CollectionSyncUpTarget  (Collections API; max 200/call; Swift) ← DEFAULT
└── SFParentChildrenSyncUpTarget  (one parent-tree per Composite Batch; Obj-C)

SFAdvancedSyncUpTarget (protocol) — adopted by all three above
```

`CollectionSyncUpTarget` is the default when the target JSON has no `iOSImpl` key.

---

### SFSyncUpTarget

`Target/SFSyncUpTarget.h`

```objc
@property (nonatomic, strong, readonly) NSArray<NSString*> *createFieldlist;
@property (nonatomic, strong, readonly) NSArray<NSString*> *updateFieldlist;
@property (nonatomic, copy) NSString *externalIdFieldName;   // enables upsert

+ (instancetype)newSyncTarget;
+ (instancetype)newSyncTargetWithCreateFieldlist:(nullable NSArray *)createFieldlist
                                 updateFieldlist:(nullable NSArray *)updateFieldlist;
```

Server operations (overrideable):

```objc
- (void)createOnServer:(SFMobileSyncSyncManager *)syncManager
                record:(NSDictionary *)record
             fieldlist:(NSArray *)fieldlist
       completionBlock:(SFSyncUpTargetCompleteBlock)completionBlock
             failBlock:(SFSyncUpTargetErrorBlock)failBlock;

- (void)updateOnServer:(SFMobileSyncSyncManager *)syncManager
                record:(NSDictionary *)record
             fieldlist:(NSArray *)fieldlist
       completionBlock:(SFSyncUpTargetCompleteBlock)completionBlock
             failBlock:(SFSyncUpTargetErrorBlock)failBlock;

- (void)deleteOnServer:(SFMobileSyncSyncManager *)syncManager
                record:(NSDictionary *)record
       completionBlock:(SFSyncUpTargetCompleteBlock)completionBlock
             failBlock:(SFSyncUpTargetErrorBlock)failBlock;
```

If `externalIdFieldName` is set and has a non-local server ID value, `createOnServer:` uses `PATCH /sobjects/<Type>/<extIdField>/<value>` (upsert).

Conflict detection:

```objc
- (void)isNewerThanServer:(SFMobileSyncSyncManager *)syncManager
                   record:(NSDictionary *)record
              resultBlock:(SFSyncUpRecordNewerThanServerBlock)resultBlock;
// resultBlock: ^(BOOL isNewerThanServer)
```

Returns `YES` (proceed) for locally created records, when local mod date is nil, or when local `LastModifiedDate >= server LastModifiedDate`.

---

### SFAdvancedSyncUpTarget Protocol

```objc
@protocol SFAdvancedSyncUpTarget <NSObject>
@property (nonatomic, assign, readonly) NSUInteger maxBatchSize;
- (void)syncUpRecords:(SFMobileSyncSyncManager *)syncManager
              records:(NSArray *)records
            fieldlist:(NSArray *)fieldlist
            mergeMode:(SFSyncStateMergeMode)mergeMode
         syncSoupName:(NSString *)syncSoupName
      completionBlock:(SFSyncUpTargetCompleteBlock)completionBlock
            failBlock:(SFSyncUpTargetErrorBlock)failBlock;
@end
```

---

### SFBatchSyncUpTarget

```objc
+ (instancetype)newSyncTarget;
+ (instancetype)newSyncTargetWithCreateFieldlist:(nullable NSArray *)createFieldlist
                                 updateFieldlist:(nullable NSArray *)updateFieldlist;
+ (instancetype)newSyncTargetWithCreateFieldlist:(nullable NSArray *)createFieldlist
                                 updateFieldlist:(nullable NSArray *)updateFieldlist
                                    maxBatchSize:(NSUInteger)maxBatchSize;
```

Uses `/composite/batch`. Max batch size: 25.

---

### CollectionSyncUpTarget (Swift)

```swift
@objc(SFCollectionSyncUpTarget)
public class CollectionSyncUpTarget: BatchSyncUpTarget {
    @objc public override class func newSyncTarget() -> Self
    @objc public override class func newSyncTarget(
        createFieldlist: [String]?,
        updateFieldlist: [String]?
    ) -> Self
}
```

Default target. Groups requests by operation type and sends each group via `/composite/sobjects`. Max batch size: 200.

Overrides `areNewerThanServer:` to batch-fetch `LastModifiedDate` via Collection Retrieve.

---

### SFParentChildrenSyncUpTarget

```objc
+ (instancetype)newSyncTargetWithParentInfo:(SFParentInfo *)parentInfo
                     parentCreateFieldlist:(NSArray<NSString*>*)parentCreateFieldlist
                     parentUpdateFieldlist:(NSArray<NSString*>*)parentUpdateFieldlist
                              childrenInfo:(SFChildrenInfo *)childrenInfo
                   childrenCreateFieldlist:(NSArray<NSString*>*)childrenCreateFieldlist
                   childrenUpdateFieldlist:(NSArray<NSString*>*)childrenUpdateFieldlist
                          relationshipType:(SFParentChildrenRelationshipType)relationshipType;
```

Max batch size: 1 (one parent + children per request). Uses `@{refId.id}` substitution for child creates referencing a new parent's server ID.

`isNewerThanServer:` checks parent and all children timestamps in a single SOQL.

#### Fieldlist Configuration

Both the parent and children fieldlists passed to `SFParentChildrenSyncUpTarget` must contain only **user-writable fields**. Salesforce will reject the Composite API request with `INVALID_FIELD_FOR_INSERT_UPDATE` if any of the following system/audit fields are included:

- `Id`
- `CreatedDate`
- `LastModifiedDate`
- `SystemModstamp`
- `IsDeleted`

**The child's `parentIdFieldName` must not appear in `childrenCreateFieldlist`.** When a child record is being created alongside a new parent, the SDK injects the parent reference automatically using `@{refId.id}` substitution in the Composite API request body. This tells Salesforce to resolve the child's lookup field to the server-assigned ID of the just-created parent record. If you also include that field name explicitly in `childrenCreateFieldlist`, the request will contain a conflicting explicit value alongside the reference substitution, and Salesforce will return `INVALID_FIELD_FOR_INSERT_UPDATE`.

The `parentIdFieldName` **may** appear in `childrenUpdateFieldlist` when updating existing child records (where no reference substitution is used), provided the field is user-writable in that context.

**Example — Account (parent) + Contact (child)**

```objc
// CORRECT
SFParentInfo *parentInfo = [SFParentInfo newWithSObjectType:@"Account"
                                                   soupName:@"accounts"
                                                      idFieldName:@"Id"
                                         modificationDateFieldName:@"LastModifiedDate"
                                                        externalIdFieldName:nil];

SFChildrenInfo *childrenInfo = [SFChildrenInfo newWithSObjectType:@"Contact"
                                                   soupName:@"contacts"
                                          parentIdFieldName:@"AccountId"  // lookup to Account
                                                idFieldName:@"Id"
                                   modificationDateFieldName:@"LastModifiedDate"];

// AccountId is intentionally absent from childrenCreateFieldlist — the SDK substitutes it automatically.
SFParentChildrenSyncUpTarget *target =
    [SFParentChildrenSyncUpTarget newSyncTargetWithParentInfo:parentInfo
                                         parentCreateFieldlist:@[@"Name", @"BillingCity"]     // no Id, CreatedDate, etc.
                                         parentUpdateFieldlist:@[@"Name", @"BillingCity"]
                                                  childrenInfo:childrenInfo
                                       childrenCreateFieldlist:@[@"LastName", @"FirstName"]   // AccountId omitted
                                       childrenUpdateFieldlist:@[@"LastName", @"FirstName", @"AccountId"]
                                              relationshipType:SFParentChildrenRelationshipTypeMasterDetail];

// INCORRECT — causes INVALID_FIELD_FOR_INSERT_UPDATE
// childrenCreateFieldlist:@[@"LastName", @"FirstName", @"AccountId"]  // AccountId must NOT be here
```

**Summary of rules:**

| Fieldlist | Exclude system fields | Exclude `parentIdFieldName`? |
|---|---|---|
| `parentCreateFieldlist` | Yes (`Id`, `CreatedDate`, `LastModifiedDate`, `SystemModstamp`, `IsDeleted`) | N/A |
| `parentUpdateFieldlist` | Yes | N/A |
| `childrenCreateFieldlist` | Yes | **Yes — always** |
| `childrenUpdateFieldlist` | Yes | No (optional, if user-writable) |

---

## Sync-Up Queue and Local Write API

The sync manager can record local changes in an ordered queue, one entry per change, for any number of record soups. `QueueSyncUpTarget` (see [Replaying the Queue](#replaying-the-queue-queuesyncuptarget)) replays the queue in the order the changes were made and with only the fields that changed. The flag-based sync-up targets do not read the queue, and apps that never call the write API are unaffected.

### Queue Soup (`mobilesync_queue`)

`SFSDKSyncQueue` (Swift, `Util/SyncQueue.swift`) registers the soup `mobilesync_queue` in a store when the sync manager of that store is created, next to the syncs soup (`+[SFSDKSyncQueue setupQueueSoupIfNeeded:]`). If the soup exists with index paths or types that differ from the expected ones it is altered with re-indexing. The only visible effect for an app that does not use the write API is an empty soup.

| Path | Index type | Content |
|---|---|---|
| `sequence` | integer | Global order of the entries, across all record soups |
| `soupName` | string | Soup that holds the record |
| `recordId` | string | `Id` of the record (local id or server id) |
| `sobjectType` | string | `attributes.type` of the record |
| `kind` | string | `CREATE`, `UPDATE` or `DELETE` |
| `changes` | json1 | Changed fields and their new values (all non-internal fields for `CREATE`, absent for `DELETE`) |
| `base` | json1 | Reserved, not written yet |
| `status` | string | `PENDING` or `PARKED` (new entries are `PENDING`) |
| `lastError` | json1 | Last replay error (record-level or transport), written by the replay; absent until an error happens |
| `attempts` | integer | Number of failed replay attempts (starts at 0; the replay adds 1 on a record-level or transport error, not when an entry is deferred) |
| `parentRef` | string | Not written by the write API. If present it names a record the entry depends on: the replay defers the entry while that record is blocked, and rewrites it when the record's temp id is replaced |

`sequence` is allocated inside the write transaction as `MAX(sequence) + 1` (1 for an empty queue), so it is unique and monotonic across record soups, and a rolled-back write does not use a number.

### Local Write API

Extension of `SyncManager` (`SFMobileSyncSyncManager`) in `Extensions/SyncManager+LocalWrite.swift`. All three calls are synchronous and run in one SmartStore transaction (`performTransaction`): the record write and the queue entry both happen or neither does.

```swift
func createLocal(soupName: String, record: [String: Any]) throws -> [String: Any]
func updateLocal(soupName: String, id: String, changes: [String: Any]) throws -> [String: Any]
func deleteLocal(soupName: String, id: String) throws -> [String: Any]
```

```objc
// Objective-C selectors
- (NSDictionary *)createLocalInSoup:(NSString *)soupName record:(NSDictionary *)record error:(NSError **)error;
- (NSDictionary *)updateLocalInSoup:(NSString *)soupName id:(NSString *)id changes:(NSDictionary *)changes error:(NSError **)error;
- (NSDictionary *)deleteLocalInSoup:(NSString *)soupName id:(NSString *)id error:(NSError **)error;
```

| Call | Record | Flags | Queue entry |
|---|---|---|---|
| `createLocal` | Inserted (never overwrites). `Id` is the given local id, or a new local id | `__local__` and `__locally_created__` true; `__locally_updated__` and `__locally_deleted__` false; `__last_error__` removed | `CREATE`, `changes` = all fields except the internal ones |
| `updateLocal` | `changes` merged into the stored record | `__local__` and `__locally_updated__` true; `__locally_created__` is kept | `UPDATE`, `changes` = the given fields only |
| `deleteLocal` | Kept in its soup (soft delete) | `__local__` and `__locally_deleted__` true | `DELETE`, no `changes` |

Rules:
- The soup must exist and have an index on `Id`. The flags (`__local__`, `__locally_created__`, `__locally_updated__`, `__locally_deleted__`) should be **string** indexes in the record soup, as in all MobileSync soups, for sync-down skip logic and the flag-based sync up to work. The write API stores the flags as booleans and does not check their indexes.
- `createLocal` needs the object type in `attributes.type`. It rejects a record with an `Id` that is not a local id, with an `Id` that already exists, with a `_soup*` key, or with values that cannot be serialized to JSON. The dictionary passed in is not modified.
- `updateLocal` and `deleteLocal` accept a locally created record or a record that came from sync down (server id). They fail if the record does not exist or is already flagged deleted.
- Internal fields are never part of `changes` and are rejected in the `changes` of `updateLocal`: `Id`, `attributes`, `_soup*` keys, the four dirty flags, `__last_error__`, `__sync_id__`, `__display__`. `changes` must not be empty. To clear a field, pass `NSNull()` (`[NSNull null]`).
- A record soup must use either the queue or flag-based sync up, never both. The write API sets the same dirty flags that flag-based sync-up targets read, and `QueueSyncUpTarget` (below) replays the queue and ignores the flags, so mixing them on one soup gives inconsistent results (unsupported).
- `__display__` is neither written nor refreshed.
- The calls do not check whether the sync manager is stopped (they are local writes, not syncs). They block while holding the store, so do not use them from the main thread for large volumes.

Errors are `NSError`s in `kSFMobileSyncErrorDomain`, with a localized description. Nothing is written when a call fails.

| Code | Meaning |
|---|---|
| 905 | Soup does not exist |
| 906 | Soup has no index on `Id` |
| 907 | Invalid record (`createLocal`): no object type, `_soup*` key, or not serializable to JSON |
| 908 | `createLocal`: `Id` is present and is not a local id |
| 909 | `createLocal`: a record with this `Id` already exists, or the `Id` is used by a record or queue entry of another soup (local ids are unique store-wide) |
| 910 | Record not found |
| 911 | More than one record with this `Id` |
| 912 | Record is already flagged deleted |
| 913 | Invalid `changes`: empty, internal field, or not serializable to JSON |
| 914 | Store failure (the write did not produce a record) |

Other failures (for example a SmartStore error that makes the transaction fail) are returned as the underlying `NSError`.

### Replaying the Queue (`QueueSyncUpTarget`)

A queue sync is a normal sync up whose target is `QueueSyncUpTarget` and whose soup name is `SyncQueue.soupName` (`mobilesync_queue`). `SFMobileSyncSyncManager` runs it with `QueueSyncUpTask` (`SFSyncTask.h` is now a public header so that Swift can subclass it).

```swift
let target = QueueSyncUpTarget()               // optionally: target.externalIdFieldName = "ExtId__c"
let options = SyncOptions.newSyncOptions(forSyncUp: [], mergeMode: .overwrite)   // fieldlist and merge mode are ignored
try syncManager.syncUp(target: target, options: options, soupName: SyncQueue.soupName, syncName: "queueSync") { sync in ... }
```

- Pending entries are replayed one at a time in `sequence` order (strict order, across soups). `PARKED` entries are skipped. `totalSize` is the number of pending entries at the start. The requests are built from the entry (`kind`, `sobjectType`, `changes`): `POST` for `CREATE` (or an upsert on `externalIdFieldName`), `PATCH` with only the changed fields for `UPDATE`, `DELETE` for `DELETE`. The dirty flags are not used: flagged records without an entry are never sent.
- Success: the entry is removed. If no other entry (pending or parked) for the record remains in the queue, the record is cleaned (the four flags false, `__last_error__` removed). Otherwise it stays dirty for the remaining entries and `__last_error__` is kept: `__local__` true, `__locally_created__` false, `__locally_updated__` true only if an `UPDATE` remains, `__locally_deleted__` unchanged (a pending `DELETE` stays flagged). The last replayed entry of a record cleans it. A deleted record is removed from its soup. A `DELETE` answered by 404 is a success.
- Upsert on `externalIdFieldName`: the external id value is in the path and the field is left out of the body (the server refuses it in both). A 201 carries the new `id`; on a live org a repeated upsert answers 200 with `{created: 0, id, success}`, so no lookup is needed. A 204 (if a server answers so) has no body: the id is read with `GET /sobjects/<type>/<externalIdField>/<value>?fields=Id` (value from the entry's `changes`, URL-encoded like in the upsert `PATCH` path), then the entry is completed like a normal create. A failing lookup is classified like any other request. A 300 (several matches) is a record-level error.
- Record-level error (HTTP 4xx, an entry with no object type or kind, a missing record or soup): `lastError` and `attempts` + 1 are written on the entry, `__last_error__` on the record, the entry stays `PENDING` at its place and the sync goes on with the next entry. The sync ends `DONE`.
- Transport error: `attempts` + 1 and `lastError` on the entry, the sync ends `FAILED` and the entry stays at the head of the queue. Running `reSync` (by id or name) resumes from the head. An error is record-level only if it is a MobileSync error (`kSFMobileSyncErrorDomain`) or a REST error with HTTP status below 500 other than 401, 408, 429 and `REQUEST_LIMIT_EXCEEDED`; everything else (no network, cancelled, OAuth errors, 401, 5xx, 408, 429) is a transport error. A 401 is sync-wide: the sync fails and the head entry keeps its `attempts` and `lastError`; the entries behind it are untouched.
- Deferral after a record-level error: for the rest of the run, every later entry for the same record (same `soupName` and `recordId`) is deferred, and so is every entry whose `parentRef` or top-level `changes` value is the id of a rejected or deferred record (so a `CREATE` that refers to a rejected `CREATE` waits too). A deferred entry stays `PENDING`: nothing is sent, `attempts` and `lastError` are unchanged. The sync goes on with the unrelated records and ends `DONE`. On the next run the rejected entry is again the first entry of its record, so an older edit is never sent after a newer one. While the run has a blocked entry, an upsert `CREATE` (one with `externalIdFieldName` and an external id value) resolves its destination first with `GET /sobjects/<type>/<field>/<value>?fields=Id` (no lookup is made when nothing is blocked). If the Id found is the `recordId` of a blocked entry of the same type, the `CREATE` is deferred. A 404, or an Id that is not blocked, means the upsert is sent as usual. A transport-class failure of the lookup fails the sync (the `CREATE` stays, `attempts` + 1, `lastError` set, nothing sent). A 2xx answer whose `Id` is blank (including whitespace only), missing or unparseable is a transport-class failure like the one above (the sync fails, the `CREATE` stays at the head with `attempts` + 1 and `lastError` set, nothing is sent). Any other 4xx answer (other than 404, for example 300 or 403) is inconclusive and the `CREATE` is deferred. A rejected upsert `CREATE` has no server id: later upsert `CREATE`s with the same object type, external id field and value are deferred without a lookup. After a rejected upsert `CREATE` the destination is looked up the same way (this is the only lookup made after a rejection): an Id found blocks that server record, a 404 blocks nothing more, a transport-class failure fails the sync (the `CREATE` keeps `attempts` + 1 and `lastError`), a 2xx answer with a blank, missing or unparseable Id fails the sync too (the rejection already counted as the one attempt), and any other 4xx answer is inconclusive: later entries of that object type with a server `recordId` are deferred. A server record is one record whichever soup holds its row: a rejected entry for a server id defers the later entries for that `(type, serverId)` in every soup. A blank id (empty or whitespace only) is never accepted as a server id: in a create response, an upsert lookup or a destination lookup it is a transport-class failure. A `CREATE` without an external id is never affected. A `DELETE` of a record that still has a local id sends nothing and is never deferred.
- One replay at a time per store: a queue sync started while another one runs on the same store waits until the first is `DONE`, `FAILED` or `STOPPED` (the gate is held through the last request and the local commit), then reads the queue as the first left it. This keeps two syncs from sending the same `CREATE`.
- Unexpected answer (a 2xx without the expected content, e.g. a create without id): treated like a transport error (`attempts` + 1, sync `FAILED`).

#### Temp-id remapping

A `createLocal` record has a local id. When its `CREATE` succeeds, the server id replaces the local id in one transaction: the record is rewritten in place (`Id` = server id, `__last_error__` removed, flags as described under Success: clean unless entries for the record remain); the pending entries of the same soup get their `recordId` rewritten, and the pending entries of any soup get `parentRef` and the top-level string values of `changes` that are exactly the local id (a lookup such as `AccountId`) rewritten; the replayed entry is removed. If another row of the soup already has the server id (for example after a sync down, or an upsert that updated an existing record), the duplicate is removed in the same transaction, and the pending `UPDATE` entries for that server id are applied over the surviving row in sequence order, so a newer local edit is not lost. The row stays dirty (locally updated, not created) while entries remain, and a pending `DELETE` marks it locally deleted again. Only exact top-level values are rewritten (not substrings and not nested values). The map of replaced ids is keyed by `(soupName, localId)`. If a `CREATE` fails, the entries that refer to its local id are deferred (see above), not sent. A `DELETE` of a record that still has a local id is not sent: the record is removed locally and all of its entries (the failed `CREATE`, any `UPDATE`, parked or not) are dropped. A `DELETE` that the server accepts (or answers 404) also removes every other entry of the record.

**Local ids are unique store-wide.** Because references (`parentRef`, `changes` values) are rewritten in all soups, `createLocal` rejects a caller-supplied `Id` that is already used by a record of any soup with an `Id` index or by a queue entry of another soup (error 909, nothing written). Generated local ids get the same check: `createLocal` retries (up to 100 times) when a generated id collides with a record or queue entry of another soup.

---

## Layout and Metadata Sync

### SFLayoutSyncManager

```objc
+ (instancetype)sharedInstanceForUser:(SFUserAccount *)user;
+ (instancetype)sharedInstanceForUser:(SFUserAccount *)user communityId:(nullable NSString *)communityId;

- (void)fetchLayoutForObjectAPIName:(NSString *)objectAPIName
                         formFactor:(nullable NSString *)formFactor
                         layoutType:(nullable NSString *)layoutType
                               mode:(nullable NSString *)mode
                       recordTypeId:(nullable NSString *)recordTypeId
                           syncMode:(SFSDKFetchMode)syncMode
                    completionBlock:(SFLayoutSyncCompletionBlock)completionBlock;
// completionBlock: ^(SFLayout *layout)
```

Uses soup `sfdcLayouts`.

### SFMetadataSyncManager

```objc
+ (instancetype)sharedInstanceForUser:(SFUserAccount *)user;

- (void)fetchMetadataForObject:(NSString *)objectType
                          mode:(SFSDKFetchMode)mode
               completionBlock:(SFMetadataSyncCompletionBlock)completionBlock;
// completionBlock: ^(SFMetadata *metadata)
```

Uses soup `sfdcMetadata`.

### SFSDKFetchMode

```objc
typedef NS_ENUM(NSInteger, SFSDKFetchMode) {
    SFSDKFetchModeCacheOnly,    // SmartStore only
    SFSDKFetchModeCacheFirst,   // SmartStore first; fall back to server
    SFSDKFetchModeServerFirst   // always sync from server first
};
```

---

## Swift Extensions and Combine Support

`Extensions/MobileSync.swift` adds Result-based and Combine-based APIs on `SFMobileSyncSyncManager`:

```swift
extension SFMobileSyncSyncManager {

    // Result-based callback (no update block)
    func reSyncWithoutUpdates(
        named syncName: String,
        _ completionBlock: @escaping (Result<SFSyncState, MobileSyncError>) -> Void
    )

    func cleanGhosts(
        named syncName: String,
        _ completionBlock: @escaping (Result<UInt, MobileSyncError>) -> Void
    )

    // Combine publishers
    func publisher(for syncName: String) -> Future<SFSyncState, MobileSyncError>
    func cleanGhostsPublisher(for syncName: String) -> Future<UInt, MobileSyncError>
}

enum MobileSyncError: Error {
    case notStarted(_ error: Error?)
    case stopped
    case failed(_ syncState: SFSyncState?)
    case unknown
}
```

---

## JSON-Driven Configuration

### SFSDKSyncsConfig

```objc
- (nullable instancetype)initWithResourceAtPath:(NSString *)path;
- (void)createSyncs:(SFSmartStore *)store;  // idempotent
- (BOOL)hasSyncs;
```

### MobileSyncSDKManager

```objc
- (void)setupGlobalSyncsFromDefaultConfig;  // reads globalsyncs.json → global store
- (void)setupUserSyncsFromDefaultConfig;    // reads usersyncs.json → current user store
```

Call these from the SDK post-launch action.

### JSON Format

```json
{
  "syncs": [
    {
      "syncType": "syncDown",
      "syncName": "myAccountsSync",
      "soupName": "accounts",
      "target": {
        "type": "soql",
        "query": "SELECT Id, Name, Phone FROM Account ORDER BY LastModifiedDate"
      },
      "options": { "mergeMode": "OVERWRITE" }
    },
    {
      "syncType": "syncUp",
      "syncName": "myAccountsUpSync",
      "soupName": "accounts",
      "target": { "type": "rest" },
      "options": {
        "fieldlist": ["Name", "Phone"],
        "mergeMode": "LEAVE_IF_CHANGED"
      }
    }
  ]
}
```

Target `type` values: `soql`, `sosl`, `mru`, `refresh`, `briefcase`, `parent_children`, `layout`, `metadata`, `custom`.

For custom targets, add `"iOSImpl": "MyTargetClassName"` — the class must extend `SFSyncDownTarget` or `SFSyncUpTarget`.

---

## Testing

MobileSync tests live in `libs/MobileSync/MobileSyncTests/`:

```bash
xcodebuild test -workspace SalesforceMobileSDK-iOS.xcworkspace \
    -scheme MobileSyncTests -destination 'platform=iOS Simulator,...'
```

Key test files: `SyncManagerTestCase.m`, `SyncDownTests.m`, `SyncUpTests.m`, `ParentChildrenSyncTests.m`, `BriefcaseSyncDownTests.swift`, `SyncQueueTests.swift`, `LocalWriteTests.swift`.

`SyncQueueTests`, `LocalWriteTests` and `QueueSyncUpTests` need no network or org login: plain `XCTestCase`s on a global store. `QueueSyncUpTests` intercepts the REST helper methods with a `QueueSyncUpTarget` subclass (`RecordingQueueTarget`).

Tests use `MockRestClient` / `MockRestResponse` to intercept REST calls without hitting a live org.
