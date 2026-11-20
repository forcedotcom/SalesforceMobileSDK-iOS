# SmartStore — Salesforce Mobile SDK for iOS

This document covers the SmartStore library in `libs/SmartStore`. Obj-C classes are prefixed with `SF`; the Swift names (`NS_SWIFT_NAME`) drop the prefix (`SmartStore`, `QuerySpec`, `SoupIndex`, ...). The wiring into `SalesforceSDKCore` (directory layout, key generation, user scoping, logout) is covered where it affects SmartStore behavior.

Everything below was checked against the source in this repo. Where a behavior comes from a dependency (FMDB, SQLCipher) rather than this repo, it is marked **(dependency)**. Items that could not be confirmed from code are marked **unverified**.

---

## Why SmartStore Exists

Mobile SDK apps need to keep Salesforce data on the device so they can work offline. The server-side data model is dynamic: admins add, rename and retire fields at any time, and records of different record types of the same object carry different fields. A conventional fixed-schema local database would need a migration every time the server schema changed, which does not suit an SDK that ships inside many apps, each with its own objects and fields.

SmartStore handles this by storing each record as a JSON document in a **soup**: a named collection, backed by one table, whose entries can have different shapes. Only the "important" fields, the ones the app queries on, are declared as **indexes** when the soup is registered. SmartStore extracts each indexed field into its own column so queries on it are fast; everything else stays in the JSON and is returned as-is. When the server adds a field, the app can start storing it with no schema change, and if it later needs to query on it, it can add an index with `alterSoup`.

