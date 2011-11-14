var SalesforceOAuthPlugin = {

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
    }
};

/**
 * OAuthProperties data structure, for plugin arguments.
 *   remoteAccessConsumerKey - String containing the remote access object ID (client ID).
 *   oauthRedirectURI        - String containing the redirect URI configured for the remote access object.
 *   oauthLoginDomain        - String containing the login domain for authentication (e.g. login.salesforce.com).
 *   oauthScopes             - Array of strings specifying the authorization scope of the app (e.g ["api", "visualforce"]).
 *   userAccountIdentifier   - String containing a unique identifier to associated with the credentials store.
 */
function OAuthProperties(remoteAccessConsumerKey, oauthRedirectURI, oauthLoginDomain, oauthScopes, userAccountIdentifier) {
    this.remoteAccessConsumerKey = remoteAccessConsumerKey;
    this.oauthRedirectURI = oauthRedirectURI;
    this.oauthLoginDomain = oauthLoginDomain;
    this.oauthScopes = oauthScopes;
    this.userAccountIdentifier = userAccountIdentifier;
}
