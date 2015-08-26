/*
 * Copyright (c) 2015, salesforce.com, inc.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification, are permitted provided
 * that the following conditions are met:
 *
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the
 * following disclaimer.
 *
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and
 * the following disclaimer in the documentation and/or other materials provided with the distribution.
 *
 * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to endorse or
 * promote products derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
 * PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 * TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

'use strict';

var { SFSmartStoreReactBridge } = require('react-native').NativeModules;

/**
 * exec
 */
var exec = function(successCB, errorCB, methodName, args) {
    var func = "SFSmartStoreReactBridge." + methodName;
    console.log(func + " called: " + JSON.stringify(args));
    SFSmartStoreReactBridge[methodName](args, function(error, result) {
        if (error) {
            console.log(func + " failed: " + JSON.stringify(error));
            if (errorCB) errorCB(error);
        }
        else {
            console.log(func + " succeeded");
            if (successCB) successCB(result);
        }
    });
};


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

    //for queryType "exact" and "match"
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

    //path to sort by : optional
    this.orderPath = null

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

// ====== querySpec factory methods
// Returns a query spec that will page through all soup entries in order by the given path value
// Internally it simply does a range query with null begin and end keys
var buildAllQuerySpec = function (path, order, pageSize) {
    var inst = new QuerySpec(path);
    inst.queryType = "range";
    inst.orderPath = path;
    if (order) { inst.order = order; } // override default only if a value was specified
    if (pageSize) { inst.pageSize = pageSize; } // override default only if a value was specified
    return inst;
};

// Returns a query spec that will page all entries exactly matching the matchKey value for path
var buildExactQuerySpec = function (path, matchKey, pageSize, order, orderPath) {
    var inst = new QuerySpec(path);
    inst.matchKey = matchKey;
    if (pageSize) { inst.pageSize = pageSize; } // override default only if a value was specified
    if (order) { inst.order = order; } // override default only if a value was specified
    inst.orderPath = orderPath ? orderPath : path;
    return inst;
};

// Returns a query spec that will page all entries in the range beginKey ...endKey for path
var buildRangeQuerySpec = function (path, beginKey, endKey, order, pageSize, orderPath) {
    var inst = new QuerySpec(path);
    inst.queryType = "range";
    inst.beginKey = beginKey;
    inst.endKey = endKey;
    if (order) { inst.order = order; } // override default only if a value was specified
    if (pageSize) { inst.pageSize = pageSize; } // override default only if a value was specified
    inst.orderPath = orderPath ? orderPath : path;
    return inst;
};

// Returns a query spec that will page all entries matching the given likeKey value for path
var buildLikeQuerySpec = function (path, likeKey, order, pageSize, orderPath) {
    var inst = new QuerySpec(path);
    inst.queryType = "like";
    inst.likeKey = likeKey;
    if (order) { inst.order = order; } // override default only if a value was specified
    if (pageSize) { inst.pageSize = pageSize; } // override default only if a value was specified
    inst.orderPath = orderPath ? orderPath : path;
    return inst;
};

