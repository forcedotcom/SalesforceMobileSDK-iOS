'use strict';

var { SFSmartStoreReactBridge } = require('NativeModules');

/**
 * SoupIndexSpec consturctor
 */
var SoupIndexSpec = function (path, type) {
    this.path = path;
    this.type = type;
};

/**
 * QuerySpec constructor
 */
var QuerySpec = function (path) {
    // the kind of query, one of: "exact","range", "like" or "smart":
    // "exact" uses matchKey, "range" uses beginKey and endKey, "like" uses likeKey, "smart" uses smartSql
    this.queryType = "exact";

    //path for the original IndexSpec you wish to use for search: may be a compound path eg Account.Owner.Name
    this.indexPath = path;

    //for queryType "exact"
    this.matchKey = null;

    //for queryType "like"
    this.likeKey = null;
    
    //for queryType "range"
    //the value at which query results may begin
    this.beginKey = null;
    //the value at which query results may end
    this.endKey = null;

    // for queryType "smart"
    this.smartSql = null;

    //"ascending" or "descending" : optional
    this.order = "ascending";

    //the number of entries to copy from native to javascript per each cursor page
    this.pageSize = 10;
};

/**
 * StoreCursor constructor
 */
var StoreCursor = function () {
    //a unique identifier for this cursor, used by plugin
    this.cursorId = null;
    //the maximum number of entries returned per page 
    this.pageSize = 0;
    // the total number of results
    this.totalEntries = 0;
    //the total number of pages of results available
    this.totalPages = 0;
    //the current page index among all the pages available
    this.currentPageIndex = 0;
    //the list of current page entries, ordered as requested in the querySpec
    this.currentPageOrderedEntries = null;
};

// ====== Logging support ======
var logLevel;
var storeConsole = {};

var setLogLevel = function(level) {
    logLevel = level;
    var methods = ["error", "info", "warn", "debug"];
    var levelAsInt = methods.indexOf(level.toLowerCase());
    for (var i=0; i<methods.length; i++) {
        storeConsole[methods[i]] = (i <= levelAsInt ? console[methods[i]].bind(console) : function() {});
    }
};
// Showing info and above (i.e. error) by default
setLogLevel("info");

var getLogLevel = function () {
    return logLevel;
};


// ====== querySpec factory methods
// Returns a query spec that will page through all soup entries in order by the given path value
// Internally it simply does a range query with null begin and end keys
var buildAllQuerySpec = function (path, order, pageSize) {
    var inst = new QuerySpec(path);
    inst.queryType = "range";
    if (order) { inst.order = order; } // override default only if a value was specified
    if (pageSize) { inst.pageSize = pageSize; } // override default only if a value was specified
    return inst;
};

// Returns a query spec that will page all entries exactly matching the matchKey value for path
var buildExactQuerySpec = function (path, matchKey, pageSize) {
    var inst = new QuerySpec(path);
    inst.matchKey = matchKey;
    if (pageSize) { inst.pageSize = pageSize; } // override default only if a value was specified
    return inst;
};

// Returns a query spec that will page all entries in the range beginKey ...endKey for path
var buildRangeQuerySpec = function (path, beginKey, endKey, order, pageSize) {
    var inst = new QuerySpec(path);
    inst.queryType = "range";
    inst.beginKey = beginKey;
    inst.endKey = endKey;
    if (order) { inst.order = order; } // override default only if a value was specified
    if (pageSize) { inst.pageSize = pageSize; } // override default only if a value was specified
    return inst;
};

// Returns a query spec that will page all entries matching the given likeKey value for path
var buildLikeQuerySpec = function (path, likeKey, order, pageSize) {
    var inst = new QuerySpec(path);
    inst.queryType = "like";
    inst.likeKey = likeKey;
    if (order) { inst.order = order; } // override default only if a value was specified
    if (pageSize) { inst.pageSize = pageSize; } // override default only if a value was specified
    return inst;
};

