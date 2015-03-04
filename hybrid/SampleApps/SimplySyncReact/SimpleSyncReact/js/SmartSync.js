'use strict';

var { SFSmartSyncReactBridge } = require('NativeModules');

var syncDown = function(target, soupName, options, successCB, errorCB) {
    SFSmartSyncReactBridge.syncDown(
        {"target": target, "soupName": soupName, "options": options},
        successCB || function() { console.log("Bridged call succeeded"); },
        errorCB || function(err) { console.err("Bridge call failed " + err); }
    );        
};

var reSync = function(syncId, successCB, errorCB) {
    SFSmartSyncReactBridge.reSync(
        {"syncId": syncId},
        successCB || function() { console.log("Bridged call succeeded"); },
        errorCB || function(err) { console.err("Bridge call failed " + err); }
    );        
};


var syncUp = function(soupName, options, successCB, errorCB) {
    SFSmartSyncReactBridge.syncUp(
        {"soupName": soupName, "options": options},
        successCB || function() { console.log("Bridged call succeeded"); },
        errorCB || function(err) { console.err("Bridge call failed " + err); }
    );        
};

var getSyncStatus = function(syncId, successCB, errorCB) {
    SFSmartSyncReactBridge.getSyncStatus(
        {"syncId": syncId},
        successCB || function() { console.log("Bridged call succeeded"); },
        errorCB || function(err) { console.err("Bridge call failed " + err); }
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