// Returns a query spec that will page all entries matching the given full-text search matchKey value for path
// Pass null for path to match matchKey across all full-text indexed fields
var buildMatchQuerySpec = function (path, matchKey, order, pageSize, orderPath) {
    var inst = new QuerySpec(path);
    inst.queryType = "match";
    inst.matchKey = matchKey;
    inst.orderPath = orderPath;
    if (order) { inst.order = order; } // override default only if a value was specified
    if (pageSize) { inst.pageSize = pageSize; } // override default only if a value was specified
    inst.orderPath = orderPath ? orderPath : path;
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
var getDatabaseSize = function (isGlobalStore, successCB, errorCB) {
    exec(successCB, errorCB, "getDatabaseSize", {"isGlobalStore": isGlobalStore});
};

var registerSoup = function (isGlobalStore, soupName, indexSpecs, successCB, errorCB) {
    exec(successCB, errorCB, "registerSoup", {"soupName": soupName, "indexes": indexSpecs, "isGlobalStore": isGlobalStore});
};

var removeSoup = function (isGlobalStore, soupName, successCB, errorCB) {
    exec(successCB, errorCB, "removeSoup", {"soupName": soupName, "isGlobalStore": isGlobalStore});
};

var getSoupIndexSpecs = function(isGlobalStore, soupName, successCB, errorCB) {
    exec(successCB, errorCB, "getSoupIndexSpecs", {"soupName": soupName, "isGlobalStore": isGlobalStore});
};

var alterSoup = function (isGlobalStore, soupName, indexSpecs, reIndexData, successCB, errorCB) {
    exec(successCB, errorCB, "alterSoup", {"soupName": soupName, "indexes": indexSpecs, "reIndexData": reIndexData, "isGlobalStore": isGlobalStore});
};

var reIndexSoup = function (isGlobalStore, soupName, paths, successCB, errorCB) {
    exec(successCB, errorCB, "reIndexSoup", {"soupName": soupName, "paths": paths, "isGlobalStore": isGlobalStore});
};

var clearSoup = function (isGlobalStore, soupName, successCB, errorCB) {
    exec(successCB, errorCB, "clearSoup", {"soupName": soupName, "isGlobalStore": isGlobalStore});
};

var showInspector = function(isGlobalStore) {
    isGlobalStore = isGlobalStore || false;
    exec("ShowInspector", {"isGlobalStore": isGlobalStore});
};

var soupExists = function (isGlobalStore, soupName, successCB, errorCB) {
    exec(successCB, errorCB, "soupExists", {"soupName": soupName, "isGlobalStore": isGlobalStore});
};

var querySoup = function (isGlobalStore, soupName, querySpec, successCB, errorCB) {
    if (querySpec.queryType == "smart") throw new Error("Smart queries can only be run using runSmartQuery");
    if (querySpec.order != null && querySpec.orderPath == null) querySpec.orderPath = querySpec.indexPath; // for backward compatibility with pre-3.3 code
    exec(successCB, errorCB, "querySoup", {"soupName": soupName, "querySpec": querySpec, "isGlobalStore": isGlobalStore});
};

var runSmartQuery = function (isGlobalStore, querySpec, successCB, errorCB) {
    if (querySpec.queryType != "smart") throw new Error("runSmartQuery can only run smart queries");
    exec(successCB, errorCB, "runSmartQuery", {"querySpec": querySpec, "isGlobalStore": isGlobalStore});
};

var retrieveSoupEntries = function (isGlobalStore, soupName, entryIds, successCB, errorCB) {
    exec(successCB, errorCB, "retrieveSoupEntries", {"soupName": soupName, "entryIds": entryIds, "isGlobalStore": isGlobalStore});
};

var upsertSoupEntries = function (isGlobalStore, soupName, entries, successCB, errorCB) {
    upsertSoupEntriesWithExternalId(isGlobalStore, soupName, entries, "_soupEntryId", successCB, errorCB);
};

var upsertSoupEntriesWithExternalId = function (isGlobalStore, soupName, entries, externalIdPath, successCB, errorCB) {
    exec(successCB, errorCB, "upsertSoupEntries", {"soupName": soupName, "entries": entries, "externalIdPath": externalIdPath, "isGlobalStore": isGlobalStore});
};

var removeFromSoup = function (isGlobalStore, soupName, entryIds, successCB, errorCB) {
    isGlobalStore = isGlobalStore || false;
    exec(successCB, errorCB, "removeFromSoup", {"soupName": soupName, "entryIds": entryIds, "isGlobalStore": isGlobalStore});
};

//====== Cursor manipulation ======
var moveCursorToPageIndex = function (isGlobalStore, cursor, newPageIndex, successCB, errorCB) {
    exec(successCB, errorCB, "moveCursorToPageIndex", {"cursorId": cursor.cursorId, "index": newPageIndex, "isGlobalStore": isGlobalStore});
};

var moveCursorToNextPage = function (isGlobalStore, cursor, successCB, errorCB) {
    var newPageIndex = cursor.currentPageIndex + 1;
    if (newPageIndex >= cursor.totalPages) {
        errorCB(cursor, new Error("moveCursorToNextPage called while on last page"));
    } else {
        moveCursorToPageIndex(isGlobalStore, cursor, newPageIndex, successCB, errorCB);
    }
};

var moveCursorToPreviousPage = function (isGlobalStore, cursor, successCB, errorCB) {
    var newPageIndex = cursor.currentPageIndex - 1;
    if (newPageIndex < 0) {
        errorCB(cursor, new Error("moveCursorToPreviousPage called while on first page"));
    } else {
        moveCursorToPageIndex(isGlobalStore, cursor, newPageIndex, successCB, errorCB);
    }
};

var closeCursor = function (isGlobalStore, cursor, successCB, errorCB) {
    exec(successCB, errorCB, "closeCursor", {"cursorId": cursor.cursorId, "isGlobalStore": isGlobalStore});
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
    buildMatchQuerySpec: buildMatchQuerySpec,
    clearSoup: clearSoup,
    closeCursor: closeCursor,
    getDatabaseSize: getDatabaseSize,
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
    showInspector: showInspector,
    soupExists: soupExists,
    upsertSoupEntries: upsertSoupEntries,
    upsertSoupEntriesWithExternalId: upsertSoupEntriesWithExternalId,

    // Constructors
    QuerySpec: QuerySpec,
    SoupIndexSpec: SoupIndexSpec,
    StoreCursor: StoreCursor
};

