//Sample code for Hybrid REST Explorer

var lastSoupCursor = null;

function regLinkClickHandlers() {
    var logToConsole = cordova.require("salesforce/util/logger").logToConsole;
    logToConsole("regLinkClickHandlers");

    
    $('#link_reset').click(function() {
                           logToConsole("link_reset clicked");
                           $("#div_device_contact_list").html("");
                           $("#div_sfdc_contact_list").html("");
                           $("#div_sfdc_account_list").html("");
                           $("#div_sfdc_soup_entry_list").html("");
                           $("#console").html("");
    });
}





