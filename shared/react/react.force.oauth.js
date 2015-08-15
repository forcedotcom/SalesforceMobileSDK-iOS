'use strict';

var { SFOauthReactBridge } = Require('react-native').NativeModules;

var accessToken = undefined;

/**
 * exec
 */
var exec = function(successCB, errorCB, methodName, args) {
    console.log("SFOauthReactBridge." + methodName + " called: " + JSON.stringify(args));
    SFOauthReactBridge[methodName](args, function(result) {
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
