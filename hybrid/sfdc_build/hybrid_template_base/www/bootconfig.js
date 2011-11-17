     
     
//-----------------------------------------------------------------
// Replace the values below with your own app configuration values.
//-----------------------------------------------------------------

// The client ID value specified for your remote access object that defines
// your application in Salesforce.
var remoteAccessConsumerKey = "___VARIABLE_publicKey___";

// The redirect URI value specified for your remote access object that defines
// your application in Salesforce.
var oauthRedirectURI = "___VARIABLE_redirectURL___";

// The authorization/access scope(s) you wish to define for your application.
var oauthScopes = ["visualforce", "api"];

// An account identifier such as most recently used username, which you can use/vary e.g.
// to manage multiple account stores in your app.  You probably don't need to change this. 
var userAccountIdentifier = "Default";

// The start page of the application.  This is the [pagePath] portion of
// http://[host]/[pagePath].  Leave blank to use the local index.html page.
var startPage = "";  // Used for local REST-based"index.html" PhoneGap app.
//var startPage = "apex/BasicVFPage"; //used for Visualforce-based apps


// Whether the container app should automatically refresh our oauth session on app foreground:
// generally a good idea for Visualforce pages.  For REST-based apps we recommend using
// onAppResume to refresh if needed.
var autoRefreshOnForeground = false; //Use true for Visualforce-based apps
    
// This application retrieves login host information from the app's settings, using
// SalesforceOAuthPlugin.getLoginHost().  If you wish to supply the login host using
// another implementation, be sure to specify it in the OAuthProperties settings that
// are passed to SalesforceOAuthPlugin.authenticate().  See the receivedLoginHost()
// method.
//
// var loginHost = "login.salesforce.com";
    
//-----------------------------------------------------------------
// End configuration block
//-----------------------------------------------------------------
        
            

