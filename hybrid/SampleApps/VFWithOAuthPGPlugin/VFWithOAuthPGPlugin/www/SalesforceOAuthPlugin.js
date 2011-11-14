var SalesforceOAuthPlugin = {
    getLoginHost: function(success, fail) {
        PhoneGap.exec(success, fail, "com.salesforce.oauth", "getLoginHost", []);
    },
    
    authenticate: function(success, fail, oauthProperties) {
        PhoneGap.exec(success, fail, "com.salesforce.oauth", "authenticate", [JSON.stringify(oauthProperties)]);
    }
};

/**
 OAuthProperties data structure, for plugin arguments.
 */
function OAuthProperties(remoteAccessConsumerKey, oauthRedirectURI, oauthLoginDomain, oauthScopes, userAccountIdentifier) {
    this.remoteAccessConsumerKey = remoteAccessConsumerKey;
    this.oauthRedirectURI = oauthRedirectURI;
    this.oauthLoginDomain = oauthLoginDomain;
    this.oauthScopes = oauthScopes;
    this.userAccountIdentifier = userAccountIdentifier;
}