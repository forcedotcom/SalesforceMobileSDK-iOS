//Sample code for Hybrid REST Explorer

var lastSoupCursor = null;
var gTestSuiteSmartStore = null;


function regLinkClickHandlers() {
    SFHybridApp.logToConsole("regLinkClickHandlers");
    
    $('#link_reset').click(function() {
                           SFHybridApp.logToConsole("link_reset clicked");
                           $("#console").html("");
    });
                  
   $('#link_start_tests').click(function() {
                           SFHybridApp.logToConsole("link_start_tests clicked");
                           kickStartTests();
					});
         
    $('#link_logout').click(function() {
             SFHybridApp.logToConsole("link_logout clicked");
             SalesforceOAuthPlugin.logout();
             });               
    
}

/*
Can be used from native side to start the tests
*/
function kickStartTests() {
    gTestSuiteSmartStore = new SmartStoreTestSuite();
    gTestSuiteSmartStore.startTests();
}