// Returns a query spec that will page all results returned by smartSql
var buildSmartQuerySpec = function (smartSql, pageSize) {
    var inst = new QuerySpec();
    inst.queryType = "smart";
    inst.smartSql = smartSql;
    if (pageSize) { inst.pageSize = pageSize; } // override default only if a value was specified
    return inst;
};

// ====== Soup manipulation ======
var getDatabaseSize = function(successCB, errorCB) {
    storeConsole.debug("SmartStore.getDatabaseSize");
    SFSmartStoreReactBridge.getDatabaseSize(
        {}, 
        successCB, 
        errorCB
    );
};

var registerSoup = function (soupName, indexSpecs, successCB, errorCB) {
    storeConsole.debug("SmartStore.registerSoup: '" + soupName + "' indexSpecs: " + JSON.stringify(indexSpecs));
    SFSmartStoreReactBridge.registerSoup(
        {"soupName": soupName, "indexes": indexSpecs},
        successCB,
        errorCB
    );
};

var removeSoup = function (soupName, successCB, errorCB) {
    storeConsole.debug("SmartStore.removeSoup: " + soupName);
    SFSmartStoreReactBridge.removeSoup(
        {"soupName": soupName},
        successCB,
        errorCB
    );
};

var getSoupIndexSpecs = function(soupName, successCB, errorCB) {
    storeConsole.debug("SmartStore.getSoupIndexSpecs: " + soupName);
    SFSmartStoreReactBridge.getSoupIndexSpecs(
        {"soupName": soupName},
        successCB,
        errorCB
    );
};

var alterSoup = function (soupName, indexSpecs, reIndexData, successCB, errorCB) {
    storeConsole.debug("SmartStore.alterSoup: '" + soupName + "' indexSpecs: " + JSON.stringify(indexSpecs));
    SFSmartStoreReactBridge.alterSoup(
        {"soupName": soupName, "indexes": indexSpecs, "reIndexData": reIndexData},
        successCB,
        errorCB
    );
};

var reIndexSoup = function (soupName, paths, successCB, errorCB) {
    storeConsole.debug("SmartStore.reIndexSoup: '" + soupName + "' paths: " + JSON.stringify(paths));
    SFSmartStoreReactBridge.reIndexSoup(
        {"soupName": soupName, "paths": paths},
        successCB,
        errorCB
    );
};

var clearSoup = function (soupName, successCB, errorCB) {
    storeConsole.debug("SmartStore.clearSoup: '" + soupName + "'");
    SFSmartStoreReactBridge.clearSoup(
        {"soupName": soupName},
        successCB,
        errorCB
    );
};

var showInspector = function(successCB, errorCB) {
    storeConsole.debug("SmartStore.showInspector");
    SFSmartStoreReactBridge.showInspector(
        [],
        successCB,
        errorCB
    );
};

var soupExists = function (soupName, successCB, errorCB) {
    storeConsole.debug("SmartStore.soupExists: " + soupName);
    SFSmartStoreReactBridge.soupExists(
        {"soupName": soupName},
        successCB,
        errorCB
    );
};

var querySoup = function (soupName, querySpec, successCB, errorCB) {
    if (querySpec.queryType == "smart") throw new Error("Smart queries can only be run using runSmartQuery");
    storeConsole.debug("SmartStore.querySoup: '" + soupName + "' indexPath: " + querySpec.indexPath);
    SFSmartStoreReactBridge.querySoup(
        {"soupName": soupName, "querySpec": querySpec},
        successCB,
        errorCB
    );
};

var runSmartQuery = function (querySpec, successCB, errorCB) {
    if (querySpec.queryType != "smart") throw new Error("runSmartQuery can only run smart queries");
    storeConsole.debug("SmartStore.runSmartQuery: smartSql: " + querySpec.smartSql);
    SFSmartStoreReactBridge.runSmartQuery(
        {"querySpec": querySpec},
        successCB,
        errorCB
    );
};

var retrieveSoupEntries = function (soupName, entryIds, successCB, errorCB) {
    storeConsole.debug("SmartStore.retrieveSoupEntry: '" + soupName + "' entryIds: " + entryIds);
    SFSmartStoreReactBridge.retrieveSoupEntries(
        {"soupName": soupName, "entryIds": entryIds},
        successCB,
        errorCB
    );
};

