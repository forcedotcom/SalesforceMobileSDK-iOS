'use strict';

var { SFSmartSyncReactBridge } = require('NativeModules');

var syncDown = function(target, soupName, options, successCB, errorCB) {
    SFSmartSyncReactBridge.syncDown(
        {"target": target, "soupName": soupName, "options": options},
        successCB,
        errorCB
    );        
};

var reSync = function(syncId, successCB, errorCB) {
    SFSmartSyncReactBridge.reSync(
        {"syncId": syncId},
        successCB,
        errorCB
    );        
};


var syncUp = function(soupName, options, successCB, errorCB) {
    SFSmartSyncReactBridge.syncUp(
        {"soupName": soupName, "options": options},
        successCB,
        errorCB
    );        
};

var getSyncStatus = function(syncId, successCB, errorCB) {
    SFSmartSyncReactBridge.getSyncStatus(
        {"syncId": syncId},
        successCB,
        errorCB
    );        
};

var MERGE_MODE = {
    OVERWRITE: "OVERWRITE",
    LEAVE_IF_CHANGED: "LEAVE_IF_CHANGED"
};


module.exports = {
    MERGE_MODE: MERGE_MODE,
    syncDown: syncDown,
    syncUp: syncUp,
    getSyncStatus: getSyncStatus,
    reSync: reSync
};
