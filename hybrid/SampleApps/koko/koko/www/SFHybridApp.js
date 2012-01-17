/**
 * Utility functionality for hybrid apps.
 * Note: This JS module assumes the inclusion of a) the PhoneGap JS libraries and
 * b) the jQuery libraries.
 */
 
if (SFHybridApp == undefined) {

var SFHybridApp = {

appStartTime: new Date(),  // Used for debug timing measurements.

/**
 * Logs debug messages to a "debug console" section of the page.  Only
 * shows when debugMode (above) is set to true.
 *   txt - The text (html) to log to the console.
 */
logToConsole: function(txt) {
    if ((typeof debugMode !== "undefined") && (debugMode === true)) {
        $("#console").css("display", "block");
        SFHybridApp.log("#console", txt);
    }
},
        
/**
 * Use to log error messages to an "error console" section of the page.
 *   txt - The text (html) to log to the console.
 */
logError: function(txt) {
    $("#errors").css("display", "block");
    SFHybridApp.log("#errors", txt);
},
        
/**
 * Logs text to a given section of the page.
 *   section - HTML section (CSS-identified) to log to.
 *   txt - The text (html) to log.
 */
log: function(section, txt) {
    console.log("jslog:" + txt);
    var now = new Date();
    var fullTxt = "<p><i><b>* At " + (now.getTime() - SFHybridApp.appStartTime.getTime()) + "ms:</b></i> " + txt + "</p>";
    $(section).append(fullTxt);
},

/**
 * Creates the local URL to load.
 *   page - The local page value used to create the URL.
 * 
 * Returns:
 *   The local URL start page for the app.
 */
buildLocalUrl: function(page) {
    if (navigator.device.platform == "Android") {
        return SFHybridApp.buildAppUrl("file:///android_asset/www", page);
    }
    else {
        return page; 
    }
},

/**
 * Creates a fullly qualified URL from server and page information.
 * Example:
 *   var fullUrl = SFHybridApp.buildAppUrl("https://na1.salesforce.com", "apex/MyVisualForcePage");
 *
 *   server - The server URL prefix.
 *   page   - The page information to append to the server.
 * Returns:
 *   Full URL to the user's page, e.g. https://na1.salesforce.com/apex/MyVisualForcePage.
 */
buildAppUrl: function(server, page) {
    var trimmedServer = $.trim(server);
    var trimmedPage = $.trim(page);
    if (trimmedServer === "")
        return trimmedPage;
    else if (trimmedPage === "")
        return trimmedServer;
    
    // Manage '/' between server and page URL on the page var side.
    if (trimmedServer.charAt(trimmedServer.length-1) === '/')
        trimmedServer = trimmedServer.substr(0, trimmedServer.length-1);
    
    if (trimmedPage === "" || trimmedPage === "/")
        return trimmedServer + "/";
    if (trimmedPage.charAt(0) !== '/')
        trimmedPage = "/" + trimmedPage;
    
    return trimmedServer + trimmedPage;
},

/**
 * Load the given URL, using PhoneGap on Android, and loading directly on other platforms.
 *   fullAppUrl       - The URL to load.
 */
loadUrl: function(fullAppUrl) {
    if (navigator.device.platform == "Android") {
        navigator.app.loadUrl(fullAppUrl , {clearHistory:true});
    }
    else {
        location.href = fullAppUrl;
    }
},

/**
 * RemoteAppStartData data object - Represents the data associated with bootstrapping a
 * 'remote' app, i.e. a hybrid app with its content managed as a traditional server-side
 * web app, such as a Visualforce app.
 *
 *   appStartUrl        - Required - The "start page" of the hybrid application.
 *   isAbsoluteUrl      - Optional - Whether or not the start URL is a fully-qualified URL.
 *                                   Defaults to false.
 *   shouldAuthenticate - Optional - Whether or not to authenticate prior to loading the
 *                                   application.  Defaults to true.
 */
RemoteAppStartData: function(appStartUrl, isAbsoluteUrl, shouldAuthenticate) {
    if (typeof appStartUrl !== "string" || $.trim(appStartUrl) === "") {
        SFHybridApp.logError("appStartUrl cannot be empty");
        return;
    }
    this.appStartUrl = appStartUrl;
    this.isRemoteApp = true;
    this.isAbsoluteUrl = (typeof isAbsoluteUrl !== "boolean" ? false : isAbsoluteUrl);
    this.shouldAuthenticate = (typeof shouldAuthenticate !== "boolean" ? true : shouldAuthenticate);
},

/**
 * LocalAppStartData data object - Represents the data associated with bootstrapping a
 * 'local' app, i.e. a hybrid app with its content managed through a local web page,
 * such as a traditional PhoneGap app.
 *
 *   appStartUrl        - Optional - The local "start page" of the hybrid application.
 *                                   Defaults to "index.html".
 *   shouldAuthenticate - Optional - Whether or not to authenticate prior to loading the
 *                                   application.  Defaults to true.
 */
LocalAppStartData: function(appStartUrl, shouldAuthenticate) {
    this.appStartUrl = (typeof appStartUrl !== "string" || $.trim(appStartUrl) === "" ? "index.html" : appStartUrl);
    this.isRemoteApp = false;
    this.isAbsoluteUrl = false;
    this.shouldAuthenticate = (typeof shouldAuthenticate !== "boolean" ? true : shouldAuthenticate);
}

};

}
