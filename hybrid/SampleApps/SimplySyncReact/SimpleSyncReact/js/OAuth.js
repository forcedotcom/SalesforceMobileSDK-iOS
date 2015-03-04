'use strict';

var { SFOauthReactBridge } = require('NativeModules');

var accessToken = undefined;

var getAccessToken  = function(successCB, errorCB) {
    SFOauthReactBridge.getAccessToken(
        {},
        function(token) {
            accessToken = token;
            if (successCB) {
                successCB(token);
            }
        },
        errorCB || function(err) { console.err("Bridge call failed " + err); }
    );        
    return accessToken;
};

module.exports = {
    getAccessToken: getAccessToken
};
