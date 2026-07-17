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
7. [Layout and Metadata Sync](#layout-and-metadata-sync)
8. [Swift Extensions and Combine Support](#swift-extensions-and-combine-support)
9. [JSON-Driven Configuration](#json-driven-configuration)
10. [Testing](#testing)

---

## File Structure

```
libs/MobileSync/Classes/
├── Manager/           SFMobileSyncSyncManager, task classes, LayoutSyncManager, MetadataSyncManager
├── Target/            All sync target classes
├── Model/             SFLayout, SFMetadata, SFObject, SFMobileSyncPersistableObject
├── Config/            SFSDKSyncsConfig
├── Util/              SFSyncState, SFSyncOptions, SFParentInfo, SFChildrenInfo,
│                      BriefcaseObjectInfo, SFSDKSoqlMutator, SFMobileSyncConstants
├── BatchSyncUpTarget.swift
├── CollectionSyncUpTarget.swift
└── SyncTarget.swift   (Swift helpers on SyncDownTarget)
Extensions/
└── MobileSync.swift   (Swift/Combine extensions on SFMobileSyncSyncManager)
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
public class BriefcaseSyncDownTarget: SFSyncDownTarget {
    @objc public init(infos: [BriefcaseObjectInfo])
    @objc public init(infos: [BriefcaseObjectInfo], countIdsPerRetrieve: Int)
}
```

`BriefcaseObjectInfo` fields: `sobjectType`, `fieldlist`, `idFieldName`, `modificationDateFieldName`, `soupName`.

Uses `/connect/briefcase/priming-records` with relay-token pagination. Fetches full records via Collection Retrieve. Routes records to different soups based on `attributes.type`. Ghost cleanup paginates the priming API without a timestamp filter.

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

Key test files: `SyncManagerTestCase.m`, `SyncDownTests.m`, `SyncUpTests.m`, `ParentChildrenSyncTests.m`, `BriefcaseSyncTests.m`.

Tests use `MockRestClient` / `MockRestResponse` to intercept REST calls without hitting a live org.