SmartStore was built before SQLite and SQLCipher had the JSON1 extension, so it extracts indexed values into dedicated columns itself. Once JSON1 became available, SmartStore adopted it as an additional index type, `json1`, which indexes a field through `json_extract` on the stored JSON without a separate column. The original column-based index types (`string`, `integer`, `floating`, `full_text`) still work as before.

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [File Structure and Key Files](#file-structure-and-key-files)
4. [Getting a Store](#getting-a-store)
5. [Soups and Indexes](#soups-and-indexes)
6. [Records](#records)
7. [Queries](#queries)
8. [Smart SQL](#smart-sql)
9. [Full-Text Search](#full-text-search)
10. [Transactions](#transactions)
11. [Altering and Re-indexing Soups](#altering-and-re-indexing-soups)
12. [Encryption and Keys](#encryption-and-keys)
13. [Error Handling](#error-handling)
14. [Threading Model and Limits](#threading-model-and-limits)
15. [Declarative Store Configuration](#declarative-store-configuration)
16. [Swift and Combine Extensions](#swift-and-combine-extensions)
17. [Not Present on iOS](#not-present-on-ios)
18. [Testing](#testing)

---

## Overview

SmartStore is an encrypted, on-device JSON document store built on SQLCipher (accessed through FMDB). Data lives in named **soups**. A soup holds JSON dictionaries ("entries" or "elements"). Selected JSON paths can be **indexed**, which makes them usable in `WHERE` / `ORDER BY` clauses. Queries are either simple (all / exact / range / like / match) or **Smart SQL**, a SQLite dialect where `{soupName:path}` references are rewritten to real table and column names before execution.

SmartStore is the persistence layer under MobileSync (`libs/MobileSync`), which keeps its sync state in soups (see [`docs/mobilesync/README.md`](../mobilesync/README.md)).

---

## Architecture

```
App code (Obj-C / Swift)
 └── SFSmartStore  (SmartStore)                 ← public API; one instance per (user|global, storeName)
      ├── SFQuerySpec                            ← query description → Smart SQL (+ count SQL + ids SQL)
      ├── SFSmartSqlHelper                       ← Smart SQL → SQL ({soup:path} rewriting)
      ├── SFSmartSqlCache                        ← smartSql → sql cache (NSCache, 1024 entries; owned by the store, not the helper)
      ├── SFSoupIndex                            ← index definition (path + type)
      ├── SFAlterSoupLongOperation               ← resumable multi-step alterSoup
      ├── SFSmartStoreDatabaseManager            ← store directory, open/encrypt, file protection
      │    └── SFSmartStoreUtils / SFDirectoryManager (SalesforceSDKCore) ← per-user paths
      └── FMDatabaseQueue (FMDB)                 ← serial dispatch queue + single FMDatabase
           └── SQLCipher (SQLite)                ← encrypted file  <...>/stores/<storeName>/store.sqlite
```

### On-disk schema

Each store is one SQLCipher database file (`store.sqlite`) with these tables:

| Table | Purpose |
|---|---|
| `soup_attrs` | `id INTEGER PRIMARY KEY AUTOINCREMENT, soupName TEXT`. Maps a soup name to its table: soup `id` N is stored in `TABLE_N`. Indexed on `soupName`. |
| `soup_index_map` | One row per index: `soupName, path, columnName, columnType`. Note `columnType` actually stores the SmartStore index type string (`string`, `integer`, ...), not a SQL type. |
| `long_operations_status` | In-flight alter-soup operations (`id, type, details, status, created, lastModified`). Created lazily when opening an older store. |
| `TABLE_<n>` | One per soup: `id INTEGER PRIMARY KEY AUTOINCREMENT, soup TEXT, created INTEGER, lastModified INTEGER`, plus one column `TABLE_<n>_<i>` per non-JSON1 index (`i` = position in the registered index array). |
| `TABLE_<n>_fts` | FTS virtual table, present only if the soup has at least one `full_text` index. FTS5 by default (see [Full-Text Search](#full-text-search)). |
| `soup_names` | Legacy name of `soup_attrs`; renamed on open if found (`upgradeRenameTableSoupNamesToSoupAttrs`). |

Indexes created per soup: `TABLE_<n>_created_idx`, `TABLE_<n>_lastModified_idx`, and `TABLE_<n>_<i>_idx` for each index spec (for JSON1 indexes this is an expression index on `json_extract(soup, '$.<path>')`).

`soup_attrs` holds only `id` and `soupName` in this repo. Comments in `SFSmartStore+Internal.h` mention "external blobs storage" as a soup attribute; no such code exists (see [Not Present on iOS](#not-present-on-ios)).

### Caches (per `SFSmartStore` instance)

`soupName → table name` (`NSCache`), `soupName → [SFSoupIndex]` (`NSCache`), `smartSql → sql` (`SFSmartSqlCache`). All have `countLimit = 1024` (`CACHES_COUNT_LIMIT`). Entries for a soup are dropped by `removeFromCache:` on `removeSoup` and at the start/during `alterSoup`.

---

## File Structure and Key Files

```
libs/SmartStore/
├── SmartStore/
│   ├── SmartStore.h                         umbrella header
│   └── Classes/
│       ├── SFSmartStore.h/.m                 public API + implementation
│       ├── SFSmartStore+Internal.h           table/column names, FTS enum, internal helpers
│       ├── SFSoupIndex.h/.m                  index definition and type filters
│       ├── SFQuerySpec.h/.m                  query specs → Smart SQL
│       ├── SFSmartSqlHelper.h/.m             Smart SQL → SQL
│       ├── SFSmartSqlCache.h/.m              smartSql→sql cache
│       ├── SFAlterSoupLongOperation.h/.m     alterSoup state machine
│       ├── SFSmartStoreDatabaseManager.h/.m  paths, open, encrypt/unencrypt, file protection
│       ├── SFStoreCursor.h/.m                paging cursor (query + page index)
│       ├── SFSDKStoreConfig.h/.m             JSON-driven soup registration
│       ├── SmartStoreSDKManager.h/.m         SDK manager for SmartStore apps
│       ├── SFSmartStoreInspectorViewController.h/.m   dev-support store inspector UI
│       ├── SFSmartStoreUtils.h/.m            user key for the store registry
│       ├── SFSDKSmartStoreLogger.h/.m        logger
│       └── Extensions/SmartStore.swift       Swift / Combine helpers
├── SmartStoreTests/                         XCTest bundle (Obj-C + one Swift file)
├── SmartStoreTestApp/                       host app (globalstore.json, userstore.json)
└── SmartStore.xcodeproj
```

| File (relative to repo root) | Role |
|---|---|
| `libs/SmartStore/SmartStore/Classes/SFSmartStore.h` | Public API surface |
| `libs/SmartStore/SmartStore/Classes/SFSmartStore.m` | Store registry, soup/record operations, query execution, key derivation hooks, `inDatabase:` / `inTransaction:` wrappers |
| `libs/SmartStore/SmartStore/Classes/SFSmartStore+Internal.h` | Internal table/column constants, `ftsExtension`, `dbMgr`, `...withDb:` helpers (not in the umbrella header) |
| `libs/SmartStore/SmartStore/Classes/SFQuerySpec.m` | Builds Smart SQL / count SQL / ids SQL for each query type |
| `libs/SmartStore/SmartStore/Classes/SFSmartSqlHelper.m` | `{soup}` / `{soup:path}` rewriting |
| `libs/SmartStore/SmartStore/Classes/SFSmartStoreDatabaseManager.m` | Opening the SQLCipher DB, pragmas, encrypt/unencrypt via `sqlcipher_export`, store directories |
| `libs/SmartStore/SmartStore/Classes/SFAlterSoupLongOperation.m` | Resumable alter-soup |
| `libs/SmartStore/SmartStore/Classes/SmartStoreSDKManager.m` | Config-driven store setup, logout cleanup, dev-support hooks |
| `libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Security/Encryptor.swift` | `SFSDKKeyGenerator` (keychain-backed key) |
| `libs/SalesforceSDKCore/SalesforceSDKCore/Classes/Util/SFDirectoryManager.m` | Per-user / global directory layout |

---

## Getting a Store

`SFSmartStore` instances are cached in two process-wide registries (`_allSharedStores` keyed by user key then store name; `_allGlobalSharedStores` keyed by store name). All registry class methods use `@synchronized (self)`.

```objc
extern NSString *const kDefaultSmartStoreName;   // @"defaultStore"; Swift: SmartStore.defaultStoreName

// User store for the current user (SFUserAccountManager.sharedInstance.currentUser)
+ (nullable instancetype)sharedStoreWithName:(NSString *)storeName;

// User store for a specific user
+ (nullable instancetype)sharedStoreWithName:(NSString *)storeName user:(SFUserAccount *)user;

// Global store (not tied to any user)
+ (instancetype)sharedGlobalStoreWithName:(NSString *)storeName;
```

Swift: `SmartStore.shared(withName:)`, `SmartStore.shared(withName:forUserAccount:)`, `SmartStore.sharedGlobal(withName:)`.

### User vs. global stores

| | User store | Global store |
|---|---|---|
| `user` property | the `SFUserAccount` | `nil` |
| `isGlobal` (internal) | `NO` | `YES` |
| Database manager | `SFSmartStoreDatabaseManager sharedManagerForUser:` | `sharedGlobalManager` |
| Directory | `<root>/<orgId>/<userId>/<communityId or "internal">/stores/<storeName>/store.sqlite` | `<root>/stores/<storeName>/store.sqlite` |

`<root>` is `Documents/<bundleId>` (or the app-group container if data sharing is enabled) — see `SFDirectoryManager directoryForOrg:user:community:type:components:`.

Creation rules (`SFSmartStore.m`):

- `sharedStoreWithName:` returns `nil` (and logs a warning) if there is no current user, if the user key cannot be computed, or if the user's `loginState` is not `SFUserAccountLoginStateLoggedIn`.
- The registry key for a user is `SFSmartStoreUtils userKeyForUser:`, which is `SFKeyForUserAndScope(user, SFUserAccountScopeCommunity)`: org + user + community. The same user in a different community therefore gets a separate registry entry and separate files (community id defaults to `internal`).
- `sharedGlobalStoreWithName:` returns `nil` only if the database could not be set up.
- Each call to `sharedGlobalStoreWithName:` creates and stores an analytics event (`globalSmartStoreInit`), even on cache hits. User stores create `userSmartStoreInit` only when the registry has no entry yet (including when creation then fails and `nil` is returned; `SFSmartStore.m:313-351`). Despite the non-null return declared on `sharedGlobalStoreWithName:`, it returns `nil` if the store could not be set up.
- Creating a store registers an app feature marker (`US` for user, `GS` for global) with `SFSDKAppFeatureMarkers`.

### Store lifecycle

```objc
+ (void)removeSharedStoreWithName:(NSString *)storeName;                       // current user
+ (void)removeSharedStoreWithName:(NSString *)storeName forUser:(SFUserAccount *)user;
+ (void)removeSharedGlobalStoreWithName:(NSString *)storeName;
+ (void)removeAllStores;                                                       // current user
+ (void)removeAllStoresForUser:(SFUserAccount *)user;
+ (void)removeAllGlobalStores;

@property (class, readonly) NSArray<NSString *> *allStoreNames;                // current user (files on disk)
@property (class, readonly) NSArray<NSString *> *allGlobalStoreNames;
```

`remove...` closes the store's queue, drops it from the registry, and deletes the store directory. `allStoreNames` lists directories under the root that contain a `store.sqlite`; it can return `nil` if the root directory can't be read. `removeAllStoresForUser:` also drops the user's database manager.

### First open vs. subsequent open

`initWithName:user:isGlobal:` (internal) decides by whether `store.sqlite` exists:

- **First time**: create directory → open DB → `createMetaTables` → close → apply file protection `NSFileProtectionCompleteUntilFirstUserAuthentication` (`protectDir:protection:` starts at the `store.sqlite` path and sets the attribute on each path going up through the parent directories, stopping after the app `Documents` directory is reached or when a path's attributes cannot be read; `SFSmartStoreDatabaseManager.m:490-514`; any failure to set it returns `NO`) → reopen. On any failure the store directory is deleted.
- **Subsequent**: re-apply file protection → open → on success `createLongOperationsStatusTable`, `resumeLongOperations`, rename legacy `soup_names`. **If file protection cannot be applied or the DB cannot be opened (e.g. wrong key), the store directory is deleted and a fresh store is created** (`subsequentTimesStoreDatabaseSetup` then `firstTimeStoreDatabaseSetup`).

If the initializer fails, `self` is `nil` and the factory returns `nil`.

### Default store and multi-user

`kDefaultSmartStoreName` (`@"defaultStore"`) is the name used by the hybrid plugin and by `SmartStoreSDKManager`'s config-driven setup. Native code may use any name. Stores are fully independent files; there is no cross-store query.

### SmartStoreSDKManager

`SmartStoreSDKManager` (subclass of `SalesforceSDKManager`; `MobileSyncSDKManager` derives from it) adds:

```objc
+ (void)initializeSDK;
@property (class) SmartStoreSDKManager *sharedManager;   // Swift: SmartStoreSDKManager.shared
- (void)setupGlobalStoreFromDefaultConfig;   // reads globalstore.json → default global store
- (void)setupUserStoreFromDefaultConfig;     // reads userstore.json  → default user store (current user)
```

- On init it observes `kSFNotificationUserWillLogout` and calls `[SFSmartStore removeAllStoresForUser:]` for the logging-out user. **User store files are deleted on logout** only when the app uses `SmartStoreSDKManager` (or a subclass); that wiring is not in `SalesforceSDKCore`. Global stores are not touched.
- Dev support: adds an "Inspect SmartStore" action (`SFSmartStoreInspectorViewController`) and a SmartStore section (SQLCipher version, compile options, runtime settings, store names) to the dev-support info, using the default global store.

---

## Soups and Indexes

### SFSoupIndex

`SFSoupIndex.h` (Swift: `SoupIndex`)

```objc
- (nullable instancetype)initWithPath:(NSString *)path
                            indexType:(NSString *)type
                           columnName:(nullable NSString *)columnName;   // columnName is normally nil
- (id)initWithDictionary:(NSDictionary *)dict;      // keys: "path", "type", optional "columnName"
- (NSDictionary *)asDictionary;
- (NSDictionary *)asDictionary:(BOOL)withColumnName;
@property NSString *path;                           // dot-delimited: "Id", "Account.Name"
@property NSString *indexType;
@property (readonly, nullable) NSString *columnType;   // SQL type, nil for json1
@property (readonly) NSString *columnName;
```

Index types:

| Constant | Value | SQL column type | Storage |
|---|---|---|---|
| `kSoupIndexTypeString` | `string` | `TEXT` | Column `TABLE_<n>_<i>` |
| `kSoupIndexTypeInteger` | `integer` | `INTEGER` | Column |
| `kSoupIndexTypeFloating` | `floating` | `REAL` | Column |
| `kSoupIndexTypeFullText` | `full_text` | `TEXT` | Column in the soup table **and** a column in `TABLE_<n>_fts` |
| `kSoupIndexTypeJSON1` | `json1` | none (`columnType` is `nil`) | No column; expression `json_extract(soup, '$.<path>')` |

Behavior:

- Index values are extracted from the entry at insert/update time with `SFJsonUtils projectIntoJson:path:`. If the value is a dictionary or array it is stored as its JSON string; a missing path stores `NULL`.
- The internal filter blocks decide which indexes get a column: `kValueExtractedToColumn` (everything except json1), `kValueExtractedToFtsColumn` (`full_text`), `kValueIndexedWithJSONExtract` (json1).
- The index type string is not validated. An unknown type falls through `columnType` to `TEXT` (the default value of `columnType`'s `result`).
- JSON1 and un-indexed paths can both be used in Smart SQL; un-indexed paths are queried with `json_extract` automatically (see [Smart SQL](#smart-sql)). Because the JSON1 index is an expression index, queries must use the same expression for the DB index to be used; `{soup:path}` rewriting produces exactly `json_extract(soup, '$.<path>')`.
- Single quotes in `path` are escaped (`'` → `''`) when building the `json_extract` expression (registration and Smart SQL rewriting).

### Soup operations

```objc
- (BOOL)registerSoup:(NSString *)soupName
      withIndexSpecs:(NSArray<SFSoupIndex *> *)indexSpecs
               error:(NSError **)error;       // Swift: registerSoup(withName:withIndices:) throws
- (BOOL)soupExists:(NSString *)soupName;      // Swift: soupExists(forName:)
- (NSArray<SFSoupIndex *> *)indicesForSoup:(NSString *)soupName;
- (NSArray<NSString *> *)allSoupNames;
- (void)clearSoup:(NSString *)soupName;       // delete all entries, keep soup
- (void)removeSoup:(NSString *)soupName;      // drop soup tables and metadata
- (void)removeAllSoups;
- (unsigned long long)getDatabaseSize;        // size of store.sqlite (bytes); Swift: databaseSize()
```

`registerSoup`:

- Runs in a transaction (see [Transactions](#transactions)).
- Throws (surfaced as `NSError`, code 999) if `soupName` is empty or `indexSpecs` is empty. At least one index spec is required.
- **If the soup already exists, it returns success and does nothing** — it does not compare or update the indexes. Use `alterSoup` to change indexes.
- Creates `TABLE_<n>`, the optional FTS table, the DB indexes, and the `soup_index_map` rows. Logs a `registerSoup` analytics event with feature tags (`JSON1`, `FTS`).

`removeSoup` drops `TABLE_<n>` (and `TABLE_<n>_fts` if the soup has a full-text index), deletes the `soup_index_map` and `soup_attrs` rows, and clears caches. `clearSoup` deletes rows from the soup table (and FTS table) only. `removeSoup` / `clearSoup` / `removeAllSoups` do not take an `NSError`; failures are swallowed (see [Error Handling](#error-handling)).

Soup names are used verbatim in some SQL (`DELETE ... WHERE soupName="<name>"` in `removeSoup:withDb:`) and in `{...}` Smart SQL references. Names containing `"` are not escaped in those `DELETE` statements (`SFSmartStore.m:1201-1204`), so such a name breaks (or injects into) `removeSoup`; names containing `{`, `}` or `:` cannot be referenced in Smart SQL (`:` makes the reference split into extra parts). None of this is validated at registration.

---

## Records

All records are JSON dictionaries. The store adds and maintains two fields in the stored JSON:

| Field | Constant | Type | Meaning |
|---|---|---|---|
| `_soupEntryId` | `SOUP_ENTRY_ID` (Swift: `SmartStore.soupEntryId`) | integer | Primary key of the row (`id` column) |
| `_soupLastModifiedDate` | `SOUP_LAST_MODIFIED_DATE` (Swift: `SmartStore.lastModifiedDate`) | integer, ms since 1970 | Set on every insert/update (same value as the `lastModified` column) |

There is **no `_soupCreatedDate` field in the stored JSON**. The creation time exists only in the `created` column (ms since 1970, set on insert, never updated), and is reachable in Smart SQL as `{soup:_soupCreatedDate}`. `+dateFromLastModifiedValue:` converts a ms value to `NSDate`.

Column name constants (public, `SFSmartStore.h`): `ID_COL` (`id`), `CREATED_COL` (`created`), `LAST_MODIFIED_COL` (`lastModified`), `SOUP_COL` (`soup`).

### Upsert

```objc
// Insert vs. update decided by _soupEntryId in the entry
- (NSArray<NSDictionary *> *)upsertEntries:(NSArray<NSDictionary *> *)entries
                                    toSoup:(NSString *)soupName;

// Insert vs. update decided by the value at externalIdPath
- (nullable NSArray *)upsertEntries:(NSArray *)entries
                             toSoup:(NSString *)soupName
                 withExternalIdPath:(NSString *)externalIdPath
                              error:(NSError **)error;

- (nullable NSNumber *)lookupSoupEntryIdForSoupName:(NSString *)soupName
                                       forFieldPath:(NSString *)fieldPath
                                         fieldValue:(NSString *)fieldValue
                                              error:(NSError **)error;
```

Semantics (`upsertOneEntry:...` in `SFSmartStore.m`):

- `externalIdPath` of `nil` or `SOUP_ENTRY_ID`: if the entry has a `_soupEntryId` it is an **update** of that row id, otherwise an **insert**. The update path does not check that a row with that id exists (`UPDATE ... WHERE id = ?` affecting 0 rows is not detected; the entry is still returned as upserted).
- Any other `externalIdPath`: the value is read from the entry; if it is `nil` the upsert fails with error code 3 ("value cannot be empty"). Otherwise `lookupSoupEntryIdForSoupName:...` finds the row id by the **indexed column** for that path; if found it is an update, otherwise an insert. The path must be indexed in the soup (error code 2 otherwise) and must be unique (error code 1 "does not represent a unique entry" if more than one row matches). JSON1-indexed paths work as an external id path: the lookup runs `SELECT id FROM TABLE_n WHERE json_extract(soup, '$.path') = ?` (the JSON1 column name is that expression, and the query targets the soup table alone), `SFSmartStore.m:1252-1290`. The value is read with `SFJsonUtils projectIntoJson:path:`, which preserves the JSON type, and passed unchanged to FMDB (assigning it to an `NSString *` variable does not convert an `NSNumber`). A numeric JSON value (e.g. `42`) is therefore bound **numerically** and matches `json_extract(...) = ?`; a string `"42"` does not match a stored number (verified against FMDB `2.7.12-sqlcipher` and system SQLite). This matters for callers of the public `lookupSoupEntryIdForSoupName:forFieldPath:fieldValue:error:`, whose `fieldValue` is typed `NSString *`: an explicitly supplied text value is bound as text and will not match a numeric JSON value. No test in `SmartStoreTests` exercises `withExternalIdPath:` with a non-nil path.
- Insert: the id is computed as `SQLITE_SEQUENCE.seq + 1` (or 1), `created` and `lastModified` are set to now, and `_soupEntryId` / `_soupLastModifiedDate` are written into the stored JSON (overwriting any value the caller supplied). Full-text columns are inserted into `TABLE_<n>_fts` with `rowid` = entry id.
- Update: `lastModified` and all index columns are rewritten; `created` is untouched; the whole JSON blob is replaced (not merged).
- Returns the stored entries (with the two reserved fields added). If the soup does not exist the result is `nil`.
- Entries are processed in order inside **one transaction**, but a per-entry failure (nil external id, lookup error) is *not* an exception: the loop stops, the result array is emptied, `*error` is set, and the method returns an **empty array** — the transaction is **not** rolled back, so entries before the failing one remain written. Only an exception (e.g. SQL failure, see [Error Handling](#error-handling)) triggers rollback.
- The no-`error:` overload `upsertEntries:toSoup:` calls the above with `SOUP_ENTRY_ID` and `error:nil`.

### Retrieve

```objc
- (NSArray<NSDictionary *> *)retrieveEntries:(NSArray<NSNumber *> *)soupEntryIds
                                    fromSoup:(NSString *)soupName;   // Swift: retrieve(usingSoupEntryIds:fromSoupNamed:)
```

Order is not guaranteed; ids that do not exist are omitted; an unknown soup returns an empty array. The ids are inlined into the SQL (`id IN (1,2,3)`), not bound.

### Remove

```objc
- (BOOL)removeEntries:(NSArray<NSNumber *> *)entryIds
             fromSoup:(NSString *)soupName
                error:(NSError **)error;                // Swift: remove(entryIds:forSoupNamed:)
- (void)removeEntries:(NSArray<NSNumber *> *)entryIds fromSoup:(NSString *)soupName;   // Swift-unavailable

- (BOOL)removeEntriesByQuery:(SFQuerySpec *)querySpec
                    fromSoup:(NSString *)soupName
                       error:(NSError **)error;         // Swift: removeEntries(usingQuerySpec:forSoupNamed:)
- (void)removeEntriesByQuery:(SFQuerySpec *)querySpec fromSoup:(NSString *)soupName;   // Swift-unavailable
```

`removeEntriesByQuery` runs one `DELETE ... WHERE id IN (<ids query> LIMIT pageSize)` statement. The query spec's `idsSmartSql` is used: for non-smart specs it selects `id`; for smart specs it is `SELECT id FROM (<your smartSql>)`, so **your smart SQL must select the id column** (`{soup:_soupEntryId}` aliased/returned as `id`; the code comment says it "won't successfully run" otherwise). Only the first `pageSize` matching rows are deleted (`SFSmartStore.m:1846-1860`). Bind args from `bindsForQuerySpec` are passed to the soup-table `DELETE`. For soups with a full-text index a second statement, `DELETE FROM TABLE_n_fts WHERE rowid IN (<ids query>)`, runs **after** the soup-table delete, **without** bind args and **without** `LIMIT`. The ids query is re-evaluated against the already-modified soup table, so the FTS table can go out of sync in two ways (read from code and reproduced against generated SQL; `SFSmartStoreTests.m:744,759` do not use FTS soups):

- **Specs with bind args (`exact`, `like`, and `range` with a begin and/or end key):** the FTS statement is built with the same `?` placeholders but is executed through `executeUpdateThrows:withDb:` with **no arguments supplied**. FMDB's variadic `executeUpdate:` consumes one object argument per placeholder from a `va_list`, so reading those missing arguments is undefined behavior, not a supported way to leave SQLite parameters unbound. The outcome is therefore **not deterministic** (a NULL binding and no match, which orphans the removed entries' FTS rows, is only the likely case; it was not verified through FMDB, and plain SQLite reproduction does not establish it). This is a defect to fix in the code, not behavior to rely on.
- **Specs without bind args (`match`, `smart`, an unbounded `range`):** the sub-query runs with no `LIMIT`, so it returns **every remaining match**. When more entries match than `pageSize`, the FTS rows of the entries that **survived** are deleted, so those entries silently stop matching full-text queries, while the FTS rows of the entries that were removed stay behind. Example: three matching entries 1, 2, 3 with `pageSize = 1` leave soup entries 2 and 3 but only FTS row 1. (When matches `<= pageSize` all matching entries are already gone, so the FTS statement finds nothing: for specs without bind args this case leaves the removed entries' FTS rows orphaned as well.)

Orphaned FTS rows are not returned by match queries (they join back to the soup table by id) but are not cleaned up by normal operations (`clearSoup` / `removeSoup` remove them along with the data; `alterSoup` rebuilds them, see below); missing FTS rows for surviving entries mean those entries are not found by `match` queries. **Neither re-upserting them nor `reIndexSoup` repairs this:** `updateOneEntry:...` and `reIndexSoup:withIndexPaths:withDb:` issue an `UPDATE` against the FTS table, which updates zero rows when the row was deleted and never inserts it. **Recovery option: `alterSoup` with the soup's existing index specs.** Its copy step rebuilds the FTS table with `INSERT INTO TABLE_n_fts (...) SELECT ... FROM TABLE_n_old`, reading the surviving soup records rather than copying the damaged FTS table, so it inserts the missing rows, drops the orphans and preserves entry ids (reproduced with the generated SQL; `reIndexData` is not needed). The usual `alterSoup` caveats apply: it rewrites the whole soup table, each step commits separately (resumable through `long_operations_status`, not atomic), and a SQL failure in a step propagates as an `NSException` (see [Altering and Re-indexing Soups](#altering-and-re-indexing-soups)). Prevention: delete by ids (`removeEntries:fromSoup:`) rather than by query on soups with a full-text index.

---

## Queries

### SFQuerySpec

`SFQuerySpec.h` (Swift: `QuerySpec`). Instances are immutable-by-convention value objects built by factory methods; each non-smart factory computes `smartSql`, `countSmartSql` and `idsSmartSql`.

```objc
typedef NS_ENUM(NSInteger, SFSoupQueryType) {   // Swift: QuerySpec.QueryType
    kSFSoupQueryTypeExact = 2, kSFSoupQueryTypeRange = 4, kSFSoupQueryTypeLike = 8,
    kSFSoupQueryTypeSmart = 16, kSFSoupQueryTypeMatch = 32
};
typedef NS_ENUM(NSUInteger, SFSoupQuerySortOrder) {   // Swift: QuerySpec.SortOrder
    kSFSoupQuerySortOrderAscending, kSFSoupQuerySortOrderDescending
};

+ (SFQuerySpec *)newAllQuerySpec:(NSString *)soupName withSelectPaths:(nullable NSArray *)selectPaths
                   withOrderPath:(NSString *)orderPath withOrder:(SFSoupQuerySortOrder)order withPageSize:(NSUInteger)pageSize;
+ (SFQuerySpec *)newExactQuerySpec:(NSString *)soupName withSelectPaths:(nullable NSArray *)selectPaths
                          withPath:(NSString *)path withMatchKey:(NSString *)matchKey
                     withOrderPath:(NSString *)orderPath withOrder:(SFSoupQuerySortOrder)order withPageSize:(NSUInteger)pageSize;
+ (SFQuerySpec *)newRangeQuerySpec:(NSString *)soupName withSelectPaths:(nullable NSArray *)selectPaths
                          withPath:(NSString *)path withBeginKey:(NSString *)beginKey withEndKey:(NSString *)endKey
                     withOrderPath:(NSString *)orderPath withOrder:(SFSoupQuerySortOrder)order withPageSize:(NSUInteger)pageSize;
+ (SFQuerySpec *)newLikeQuerySpec:(NSString *)soupName withSelectPaths:(nullable NSArray *)selectPaths
                         withPath:(NSString *)path withLikeKey:(NSString *)likeKey
                    withOrderPath:(NSString *)orderPath withOrder:(SFSoupQuerySortOrder)order withPageSize:(NSUInteger)pageSize;
+ (SFQuerySpec *)newMatchQuerySpec:(NSString *)soupName withSelectPaths:(nullable NSArray *)selectPaths
                          withPath:(NSString *)path withMatchKey:(NSString *)matchKey
                     withOrderPath:(NSString *)orderPath withOrder:(SFSoupQuerySortOrder)order withPageSize:(NSUInteger)pageSize;
+ (SFQuerySpec *)newSmartQuerySpec:(NSString *)smartSql withPageSize:(NSUInteger)pageSize;
```

Each of these (except smart) also has an overload without `withSelectPaths:`. Swift names: `QuerySpec.buildAllQuerySpec(soupName:orderPath:order:pageSize:)`, `buildExactQuerySpec`, `buildRangeQuerySpec`, `buildLikeQuerySpec`, `buildMatchQuerySpec`, `buildSmartQuerySpec(smartSql:pageSize:)` (plus `selectPaths:` variants).

| Type | Generated clause | Bind args |
|---|---|---|
| all | implemented as a range query with `path = nil`, no keys → no `WHERE` | none |
| exact | `WHERE {soup:path} = ?` | `[matchKey]` |
| range | `>= ? AND <= ?`; only `beginKey` → `>= ?`; only `endKey` → `<= ?`; neither → no `WHERE` (also when `path` is nil) | begin and/or end key |
| like | `WHERE {soup:path} LIKE ?` | `[likeKey]` |
| match | `WHERE {soup:_soupEntryId} IN (SELECT rowid FROM {soup}_fts WHERE {soup}_fts MATCH '<key>')` | none: the match key is inlined with `'` doubled |
| smart | your Smart SQL as-is | supplied separately via `queryWithQuerySpec:pageIndex:whereArgs:error:` |

Common behavior:

- Default `SELECT` is `{soup:_soup}` (whole entry). With `selectPaths` it selects those paths, and results become arrays of values per row (like smart queries).
- `ORDER BY {soup:orderPath} ASC|DESC` is added only if `orderPath != nil`. Order direction defaults to ascending.
- `pageSize` is whatever you pass; there is no cap or minimum check in the factories. `kQuerySpecDefaultPageSize` is 10, used only when building from a dictionary with a missing/non-positive `pageSize`.
- Count SQL: for non-smart specs `SELECT count(*) FROM <from> <where>`; for smart specs `SELECT count(*) FROM (<smartSql>)`.
- `initWithDictionary:withSoupName:` (Swift `init(querySpec:targetSoupName:)`) builds a spec from the hybrid-style dictionary (`queryType`, `indexPath`, `beginKey`, ...). An unrecognized `queryType` returns `nil`.
- `asDictionary` serializes back (`description` is that dictionary as JSON).
- The factories taking `selectPaths` are declared `nullable`, the others (and `newAllQuerySpec:`) are non-null; in practice they only return `nil` if `[[super alloc] init]` fails. In Swift only `buildSmartQuerySpec`, and the overloads taking `selectPaths`, return optionals.

### Running queries

```objc
- (nullable NSNumber *)countWithQuerySpec:(SFQuerySpec *)querySpec error:(NSError **)error;   // Swift: count(using:)

- (nullable NSArray *)queryWithQuerySpec:(SFQuerySpec *)querySpec
                               pageIndex:(NSUInteger)pageIndex
                                   error:(NSError **)error;      // Swift: query(using:startingFromPageIndex:)

- (nullable NSArray *)queryWithQuerySpec:(SFQuerySpec *)querySpec
                               pageIndex:(NSUInteger)pageIndex
                               whereArgs:(nullable NSArray *)whereArgs
                                   error:(NSError **)error;      // smart queries only

- (BOOL)queryAsString:(NSMutableString *)resultString querySpec:(SFQuerySpec *)querySpec
            pageIndex:(NSUInteger)pageIndex error:(NSError **)error;   // Swift-unavailable
```

- Paging: the SQL is `SELECT * FROM (<converted sql>) LIMIT <pageSize * pageIndex>,<pageSize>`. Pages are zero-based. There is no state between calls; each call re-runs the query.
- Result shape: simple queries without `selectPaths` return an array of entry dictionaries. Smart queries and queries with `selectPaths` return an **array of arrays** (one inner array per row, one element per selected column). A column named `soup` (or prefixed `soup:`) with a string value is parsed as JSON into a dictionary; other columns are returned as-is (`NSNumber`, `NSString`, `NSNull`).
- `whereArgs` are bound only for smart queries. Passing non-nil `whereArgs` for any other type sets error code 5 — note that code writes `*error` unconditionally, so passing `NULL` for `error` in that case would crash.
- `queryAsString:` returns the JSON text of the page (`[...]`) without building Foundation objects; used by hybrid bridges. The string builder re-escapes string columns and, when `jsonSerializationCheckEnabled` is on, validates them.
- Smart SQL that fails to convert or execute raises an exception inside `inDatabase:`, which is turned into an `NSError` (code 999) for the methods that take an `error:`.
- `captureExplainQueryPlan` (property): when `YES`, each executed query additionally runs `EXPLAIN QUERY PLAN` and stores `{sql, args, rows}` in `lastExplainQueryPlan`.
- Class property `jsonSerializationCheckEnabled` (default `NO`): extra JSON validation when building string results; failures post `kSFSmartStoreJSONParseErrorNotification`. `+setPostRawJsonOnError:` (declared only in the `.m`, not in any header) controls whether the raw JSON is included in that notification.

### SFStoreCursor

`SFStoreCursor` (Swift: `StoreCursor`) wraps a query spec and current page: `cursorId`, `pageSize`, `totalPages`, `totalEntries` (computed once in `initWithStore:querySpec:` through `countWithQuerySpec:`, errors ignored), `currentPageIndex` (starts at 0). Despite the header comments, `currentPageOrderedEntries` is never populated (always `nil`) and setting `currentPageIndex` does not refetch anything (`SFStoreCursor.m` has no setter). `getDataSerialized:error:` / `getDataDeserialized:error:` run the query for the current `currentPageIndex` and return the cursor as JSON / dictionary (with a `currentPageOrderedEntries` key). `close` (also called from `dealloc`) clears the query spec and page counters, after which those methods no longer work. It is a thin helper for hybrid-style cursors; native code usually calls `queryWithQuerySpec:` directly.

---

## Smart SQL

Smart SQL is SQLite SQL with soup/field references in braces, rewritten by `SFSmartSqlHelper convertSmartSql:withStore:withDb:`:

| Reference | Rewritten to |
|---|---|
| `{soup}` | the table name, e.g. `TABLE_3` |
| `{soup:_soup}` | `TABLE_3.soup` (the raw JSON column) |
| `{soup:_soupEntryId}` | `TABLE_3.id` |
| `{soup:_soupCreatedDate}` | `TABLE_3.created` |
| `{soup:_soupLastModifiedDate}` | `TABLE_3.lastModified` |
| `{soup:path}` indexed | the index column name **without table qualifier**, e.g. `TABLE_3_0`, or `json_extract(soup, '$.path')` for JSON1 |
| `{soup:path}` not indexed | `json_extract(soup, '$.path')` (also unqualified; works on any path, but not index-backed; `'` in the path is doubled) |

Rules from the code:

- The `TABLE_3.` qualifier is added only for the special columns (`_soup`, `_soupEntryId`, `_soupCreatedDate`, `_soupLastModifiedDate`), and omitted if the `{...}` is directly preceded by `.` (e.g. `t.{soup:_soupEntryId}`), so table aliases work. Indexed and non-indexed `{soup:path}` references are never qualified by the helper, so in joins they must be unambiguous (or, for JSON1/non-indexed paths, written as `alias.{soup:path}` / `{soup}.{soup:path}`, which the last rule turns into `json_extract(alias.soup, ...)`; `alias.` before a plain index column yields `alias.TABLE_3_0`, which is valid). `SFSmartSqlTests.m` (`testConvertSmartSqlWithJSON1AndTableAliases`) notes that join queries with JSON1 or non-indexed paths only work if every such column is qualified.
- Unknown soup name → exception `convertSmartSql failed: Invalid soup name:<name>`. More than one `:` inside the braces → "Invalid soup/path reference".
- References **inside single-quoted string literals are left untouched**, except inside the quoted argument of `MATCH '...'` (needed for `{soup}_fts MATCH 'key'` style queries).
- Only a prefix check guards against writes: SQL starting (after trim, case-insensitive) with `insert`, `update`, or `delete` throws "Only SELECT are supported". It is not a SQL parser; do not treat it as a security boundary.
- Conversion results are cached per store in `SFSmartSqlCache`. A conversion that returns `nil` is cached as the string `null`. In practice conversion failures throw, so that path is mostly unused.
- The final `<qualifier>.json_extract(soup, ...)` pattern (regex `(\w+)\.json_extract\(soup`, where the qualifier is a table name or alias typed before the reference) is rewritten to `json_extract(<qualifier>.soup, ...)`.

Example:

```objc
SFQuerySpec *spec = [SFQuerySpec newSmartQuerySpec:
    @"SELECT {accounts:Name}, {contacts:LastName} "
    @"FROM {accounts}, {contacts} "
    @"WHERE {accounts:Id} = {contacts:AccountId} AND {accounts:Name} LIKE ? "
    @"ORDER BY {accounts:Name}"
                                      withPageSize:50];
NSError *error = nil;
NSArray *rows = [store queryWithQuerySpec:spec pageIndex:0 whereArgs:@[@"Acme%"] error:&error];
// rows: @[ @[@"Acme", @"Smith"], ... ]
```

---

## Full-Text Search

- A soup has FTS support if at least one index is `full_text`. All `full_text` indexes of a soup share one virtual table `TABLE_<n>_fts` (one column per full-text path, named like the main-table column), keyed by `rowid` = entry id.
- Extension: `SFSmartStoreFtsExtension` (`SFSmartStoreFTS4 = 4`, `SFSmartStoreFTS5 = 5`) in `SFSmartStore+Internal.h`; the internal property `ftsExtension` defaults to **FTS5** (`testFtsExtension` asserts 5). The value is used when a soup is created (`CREATE VIRTUAL TABLE ... USING fts<N>`); changing it affects only soups registered afterwards. FTS4 is used by tests that set the property explicitly. It is not public API.
- The FTS table is kept in sync by insert / update / delete-by-id / clear / re-index code paths in `SFSmartStore.m`. **`removeEntriesByQuery` is the exception:** it can orphan FTS rows and, when more entries match than `pageSize`, delete the FTS rows of entries that remain (so they stop matching full-text queries); see [Records](#records).
- Match query: `[SFQuerySpec newMatchQuerySpec:...]` generates the `MATCH` subquery above. `path` may be `nil` to match against any full-text column; otherwise the key is rewritten by `+qualifyMatchKey:field:` so each term gets a `{soup:path}:` column prefix (FTS5 only accepts `table MATCH 'column:term'`). Terms `and`, `or`, `not` (case-insensitive) and terms starting with `{` are left alone; parentheses and spaces split terms.
- The match key is inlined in the SQL with `'` doubled (statement binding was not used). Smart SQL can also use `{soup}_fts MATCH '...'` directly.
- A soup without a full-text index has no `_fts` table, so a match query on it fails at execution (SQL error).

```objc
SFQuerySpec *spec = [SFQuerySpec newMatchQuerySpec:@"notes" withPath:@"body"
                                      withMatchKey:@"swift AND combine"
                                     withOrderPath:@"title" withOrder:kSFSoupQuerySortOrderAscending
                                      withPageSize:20];
```

---

## Transactions

### What the code shows

`inTransaction:error:` is **not public**:

- It is defined once, in `libs/SmartStore/SmartStore/Classes/SFSmartStore.m` (line ~638), as an instance method:
  ```objc
  - (BOOL)inTransaction:(void (^)(FMDatabase *db, BOOL *rollback))block
                  error:(NSError * __autoreleasing *)error;
  ```
- It is **not declared in any header** in the repo: not in `SFSmartStore.h`, not in `SFSmartStore+Internal.h`, not in the umbrella `SmartStore.h`. (The same holds for its sibling `inDatabase:error:`.) It can be called from within `SFSmartStore.m` because the call sites are inside the same `@implementation` (clang resolves methods defined anywhere in the `@implementation`; definition order does not matter); other files (e.g. tests) would need their own category declaration. No file outside `SFSmartStore.m` calls `inTransaction:error:` (other than `store.storeQueue inTransaction:` calls in `SFAlterSoupLongOperation.m`, which use FMDB directly).
- There is no public `beginTransaction` / `commit` / `rollback` API. Apps cannot group several public SmartStore calls into one atomic unit.

### Behavior

`inTransaction:error:` forwards to `FMDatabaseQueue -inTransaction:` and adds exception handling:

1. `[FMDatabaseQueue inTransaction:]` runs the block synchronously on the queue's serial dispatch queue **(dependency)**: it issues `BEGIN EXCLUSIVE TRANSACTION`, runs the block with a `rollback` flag, then `ROLLBACK` if the flag is set or `COMMIT` otherwise.
2. The block runs inside an `@try`. If an `NSException` is thrown (this is how `executeUpdateThrows:` / `executeQueryThrows:` / Smart SQL conversion report errors), the wrapper sets `*rollback = YES`, stores an `NSError` (domain `kSFSmartStoreErrorDomain`, code 999, description = the exception description) in `*error` if one was supplied, and returns `NO`. Otherwise it returns `YES`.
3. Failures that are reported through return values or `NSError` out-params without an exception (e.g. the nil-external-id upsert described in [Records](#records)) do **not** set `rollback`; the transaction commits whatever was already written.

Public operations that run in a transaction: `registerSoup`, `removeSoup`, `removeAllSoups`, `upsertEntries...`, `removeEntries...`, `removeEntriesByQuery...`, `clearSoup`, `reIndexSoup`. Read operations (`query`, `count`, `retrieve`, `lookup`, `soupExists`, ...) use `inDatabase:error:` (no transaction, still on the serial queue).

Nesting: SmartStore never nests transactions; internal code calls the `...withDb:` variants with the already-open `FMDatabase`. Calling `inTransaction:error:` (or any public SmartStore method that wraps one) from inside a block that is already running on the store queue would call `dispatch_sync` onto the queue it is running on. That is a deadlock in plain GCD; FMDB does not provide re-entrancy for transactions **(dependency; FMDB 2.7.12 per `SmartStore.podspec` `~> 2.7.12` and the `2.7.12-sqlcipher` pin in `SmartStore.xcodeproj`; `FMDatabaseQueue.m` `inTransaction:` issues `begin exclusive transaction` and, unlike `inDatabase:` which has a debug-only `assert(currentSyncQueue != self ...)` re-entrancy check (`FMDatabaseQueue.m:185`), has no check, so a nested call deadlocks; read from source, not exercised)**. There are no savepoints in SmartStore.

The alter-soup operation opens its own FMDB transactions on `store.storeQueue` (one per step) without the exception wrapper. An exception thrown inside such a step is not caught by SmartStore and propagates out of the FMDB block.

### Comparison with Android

Android's `SmartStore.java` exposes the primitives publicly (`libs/SmartStore/src/com/salesforce/androidsdk/smartstore/store/SmartStore.java`):

```java
public void beginTransaction();            // getDatabase().beginTransaction()
public void setTransactionSuccessful();    // next endTransaction commits
public void endTransaction();              // commit if marked successful, otherwise rollback
```

| | iOS (`SFSmartStore.m`) | Android (`SmartStore.java`) |
|---|---|---|
| Public API for app-level transactions | None (`inTransaction:error:` is file-local, undeclared) | `beginTransaction` / `setTransactionSuccessful` / `endTransaction` |
| Style | Block-scoped; commit by default, rollback via flag or exception | Explicit begin / mark / end; rollback unless marked successful |
| Rollback trigger | Thrown `NSException` (or `*rollback = YES` in an FMDB block) | Not calling `setTransactionSuccessful` before `endTransaction` |
| Nesting | Not supported (single serial queue, `BEGIN EXCLUSIVE` per call) | Android `SQLiteDatabase` supports nested transactions (a failed inner one rolls back the outer); the Android code comments say callers should wrap in `synchronized(store.getDatabase())` to avoid deadlock |
| Failure reporting | `BOOL` + `NSError` (code 999) for methods with `error:`; swallowed otherwise | Exceptions |
| Per-call atomicity of public ops | Each write op wraps its own transaction, but rollback only happens on a thrown exception; see the exceptions listed below the table | Each write op wraps its own transaction (when `handleTx` is true); exceptions listed below the table |

Per-call atomicity is **not unconditional** on either platform:

- iOS batch `upsertEntries...`: if a later entry fails (for example external-id validation returning an error without throwing), the result array is emptied but the wrapper does not set `rollback`, so earlier entries of the batch are **committed**. Only a thrown exception rolls the batch back.
- iOS alter-soup commits each step in its own FMDB transaction (resumable, not atomic overall).
- Android `dropSoup` drops the tables before opening the transaction that deletes the metadata rows; `clearSoup` and `reIndexSoup` call `setTransactionSuccessful()` in `finally`, so they commit even when an exception was thrown; alter-soup commits each step.

The Android nesting behavior is standard `SQLiteDatabase` semantics (the `SmartStore.java` code just forwards to `getDatabase().beginTransaction()` / `setTransactionSuccessful()` / `endTransaction()` and documents the `synchronized` requirement at line 255); it was not exercised.

---

## Altering and Re-indexing Soups

```objc
- (BOOL)alterSoup:(NSString *)soupName
   withIndexSpecs:(NSArray<SFSoupIndex *> *)indexSpecs
      reIndexData:(BOOL)reIndexData;               // Swift: alterSoup(named:indexSpecs:reIndexData:)

- (BOOL)reIndexSoup:(NSString *)soupName
     withIndexPaths:(NSArray<NSString *> *)indexPaths;   // Swift: reIndexSoup(named:indexPaths:)

- (void)resumeLongOperations;
```

`alterSoup` returns `NO` if the soup does not exist and takes no `NSError`; it returns `YES` once the operation has *run*. It has no `NSError` parameter, but errors are **not suppressed**: the steps run directly in FMDB transactions through `executeUpdateThrows:` without SmartStore's exception wrapper, so a SQL failure inside a step propagates out of `alterSoup` as an `NSException` (the interrupted operation is resumed on the next open). It creates an `SFAlterSoupLongOperation`, which inserts a row in `long_operations_status` (type `AlterSoup`, JSON `details` with old/new index specs, `reIndexData`), then runs these steps (`SFAlterSoupStep`), each in its own transaction that also advances the status row:

1. rename `TABLE_n` → `TABLE_n_old` (and `_fts` → `_fts_old`)
2. drop old DB indexes and delete the soup's `soup_index_map` rows
3. register the soup again with the new index specs, reusing the same table name
4. copy rows from `_old` into the new table (`id`, `created`, `lastModified`, `soup`, plus index columns for paths present in both old and new specs **with the same SQL column type**; JSON1 targets have no column). Full-text columns are copied for kept `full_text` paths.
5. if `reIndexData`: re-extract values for paths whose `path--type` was not in the old specs
6. drop the `_old` tables
7. cleanup: delete the status row

If the app dies mid-operation, `resumeLongOperations` (called when an **existing** store is opened, not on first creation) re-runs pending rows from their saved step. The code notes that a crash between the `ALTER TABLE` and the status update would make step 1 fail on replay (`TODO` in `renameOldSoupTable`). Resumption assumes all long operations are alter-soup (`TODO` in `getLongOperationsWithDb:`).

`reIndexSoup:withIndexPaths:` re-reads every entry's JSON and recomputes the index columns (and FTS columns) for the given paths; paths that are not already indexed in the soup are silently ignored. It runs in a transaction and returns `NO` only if the soup does not exist.

---

## Encryption and Keys

### Database encryption

`SFSmartStoreDatabaseManager unlockDatabase:key:salt:` configures every connection:

1. If `+[SFSmartStore setLicenseKey:]` was called: `PRAGMA cipher_license = '<key>'` (needed for SQLCipher commercial/enterprise editions).
2. `[db setKey:key]` if `key` is non-nil. If the key generator returns `nil` (for example `SFSDKKeyGenerator` throws, which the default generator only logs), `encKey` is `nil` and the store is opened **without encryption** (no error is raised).
3. `PRAGMA kdf_iter = 4000` (comment: the 3.x/4.x defaults are too slow).
4. If both `salt` and a non-empty `key` exist: `PRAGMA cipher_plaintext_header_size = 32`, `PRAGMA cipher_salt = "x'<salt>'"`, `PRAGMA journal_mode = WAL`.
5. A `select name from sqlite_master` read verifies the key; on failure the DB is closed and the open fails.

The comment states that `PRAGMA cipher_migrate` is no longer run, so a direct jump from a store created by SDK 7.x (SQLCipher 3.x) to 10.0+ will not open **(comment at `SFSmartStoreDatabaseManager.m:212`; no test covers it)**.

### Key derivation and storage

- `+[SFSmartStore encKey]` calls the class-level `encryptionKeyGenerator` block and base64-encodes the returned `NSData`; that string is passed to `setKey:` as a passphrase.
- Default generator (`+initialize` in `SFSmartStore.m`): `[SFSDKKeyGenerator encryptionKeyFor:kSFSmartStoreEncryptionKeyLabel error:]`, label `com.salesforce.smartstore.encryption.keyLabel`.
- `SFSDKKeyGenerator` (`Encryptor.swift`, class `KeyGenerator`): returns a cached 256-bit `SymmetricKey` for the label, or loads it from the keychain (service `com.salesforce.keystore.<label>`), where it is stored **encrypted with an EC key pair** (`defaultKey`; tags `com.salesforce.eckey.public/private...`). If the stored key is missing or cannot be decrypted, **a new random key is generated and stored**, which makes any existing store file unreadable (and, per [first open vs. subsequent open](#first-open-vs-subsequent-open), such a store is deleted and recreated).
- The same key is used for all SmartStore stores of the app (user and global); it is not per user or per store.
- Override with `+[SFSmartStore setEncryptionKeyGenerator:]` before any store is opened (header warns that changing it later corrupts / loses data, and that SmartStore uses no IVs). Not recommended by the header.

### Salt (shared databases between apps)

`encryptionSaltBlock` (class property; default set in `+initialize`) returns a hex salt read from keychain service `com.salesforce.smartstore.encryption.saltLabel`. If none exists, a new 16-byte random salt is generated and written **only if app-group data sharing is enabled** (`SFSDKDatasharingHelper appGroupEnabled`); otherwise it returns `nil` and no salt/plaintext-header/WAL pragmas are applied. Can be replaced with `+setEncryptionSaltBlock:` (declared only in the `.m`; the getter is public as a read-only class property).

### Migration helpers

- `fixFor12Bug:key:salt:` (run on every open): databases created with Mobile SDK 12.0 / 12.1.x via CocoaPods were not encrypted (SQLCipher not linked). If the file is readable with no key, it is encrypted in place via `encryptDbWithStoreName:...`.
- `encryptDbWithStoreName:` / `unencryptDbWithStoreName:` and the instance `encryptDb:` / `unencryptDb:` (public in `SFSmartStoreDatabaseManager.h`) use `ATTACH ... KEY` + `sqlcipher_export`, verify the new file can be opened and read, back up the original as `.bak`, swap files, and restore the backup if anything fails. Errors use domain `com.salesforce.smartstore.db.error`, codes 1-7.
- No key-rotation API exists.

### Runtime info

`getSQLCipherVersion`, `getCipherProviderVersion`, `getCipherFIPSStatus`, `getCompileOptions`, `getRuntimeSettings` run the corresponding `PRAGMA` (Swift: `versionOfSQLCipher()`, `cipherProviderVersion()`, `cipherFIPSStatus()`, `compileOptions()`, `runtimeSettings()`).

---

## Error Handling

Two layers coexist:

- **Exceptions inside the store**: `executeQueryThrows:` / `executeUpdateThrows:` (and registration validation, Smart SQL conversion, `NSAssert`s) throw `NSException` with the SQLite last error message as reason.
- **`inDatabase:error:` / `inTransaction:error:` (private)** catch them and convert to `NSError`: domain `com.salesforce.smartstore.error` (`kSFSmartStoreErrorDomain`), code 999, description = `[exception description]`.

Other `NSError`s with the same domain are created directly:

| Code | Meaning | Raised by |
|---|---|---|
| 1 | value for the external id path does not match exactly one entry | `lookupSoupEntryIdForSoupName:...` |
| 2 | no index defined for the field path | `lookupSoupEntryIdForSoupName:...` |
| 3 | external id value is empty | upsert with external id path |
| 5 | `whereArgs` only supported for smart queries | `queryWithQuerySpec:pageIndex:whereArgs:error:` |
| 999 | exception caught (SQL error, invalid soup/index, invalid Smart SQL, ...) | `inDatabase:` / `inTransaction:` |

Methods **with** an `error:` parameter surface failures. Methods **without** one either swallow them or let them propagate, depending on whether they run through SmartStore's exception-catching wrappers (`alterSoup:...` is the exception to the list below, see its section: it has no `NSError` parameter, but its steps run directly inside FMDB transactions, so a SQL failure propagates as an `NSException`). These swallow failures: `clearSoup:`, `removeSoup:`, `removeAllSoups`, `reIndexSoup:...`, `retrieveEntries:fromSoup:`, `upsertEntries:toSoup:`, `soupExists:`, `indicesForSoup:`, `allSoupNames`, `removeEntries:fromSoup:` and `removeEntriesByQuery:fromSoup:` (the void versions). Several of these use `__block` result variables that are not initialized, so after a swallowed exception the return value is undefined (`soupExists:` and `reIndexSoup:...` use `__block BOOL result;`, `SFSmartStore.m:1020,1908`). `countWithQuerySpec:error:` has the same problem with `__block NSInteger result;` (`SFSmartStore.m:1312`): on failure `*error` is set, but it still returns an `NSNumber` wrapping an uninitialized value instead of `nil`. Object-typed `__block` results (`NSArray*`) are zero-initialized by ARC, so those methods return `nil`.

Notifications and analytics:

- `kSFSmartStoreJSONParseErrorNotification` (`SmartStore.JSONParseErrorNotification`) is posted when JSON validation is enabled and parsing fails. `kSFSmartStoreJSONSerializationErrorNotification` is defined in the `.m` and not declared in any header; `buildEventOnJsonSerializationErrorForUser:...` posts `kSFSmartStoreJSONParseErrorNotification` (not the serialization constant).
- Analytics events (`SFSDKEventBuilderHelper`): `userSmartStoreInit`, `globalSmartStoreInit`, `registerSoup`, `SmartStoreJSONParseError`, `SmartStoreJSONSerializationError`.
- Logging: `SFSDKSmartStoreLogger` (`d:`, `e:`, `w:`, `i:`, `v:` with format). `SFSDKSmartStoreLogger setLogLevel:` is used in tests.

---

## Threading Model and Limits

- Each store owns one `FMDatabaseQueue` = one `FMDatabase` and one **serial** dispatch queue. Every public operation is a synchronous `dispatch_sync` onto that queue: the caller blocks until the work is done, and operations on the same store are fully serialized. Different stores have separate queues and separate files.
- It is safe to call from any thread; do not call from the main thread for large operations. Do not re-enter the same store from inside a block that is running on its queue (see [Transactions](#transactions)).
- The store registries and `removeShared...` methods synchronize on the class; `SFSmartStoreDatabaseManager` registry methods synchronize on the manager class.
- The `SFSmartStore` instance holds observers for `UIApplicationProtectedDataDidBecomeAvailable` / `WillBecomeUnavailable` (tracked by `isFileDataProtectionActive`; always `NO` on the simulator per the header comment) and removes them in `dealloc`.

Limits visible in code:

| Limit | Value / source |
|---|---|
| Per-store caches | 1024 entries each (`CACHES_COUNT_LIMIT`) |
| Default page size from dictionary | 10 (`kQuerySpecDefaultPageSize`) |
| Page size in Swift `query(_:)` helper | 65536, first page only (`Constants.PAGE_SIZE`) |
| Page size in factories | no cap |
| Salt length | 16 bytes |
| PBKDF iterations | `kdf_iter = 4000` |
| Max entry / soup / store size, number of index specs | none enforced by SmartStore code (SQLite / SQLCipher limits apply; no limit constants besides the ones above exist in `libs/SmartStore`) |

---

## Declarative Store Configuration

`SFSDKStoreConfig` (Swift: `StoreConfig`) loads soup definitions from a JSON resource (`SFSDKResourceUtils loadConfigFromFile:`):

```json
{
  "soups": [
    {
      "soupName": "accounts",
      "indexes": [
        { "path": "Id",   "type": "string" },
        { "path": "Name", "type": "full_text" }
      ]
    }
  ]
}
```

```objc
- (nullable instancetype)initWithResourceAtPath:(NSString *)path;
- (void)registerSoups:(SFSmartStore *)store;   // skips soups that already exist; errors only logged
- (BOOL)hasSoups;
```

`SmartStoreSDKManager` reads `globalstore.json` and `userstore.json` (`pathForGlobalStoreConfig` / `pathForUserStoreConfig`) with the default store name, but only when the app calls `setupGlobalStoreFromDefaultConfig` / `setupUserStoreFromDefaultConfig` (nothing in the SDK calls them automatically; `SFSDKStoreConfig` logs the registration error format string incorrectly, so the `NSError` itself is not included in the log message). Examples: `libs/SmartStore/SmartStoreTestApp/globalstore.json`, `userstore.json`. This config only supports soup names and index specs.

---

## Swift and Combine Extensions

`Classes/Extensions/SmartStore.swift` (all on the Swift name `SmartStore`):

```swift
public enum SmartStoreError: Error { case error(_ error: Error?); case unknown }

extension SmartStore {
    /// Registers a soup indexing every path as JSON1
    public func registerSoup(withName soupName: String,
                             withIndexPaths indexPaths: [String]) -> Result<Bool, SmartStoreError>

    /// Runs a smart SQL query (page 0, page size 65536)
    public func query(_ smartSql: String) -> Result<[Any], SmartStoreError>

    /// Same query wrapped in a Combine Future
    public func publisher(for smartSql: String) -> Future<[Any], SmartStoreError>
}
```

Notes:

- `registerSoup(withName:withIndexPaths:)` always uses `kSoupIndexTypeJSON1`; use the throwing `registerSoup(withName:withIndices:)` for other index types.
- `query(_:)` returns only the first 65536 rows.
- `publisher(for:)` is a `Future` whose closure runs **immediately and synchronously on the creating thread** (the query executes when the `Future` is created, not on subscription). Subscribers receive the stored result.

Swift usage:

```swift
let store = SmartStore.shared(withName: SmartStore.defaultStoreName)!

try store.registerSoup(withName: "accounts", withIndices: [
    SoupIndex(path: "Id", indexType: kSoupIndexTypeString, columnName: nil)!,
    SoupIndex(path: "Name", indexType: kSoupIndexTypeFullText, columnName: nil)!
])

store.upsert(entries: [["Id": "001", "Name": "Acme"]], forSoupNamed: "accounts")

let spec = QuerySpec.buildExactQuerySpec(soupName: "accounts", path: "Id", matchKey: "001",
                                         orderPath: "Id", order: .ascending, pageSize: 10)
let rows = try store.query(using: spec, startingFromPageIndex: 0)
```

Obj-C usage:

```objc
SFSmartStore *store = [SFSmartStore sharedStoreWithName:kDefaultSmartStoreName];
NSError *error = nil;
[store registerSoup:@"accounts"
     withIndexSpecs:@[
         [[SFSoupIndex alloc] initWithPath:@"Id"   indexType:kSoupIndexTypeString   columnName:nil],
         [[SFSoupIndex alloc] initWithPath:@"Name" indexType:kSoupIndexTypeFullText columnName:nil]]
              error:&error];

NSArray *saved = [store upsertEntries:@[@{@"Id": @"001", @"Name": @"Acme"}]
                               toSoup:@"accounts"
                   withExternalIdPath:@"Id"
                                error:&error];

SFQuerySpec *spec = [SFQuerySpec newAllQuerySpec:@"accounts" withOrderPath:@"Name"
                                       withOrder:kSFSoupQuerySortOrderAscending withPageSize:25];
NSArray *entries = [store queryWithQuerySpec:spec pageIndex:0 error:&error];
NSNumber *total  = [store countWithQuerySpec:spec error:&error];
```

---

## Not Present on iOS

Searched `libs/SmartStore` and the rest of the iOS repo:

- **`SFSoupSpec` does not exist.** The name appears only as a forward declaration (`@class SFSoupSpec;` in `SFSmartStore.h` and `SFAlterSoupLongOperation.h`) and as `soupSpec` / `oldSoupSpec` properties on `SFAlterSoupLongOperation` that are never assigned, plus the unused constants `NEW_SOUP_SPEC` / `OLD_SOUP_SPEC`. There is no soup-level spec API: `registerSoup` takes only index specs.
- **Soup features / external storage do not exist.** No `registerSoupWithSpec:`, no external-storage feature, no soup file directory. The only references are leftovers: the `kSFSmartStoreErrorLoadExternalSoup` constant (never used), the doc comment on `jsonSerializationCheckEnabled` ("soup entries that use external storage"), and a comment in `createMetaTables`.
- No `SFSoupSpec`-based equivalent exists on Android in the checked-out repo either (no `SoupSpec` class under `SalesforceMobileSDK-Android/libs/SmartStore/src`).
- No `_soupCreatedDate` JSON field (only the `created` column / Smart SQL token).
- No public transaction API (see [Transactions](#transactions)).
- No key rotation API.

---

## Testing

Tests live in `libs/SmartStore/SmartStoreTests` (scheme `SmartStore`, test bundle `SmartStoreTests`; host app `SmartStoreTestApp`).

| File | Covers |
|---|---|
| `SFSmartStoreTests.m` | Core CRUD, soups, indexes, queries, SQLCipher info, FTS5 default, JSON1 (no test uses a non-nil `withExternalIdPath:`) |
| `SFSmartStoreAlterTests.m` | `alterSoup`, step-by-step resumption |
| `SFSmartStoreFullTextSearchTests.m` (+ `.h`) | FTS4 and FTS5 register/insert/update/delete/clear/search |
| `SFSmartStoreFullTextSearchSpeedTests.m`, `SFSmartStoreLoadTests.m` | Performance / load |
| `SFSmartSqlTests.m` | Smart SQL conversion and execution |
| `SFSmartSqlCacheTests.m` | smartSql → sql cache |
| `SFQuerySpecTests.m` | Query spec SQL generation |
| `SFMultipleSmartStoresTests.m` | Multiple user / global stores, store names, removal |
| `SFSDKStoreConfigTests.m` | JSON config loading and `setup{Global,User}StoreFromDefaultConfig` |
| `SmartStoreSDKManagerTests.m` | `SmartStoreSDKManager` dev-support infos and the "Inspect SmartStore" dev action (no tests for config setup or logout cleanup) |
| `SmartStoreTests.swift` | Swift extensions (`registerSoup(withName:withIndexPaths:)`, `query(_:)`) |
| `SFSmartStoreTestCase.m/.h` | Base class: creates a test user and stores, JSON comparison helpers |

Tests import `SFSmartStore+Internal.h` and use internal methods (including `withDb:` variants, `clearSharedStoreMemoryState`, and `ftsExtension`).

Run (from the repo root, per `CLAUDE.md`):

```bash
# Whole SmartStore suite
xcodebuild test -workspace SalesforceMobileSDK.xcworkspace \
  -scheme SmartStore \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6'

# One test class
xcodebuild test -workspace SalesforceMobileSDK.xcworkspace \
  -scheme SmartStore \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' \
  -only-testing:SmartStoreTests/SFSmartSqlTests
```

CI: `.github/workflows/nightly.yaml` includes `SmartStore` in its library matrix (`lib: [SalesforceSDKCommon, SalesforceAnalytics, SalesforceSDKCore, SmartStore, MobileSync]`). `.github/workflows/pr.yaml` runs a `test-orchestrator` job whose `libs` output is the matrix of libraries to test for the PR.

---

## Dependencies

From `SmartStore.podspec`: `FMDB/SQLCipher ~> 2.7.12` and `SQLCipher ~> 4.17.0` (CocoaPods). The Xcode project pins `forcedotcom/fmdb` at exactly `2.7.12-sqlcipher` and SQLCipher 4.17.0 for SwiftPM builds (`libs/SmartStore/SmartStore.xcodeproj/project.pbxproj`); there is no root `Package.swift`.
