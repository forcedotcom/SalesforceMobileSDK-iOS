'use strict';

var { SFSmartSyncReactBridge } = require('react-native').NativeModules;

/**
 * exec
 */
var exec = function(successCB, errorCB, methodName, args) {
    storeConsole.debug("SFSmartSyncReactBridge." + methodName + " called: " + JSON.stringify(args));
    SFSmartStoreReactBridge[methodName](args, function(result) {
        if (result.length == 0) {
            storeConsole.debug(methodName + " failed: " + resullt[0]);
            if (errorCB) errorCB(result[0]);
        }
        else {
            storeConsole.debug(methodName + " succeeded");
            if (successCB) successCB(result[1]);
        }
    });
};


// NB: also in smartstore plugin
var checkFirstArg = function(argumentsOfCaller) {
    var args = Array.prototype.slice.call(argumentsOfCaller);
    if (typeof(args[0]) !== "boolean") {
        args.unshift(false);
        argumentsOfCaller.callee.apply(null, args);
        return true;
    }
    else {
        return false;
    }
};


var syncDown = function(isGlobalStore, target, soupName, options, successCB, errorCB) {
    if (checkFirstArg(arguments)) return;
    exec(successCB, errorCB, "syncDown", {"target": target, "soupName": soupName, "options": options, "isGlobalStore":isGlobalStore});        
};

var reSync = function(isGlobalStore, syncId, successCB, errorCB) {
    if (checkFirstArg(arguments)) return;
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
    if (checkFirstArg(arguments, "boolean", false)) return;
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
