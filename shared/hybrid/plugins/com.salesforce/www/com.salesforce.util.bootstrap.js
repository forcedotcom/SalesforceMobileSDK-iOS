cordova.define("com.salesforce.util.bootstrap", function(require, exports, module) {/*
 * Copyright (c) 2012-13, salesforce.com, inc.
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

// Version this js was shipped with
var SALESFORCE_MOBILE_SDK_VERSION = "2.2.0.unstable";

var logger = require("com.salesforce.util.logger");

/**
 * Determine whether the device is online.
 */
var deviceIsOnline = function() {
    var connType;
    if (navigator && navigator.connection) {
        connType = navigator.connection.type;
        logger.logToConsole("deviceIsOnline connType: " + connType);
    } else {
        logger.logToConsole("deviceIsOnline connType is undefined.");
    }
    
    if (typeof connType !== 'undefined') {
        // Cordova's connection object.  May be more accurate?
        return (connType != null && connType != Connection.NONE && connType != Connection.UNKNOWN);
    } else {
        // Default to browser facility.
        return navigator.onLine;
    }
};

/**
 * Part of the module that is public
 */
module.exports = {
    deviceIsOnline: deviceIsOnline
};});
