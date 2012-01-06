var SalesforceOAuthPlugin = {

	/**
	* Obtain authentication credentials, calling 'authenticate' only if necessary.
	* Most index.html authors can simply use this method to obtain auth credentials
	* after onDeviceReady.
    *   success - The success callback function to use.
    *   fail    - The failure/error callback function to use.
	* PhoneGap returns a dictionary with:
	* 	accessToken
	* 	refreshToken
    *   clientId
	* 	userId
	* 	orgId
    *   loginUrl
	* 	instanceUrl
	* 	userAgent
	*/
    getAuthCredentials: function(success, fail) {
        PhoneGap.exec(success, fail, "com.salesforce.oauth","getAuthCredentials",[]);
    },
    
    /**
     * Initiates the authentication process, with the given app configuration.
     *   success         - The success callback function to use.
     *   fail            - The failure/error callback function to use.
     *   oauthProperties - The configuration properties for the authentication process.
     *                     See OAuthProperties() below.
     * PhoneGap returns a dictionary with:
     *   accessToken
     *   refreshToken
     *   clientId
     *   userId
     *   orgId
     *   loginUrl
     *   instanceUrl
     *   userAgent
     */
    authenticate: function(success, fail, oauthProperties) {
        PhoneGap.exec(success, fail, "com.salesforce.oauth", "authenticate", [JSON.stringify(oauthProperties)]);
    },


    /**
    * Logout the current authenticated user. This removes any current valid session token
    * as well as any OAuth refresh token.  The user is forced to login again.
    * This method does not call back with a success or failure callback, as 
    * (1) this method must not fail and (2) in the success case, the current user
    * will be logged out and asked to re-authenticate.
    */
    logout: function() {
        PhoneGap.exec(null, null, "com.salesforce.oauth","logoutCurrentUser",[]);
    },
    
    /**
     * Creates the full app URL, based on the user's start page and the instance where
     * the user is authenticated.
     *   pageLocation     - The user-defined start page on the service (e.g. apex/MyVisualForcePage).
     *   oauthCredentials - The credentials data, used to determine the instance URL.  See
     *                      authenticate() above for a description of the data structure.
     * Returns:
     *   Full URL to the user's page, e.g. https://na1.salesforce.com/apex/MyVisualForcePage.
     */
    buildAppUrl: function(pageLocation, oauthCredentials) {
        var instanceUrl = oauthCredentials.instanceUrl;

        // Manage '/' between instance and page URL on the page var side.
        if (instanceUrl.charAt(instanceUrl.length-1) == '/')
            instanceUrl = instanceUrl.substr(0, instanceUrl.length-1);

        var trimmedPageLocation = pageLocation.replace(/^\s+/, '').replace(/\s+$/, '');
        if (trimmedPageLocation == "" || trimmedPageLocation == "/")
            return oauthCredentials.instanceUrl + "/";
        if (trimmedPageLocation.charAt(0) != '/')
            trimmedPageLocation = "/" + trimmedPageLocation;

        return instanceUrl + trimmedPageLocation;
    },

    /**
     * Creates the default local URL to load when no start page is specified.
     * 
     */
    buildDefaultLocalUrl: function() {
		if (navigator.device.platform == "Android") {
			return "file:///android_asset/www/index.html";
		}
		else {
			return "index.html"; 
		}
    },
    
    /**
     * Load the URL using phonegap on Android and directly on other platforms
     *   fullAppUrl       - the full url to load
     */
    loadUrl: function(fullAppUrl) {
		if (navigator.device.platform == "Android") {
			navigator.app.loadUrl(fullAppUrl , {clearHistory:true});
		}
		else {
			location.href = fullAppUrl;
		}
    }
};

/**
 * OAuthProperties data structure, for plugin arguments.
 *   remoteAccessConsumerKey - String containing the remote access object ID (client ID).
 *   oauthRedirectURI        - String containing the redirect URI configured for the remote access object.
 *   oauthScopes             - Array of strings specifying the authorization scope of the app (e.g ["api", "visualforce"]).
 *   autoRefreshOnForeground - Boolean, determines whether the container automatically refreshes OAuth session when app is foregrounded
 */
function OAuthProperties(remoteAccessConsumerKey, oauthRedirectURI, oauthScopes, autoRefreshOnForeground) {
    this.remoteAccessConsumerKey = remoteAccessConsumerKey;
    this.oauthRedirectURI = oauthRedirectURI;
    this.oauthScopes = oauthScopes;
    this.autoRefreshOnForeground = autoRefreshOnForeground;
}