var upsertSoupEntries = function (soupName, entries, successCB, errorCB) {
    upsertSoupEntriesWithExternalId(soupName, entries, "_soupEntryId", successCB, errorCB);
};

var upsertSoupEntriesWithExternalId = function (soupName, entries, externalIdPath, successCB, errorCB) {
    storeConsole.debug("SmartStore.upsertSoupEntries: '" + soupName + "' entries.length: " + entries.length);
    SFSmartStoreReactBridge.upsertSoupEntries(
        {"soupName": soupName, "entries": entries, "externalIdPath": externalIdPath},
        successCB,
        errorCB
    );
};

var removeFromSoup = function (soupName, entryIds, successCB, errorCB) {
    storeConsole.debug("SmartStore.removeFromSoup: '" + soupName + "' entryIds: " + entryIds);
    SFSmartStoreReactBridge.removeFromSoup(
        {"soupName": soupName, "entryIds": entryIds},
        successCB,
        errorCB
    );
};

//====== Cursor manipulation ======
var moveCursorToPageIndex = function (cursor, newPageIndex, successCB, errorCB) {
    storeConsole.debug("moveCursorToPageIndex: " + cursor.cursorId + "  newPageIndex: " + newPageIndex);
    SFSmartStoreReactBridge.moveCursorToPageIndex(
        {"cursorId": cursor.cursorId, "index": newPageIndex},
        successCB,
        errorCB
    );
};

var moveCursorToNextPage = function (cursor, successCB, errorCB) {
    var newPageIndex = cursor.currentPageIndex + 1;
    if (newPageIndex >= cursor.totalPages) {
        errorCB(cursor, new Error("moveCursorToNextPage called while on last page"));
    }
    else {
        moveCursorToPageIndex(cursor, newPageIndex, successCB, errorCB);
    }
};

var moveCursorToPreviousPage = function (cursor, successCB, errorCB) {
    var newPageIndex = cursor.currentPageIndex - 1;
    if (newPageIndex < 0) {
        errorCB(cursor, new Error("moveCursorToPreviousPage called while on first page"));
    }
    else {
        moveCursorToPageIndex(cursor, newPageIndex, successCB, errorCB);
    }
};

var closeCursor = function (cursor, successCB, errorCB) {
    storeConsole.debug("closeCursor: " + cursor.cursorId);
    SFSmartStoreReactBridge.closeCursor(
        {"cursorId": cursor.cursorId},
        successCB,
        errorCB
    );
};

/**
 * Part of the module that is public
 */
module.exports = {
    alterSoup: alterSoup,
    buildAllQuerySpec: buildAllQuerySpec,
    buildExactQuerySpec: buildExactQuerySpec,
    buildLikeQuerySpec: buildLikeQuerySpec,
    buildRangeQuerySpec: buildRangeQuerySpec,
    buildSmartQuerySpec: buildSmartQuerySpec,
    clearSoup: clearSoup,
    closeCursor: closeCursor,
    getDatabaseSize: getDatabaseSize,
    getLogLevel: getLogLevel,
    getSoupIndexSpecs: getSoupIndexSpecs,
    moveCursorToNextPage: moveCursorToNextPage,
    moveCursorToPageIndex: moveCursorToPageIndex,
    moveCursorToPreviousPage: moveCursorToPreviousPage,
    querySoup: querySoup,
    reIndexSoup: reIndexSoup,
    registerSoup: registerSoup,
    removeFromSoup: removeFromSoup,
    removeSoup: removeSoup,
    retrieveSoupEntries: retrieveSoupEntries,
    runSmartQuery: runSmartQuery,
    setLogLevel: setLogLevel,
    showInspector: showInspector,
    soupExists: soupExists,
    upsertSoupEntries: upsertSoupEntries,
    upsertSoupEntriesWithExternalId: upsertSoupEntriesWithExternalId,

    // Constructors
    QuerySpec: QuerySpec,
    SoupIndexSpec: SoupIndexSpec,
    StoreCursor: StoreCursor
};
