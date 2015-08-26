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

var { SFOauthReactBridge } = require('react-native').NativeModules;

/**
 * exec
 */
var exec = function(successCB, errorCB, methodName, args) {
    var func = "SFOauthReactBridge." + methodName;
    console.log(func + " called: " + JSON.stringify(args));
    SFOauthReactBridge[methodName](args, function(error, result) {
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
 * Whether or not logout has already been initiated.  Can only be initiated once
 * per page load.
 */
var logoutInitiated = false;

/**
 * Obtain authentication credentials.
 *   success - The success callback function to use.
 *   fail    - The failure/error callback function to use.
 * Returns a dictionary with:
 *     accessToken
 *     refreshToken
 *     clientId
 *     userId
 *     orgId
 *     loginUrl
 *     instanceUrl
 *     userAgent
 */
var getAuthCredentials = function (success, fail) {
    exec(success, fail, "getAuthCredentials", {});
};

/**
 * Logout the current authenticated user. This removes any current valid session token
 * as well as any OAuth refresh token.  The user is forced to login again.
 * This method does not call back with a success or failure callback, as 
 * (1) this method must not fail and (2) in the success case, the current user
 * will be logged out and asked to re-authenticate.  Note also that this method can only
 * be called once per page load.  Initiating logout will ultimately redirect away from
 * the given page (effectively resetting the logout flag), and calling this method again
 * while it's currently processing will result in app state issues.
 */
var logout = function () {
    if (!logoutInitiated) {
        logoutInitiated = true;
        exec(null, null, "logoutCurrentUser", {});
    }
};

/**
 * Part of the module that is public
 */
module.exports = {
    getAuthCredentials: getAuthCredentials,
    logout: logout,
};
