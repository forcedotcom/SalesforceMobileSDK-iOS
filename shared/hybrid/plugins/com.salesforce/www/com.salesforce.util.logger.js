cordova.define("com.salesforce.util.logger", function(require, exports, module) {/*
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
var appStartTime = (new Date()).getTime();  // Used for debug timing measurements.

/**
 * Logs text to a given section of the page.
 *   section - id of HTML section to log to.
 *   txt - The text (html) to log.
 */
var log = function(section, txt) {
    console.log("jslog: " + txt);
    if ((typeof debugMode !== "undefined") && (debugMode === true)) {
        var now = new Date();
        var fullTxt = "<p><i><b>* At " + (now.getTime() - appStartTime) + "ms:</b></i> " + txt + "</p>";
        var sectionElt = document.getElementById(section);
        if (sectionElt) {
            sectionElt.style.display = "block";
            document.getElementById(section).innerHTML += fullTxt;
        }
    }
};

/**
 * Logs debug messages to a "debug console" section of the page.  Only
 * shows when debugMode (above) is set to true.
 *   txt - The text (html) to log to the console.
 */
var logToConsole = function(txt) {
    log("console", txt);
};

/**
 * Use to log error messages to an "error console" section of the page.
 *   txt - The text (html) to log to the console.
 */
var logError = function(txt) {
    log("errors", txt);
};

/**
 * Sanitizes a URL for logging, based on an array of querystring parameters whose
 * values should be sanitized.  The value of each querystring parameter, if found
 * in the URL, will be changed to '[redacted]'.  Useful for getting rid of secure
 * data on the querystring, so it doesn't get persisted in an app log for instance.
 *
 * origUrl            - Required - The URL to sanitize.
 * sanitizeParamArray - Required - An array of querystring parameters whose values
 *                                 should be sanitized.
 * Returns: The sanitzed URL.
 */
var sanitizeUrlParamsForLogging = function(origUrl, sanitizeParamArray) {
    var trimmedOrigUrl = origUrl.trim();
    if (trimmedOrigUrl === '')
        return trimmedOrigUrl;
    
    if ((typeof sanitizeParamArray !== "object") || (sanitizeParamArray.length === 0))
        return trimmedOrigUrl;
    
    var redactedUrl = trimmedOrigUrl;
    for (var i = 0; i < sanitizeParamArray.length; i++) {
        var paramRedactRegexString = "^(.*[\\?&]" + sanitizeParamArray[i] + "=)([^&]+)(.*)$";
        var paramRedactRegex = new RegExp(paramRedactRegexString, "i");
        if (paramRedactRegex.test(redactedUrl))
            redactedUrl = redactedUrl.replace(paramRedactRegex, "$1[redacted]$3");
    }
    
    return redactedUrl;
};

/**
 * Part of the module that is public
 */
module.exports = {
    logToConsole: logToConsole,
    logError: logError,
    sanitizeUrlParamsForLogging: sanitizeUrlParamsForLogging
};});
