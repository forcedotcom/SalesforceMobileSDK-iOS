'use strict';

var { SFSmartSyncReactBridge } = require('react-native').NativeModules;

/**
 * exec
 */
var exec = function(successCB, errorCB, methodName, args) {
    var func = "SFSmartSyncReactBridge." + methodName;
    console.log(func + " called: " + JSON.stringify(args));
    SFSmartSyncReactBridge[methodName](args, function(error, result) {
        if (error) {
            console.log(func + " failed: " + error);
            if (errorCB) errorCB(error);
        }
        else {
            console.log(func + " succeeded");
            if (successCB) successCB(result);
        }
    });
};

var syncDown = function(isGlobalStore, target, soupName, options, successCB, errorCB) {
    exec(successCB, errorCB, "syncDown", {"target": target, "soupName": soupName, "options": options, "isGlobalStore":isGlobalStore});        
};

var reSync = function(isGlobalStore, syncId, successCB, errorCB) {
    exec(successCB, errorCB, "reSync", {"syncId": syncId, "isGlobalStore":isGlobalStore});        
};


var syncUp = function(isGlobalStore, target, soupName, options, successCB, errorCB) {
    var args = Array.prototype.slice.call(arguments);
    // We accept syncUp(soupName, options, successCB, errorCB)
    if (typeof(args[0]) === "string") {
        isGlobalStore = false;
        target = {};
        soupName = args[0];
        options = args[1];
        successCB = args[2];
        errorCB = args[3];
    }
    // We accept syncUp(target, soupName, options, successCB, errorCB)
    if (typeof(args[0]) === "object") {
        isGlobalStore = false;
        target = args[0];
        soupName = args[1];
        options = args[2];
        successCB = args[3];
        errorCB = args[4];
    }
    target = target || {};

    exec(successCB, errorCB, "syncUp", {"target": target, "soupName": soupName, "options": options, "isGlobalStore":isGlobalStore});        
};

var getSyncStatus = function(isGlobalStore, syncId, successCB, errorCB) {
    exec(successCB, errorCB, "getSyncStatus", {"syncId": syncId, "isGlobalStore":isGlobalStore});        
};

var MERGE_MODE = {
    OVERWRITE: "OVERWRITE",
    LEAVE_IF_CHANGED: "LEAVE_IF_CHANGED"
};


/**
 * Part of the module that is public
 */
module.exports = {
    MERGE_MODE: MERGE_MODE,
    syncDown: syncDown,
    syncUp: syncUp,
    getSyncStatus: getSyncStatus,
    reSync: reSync
};
