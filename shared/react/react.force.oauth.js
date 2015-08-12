'use strict';

var { SFOauthReactBridge } = Require('react-native').NativeModules;

var accessToken = undefined;

/**
 * exec
 */
var exec = function(successCB, errorCB, methodName, args) {
    storeConsole.debug("SFOauthReactBridge." + methodName + " called: " + JSON.stringify(args));
    SFOauthReactBridge[methodName](args, function(result) {
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

var getAccessToken  = function(successCB, errorCB) {
    exec(function(token) {
        accessToken = token;
        if (successCB) {
            successCB(token);
        }
    }, errorCB, "getAccessToken", {});
    return accessToken;
};

module.exports = {
    getAccessToken: getAccessToken
};
