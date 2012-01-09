/**
 * Utility functionality for hybrid apps.
 * Note: This JS module assumes the inclusion of a) the PhoneGap JS libraries and
 * b) the jQuery libraries.
 */

var appStartTime = new Date();  // Used for debug timing measurements.

/**
 * Logs debug messages to a "debug console" section of the page.  Only
 * shows when debugMode (above) is set to true.
 *   txt - The text (html) to log to the console.
 */
function logToConsole(txt) {
    if ((typeof debugMode !== "undefined") && (debugMode === true)) {
        $("#console").css("display", "block");
        log("#console", txt);
    }
}
        
/**
 * Use to log error messages to an "error console" section of the page.
 *   txt - The text (html) to log to the console.
 */
function logError(txt) {
    $("#errors").css("display", "block");
    log("#errors", txt);
}
        
/**
 * Logs text to a given section of the page.
 *   section - HTML section (CSS-identified) to log to.
 *   txt - The text (html) to log.
 */
function log(section, txt) {
    console.log("jslog:" + txt);
    var now = new Date();
    var fullTxt = "<p><i><b>* At " + (now.getTime() - appStartTime.getTime()) + "ms:</b></i> " + txt + "</p>";
    $(section).append(fullTxt);
}
