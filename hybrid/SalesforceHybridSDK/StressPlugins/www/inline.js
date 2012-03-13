//Sample code for Hybrid REST Explorer

var lastSoupCursor = null;

function regLinkClickHandlers() {
    SFHybridApp.logToConsole("regLinkClickHandlers");

    
    $('#link_reset').click(function() {
                           SFHybridApp.logToConsole("link_reset clicked");
                           $("#div_device_contact_list").html("");
                           $("#div_sfdc_contact_list").html("");
                           $("#div_sfdc_account_list").html("");
                           $("#div_sfdc_soup_entry_list").html("");
                           $("#console").html("");
    });
                  
   $('#link_start_tests').click(function() {
                           SFHybridApp.logToConsole("link_start_tests clicked");
                           kickStartTests();
					});
         
      
    if (!PhoneGap.hasResource("smartstore")) {
        SFHybridApp.logToConsole("no resource smartstore ???");
    }

                              
}

/*
Can be used from native side to start the tests
*/
function kickStartTests() {
    navigator.testrunner.setTestSuite('SmartStoreLoadTestSuite');
    navigator.testrunner.testSuite.startTests();
}




