     
     
//-----------------------------------------------------------------
// Replace the values below with your own app configuration values.
//-----------------------------------------------------------------

// The client ID value specified for your remote access object that defines
// your application in Salesforce.
var remoteAccessConsumerKey = "3MVG9Iu66FKeHhINkB1l7xt7kR8czFcCTUhgoA8Ol2Ltf1eYHOU4SqQRSEitYFDUpqRWcoQ2.dBv_a1Dyu5xa";

// The redirect URI value specified for your remote access object that defines
// your application in Salesforce.
var oauthRedirectURI = "testsfdc:///mobilesdk/detect/oauth/done";

// The authorization/access scope(s) you wish to define for your application.
var oauthScopes = ["api"];


// The start page of the application.  This is the [pagePath] portion of
// http://[host]/[pagePath].  Leave blank to use the local index.html page.
var startPage = "";  // Used for local REST-based"index.html" PhoneGap app.
//var startPage = "apex/BasicVFPage"; //used for Visualforce-based apps


// Whether the container app should automatically refresh our oauth session on app foreground:
// generally a good idea.
var autoRefreshOnForeground = true; 
    
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
        
            

