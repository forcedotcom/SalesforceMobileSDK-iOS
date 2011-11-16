var SalesforceOAuthPlugin = {

	/**
	* Obtain authentication credentials, calling 'authenticate' only if necessary.
	* Most index.html authors can simply use this method to obtain auth credentials
	* after onDeviceReady.
    *   success - The success callback function to use.
    *   fail    - The failure/error callback function to use.
	* PhoneGrap returns a dictionary with:
	* 	accessToken
	* 	refreshToken
	* 	userId
	* 	orgId
	* 	loginUrl
	* 	instanceUrl
	* 	apiVersion
	* 	userAgent
	*/
    getAuthCredentials: function(success, fail) {
        PhoneGap.exec(success, fail, "com.salesforce.oauth","getAuthCredentials",[]);
    },

    /**
     * Gets the login host configured in the settings for this application.
     *   success - The success callback function to use.
     *   fail    - The failure/error callback function to use.
     * PhoneGap return string:
     *   The literal login host (e.g. "login.salesforce.com").
     */
    getLoginHost: function(success, fail) {
        PhoneGap.exec(success, fail, "com.salesforce.oauth", "getLoginHost", []);
    },
    
    /**
     * Initiates the authentication process, with the given app configuration.
     *   success         - The success callback function to use.
     *   fail            - The failure/error callback function to use.
     *   oauthProperties - The configuration properties for the authentication process.
     *                     See OAuthProperties() below.
     * PhoneGap return string:
     *   JSON data object string with the following structure:
     *     { "accessToken": accessToken, "refreshToken": refreshToken, "clientId": clientId,
     *       "loginUrl": loginUrl, "userId": userId, "orgId": orgId,
     *       "instanceUrl": instanceUrl, "userAgent": userAgent, "apiVersion": apiVersion
     *     }
     */
    authenticate: function(success, fail, oauthProperties) {
        PhoneGap.exec(success, fail, "com.salesforce.oauth", "authenticate", [JSON.stringify(oauthProperties)]);
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
    }
};

/**
 * OAuthProperties data structure, for plugin arguments.
 *   remoteAccessConsumerKey - String containing the remote access object ID (client ID).
 *   oauthRedirectURI        - String containing the redirect URI configured for the remote access object.
 *   oauthLoginDomain        - String containing the login domain for authentication (e.g. login.salesforce.com).
 *   oauthScopes             - Array of strings specifying the authorization scope of the app (e.g ["api", "visualforce"]).
 *   userAccountIdentifier   - String containing a unique identifier to associated with the credentials store.
 *   autoRefreshOnForeground - Boolean, determines whether the container automatically refreshes OAuth session when app is foregrounded
 */
function OAuthProperties(remoteAccessConsumerKey, oauthRedirectURI, oauthLoginDomain, oauthScopes, userAccountIdentifier, autoRefreshOnForeground) {
    this.remoteAccessConsumerKey = remoteAccessConsumerKey;
    this.oauthRedirectURI = oauthRedirectURI;
    this.oauthLoginDomain = oauthLoginDomain;
    this.oauthScopes = oauthScopes;
    this.userAccountIdentifier = userAccountIdentifier;
    this.autoRefreshOnForeground = autoRefreshOnForeground;
}
