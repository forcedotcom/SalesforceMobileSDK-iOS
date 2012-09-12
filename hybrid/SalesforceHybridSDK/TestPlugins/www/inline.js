//Sample code for Hybrid REST Explorer

var lastSoupCursor = null;


function regLinkClickHandlers() {
    var logToConsole = cordova.require("salesforce/util/logger").logToConsole;
    var smartStore = cordova.require("salesforce/plugin/smartstore");
    
    logToConsole("regLinkClickHandlers");

    
    $('#link_fetch_device_contacts').click(function() {
                                           var options = cordova.require("cordova/plugin/ContactFindOptions");
                                           var fields = ["name"];
                                           logToConsole("link_fetch_device_contacts clicked");
                                           options.filter = ""; // empty search string returns all contacts
                                           options.multiple = true;
                                           cordova.require("cordova/plugin/contacts").find(fields, onSuccessDevice, onErrorDevice, options);
                                           });
    
    $('#link_fetch_sfdc_contacts').click(function() {
                                         logToConsole("link_fetch_sfdc_contacts clicked");
                                         forcetkClient.query("SELECT Name,Id FROM Contact", onSuccessSfdcContacts, onErrorSfdc); 
                                         });
    
    $('#link_fetch_sfdc_accounts').click(function() {
         logToConsole("link_fetch_sfdc_accounts clicked");
         forcetkClient.query("SELECT Name FROM Account", onSuccessSfdcAccounts, onErrorSfdc); 
     });
    
    $('#link_reset').click(function() {
                           logToConsole("link_reset clicked");
                           $("#div_device_contact_list").html("");
                           $("#div_sfdc_contact_list").html("");
                           $("#div_sfdc_account_list").html("");
                           $("#div_sfdc_soup_entry_list").html("");
                           $("#console").html("");
    });
                  
   $('#link_logout').click(function() {
             logToConsole("link_logout clicked");
             cordova.require("salesforce/plugin/oauth").logout();
             });
    
    $('#link_reg_soup').click(function() {
      logToConsole("link_reg_soup clicked");

      var indexes = [
                     {path:"Name",type:"string"},
                     {path:"Id",type:"string"}
                     ];
        
      smartStore.registerSoup("myPeopleSoup",
                                        indexes,                                  
                                        onSuccessRegSoup, 
                                        onErrorRegSoup
        );
      
    });
    
                              
                              
    
    $('#link_stuff_soup').click(function() {
        logToConsole("link_stuff_soup clicked");

        var myEntry1 = { Name: "Todd Stellanova", Id: "00300A",  attributes:{type:"Contact"} };
        var myEntry2 = { Name: "Pro Bono Bonobo",  Id: "00300B", attributes:{type:"Contact"}  };
        var myEntry3 = { Name: "Robot", Id: "00300C", attributes:{type:"Contact"}  };

        var entries = [myEntry1,myEntry2,myEntry3];
        smartStore.upsertSoupEntries("myPeopleSoup",entries,onSuccessUpsert,onErrorUpsert);
        
    });
                            
    


    $('#link_remove_soup').click(function() {
        smartStore.removeSoup("myPeopleSoup",
                                     onSuccessRemoveSoup, 
                                     onErrorRemoveSoup);
    });
    

    

    $('#link_query_soup').click(function() {
        runQuerySoup();
    });

    
     $('#link_cursor_page_zero').click(function() {
        logToConsole("link_cursor_page_zero clicked");
        smartStore.moveCursorToPageIndex(lastSoupCursor,0, onSuccessQuerySoup,onErrorQuerySoup);
    });
     
     $('#link_cursor_page_prev').click(function() {
        logToConsole("link_cursor_page_prev clicked");
        smartStore.moveCursorToPreviousPage(lastSoupCursor,onSuccessQuerySoup,onErrorQuerySoup);
    });
     
    
    $('#link_cursor_page_next').click(function() {
        logToConsole("link_cursor_page_next clicked");
        smartStore.moveCursorToNextPage(lastSoupCursor,onSuccessQuerySoup,onErrorQuerySoup);
    });
}

function runQuerySoup() {
    var inputStr = $('#input_query_soup').val();
    if (inputStr.length === 0) {
        inputStr = null;
    }
    
    cordova.require("salesforce/util/logger").logToConsole("testSmartStoreQuerySoup: " + inputStr);

    var smartStore = cordova.require("salesforce/plugin/smartstore");
    var querySpec = new smartStore.SoupQuerySpec("Name",inputStr);
    querySpec.pageSize = 25;
                                
    smartStore.querySoup("myPeopleSoup",querySpec,
                                       onSuccessQuerySoup, 
                                       onErrorQuerySoup
                                                );
}
    
function onSuccessRegSoup(param) {
    cordova.require("salesforce/util/logger").logToConsole("onSuccessRegSoup: " + param);
}

function onErrorRegSoup(param) {
    cordova.require("salesforce/util/logger").logToConsole("onErrorRegSoup: " + param);
}

function onSuccessUpsert(param) {
    cordova.require("salesforce/util/logger").logToConsole("onSuccessUpsert: " + param);
}


function onErrorUpsert(param) {
    cordova.require("salesforce/util/logger").logToConsole("onErrorUpsert: " + param);
}


    
function onSuccessQuerySoup(cursor) {

    cordova.require("salesforce/util/logger").logToConsole("onSuccessQuerySoup totalPages: " + cursor.totalPages);
    lastSoupCursor = cursor;

    $("#div_sfdc_soup_entry_list").html("")
    var ul = $('<ul data-role="listview" data-inset="true" data-theme="a" data-dividertheme="a"></ul>');
    $("#div_sfdc_soup_entry_list").append(ul);
    
    var curPageEntries = cursor.currentPageOrderedEntries;
    
    $.each(curPageEntries, function(i,entry) {
           var formattedName = entry.name; 
           var entryId = entry._soupEntryId;
           var phatName = entry.Name;
        if (phatName) {
            formattedName = phatName;
        }

        var newLi = $("<li><a href='#'>" + entryId + " - " + formattedName + "</a></li>");
        ul.append(newLi);
    });
    
    $("#div_sfdc_soup_entry_list").trigger( "create" );

    
}


function onErrorQuerySoup(param) {
    cordova.require("salesforce/util/logger").logToConsole("onErrorQuerySoup: " + param);
}


function onSuccessRemoveSoup(param) {
    cordova.require("salesforce/util/logger").logToConsole("onSuccessRemoveSoup: " + param);
}
function onErrorRemoveSoup(param) {
    cordova.require("salesforce/util/logger").logToConsole("onErrorRemoveSoup: " + param);
}



function onSuccessDevice(contacts) {
    cordova.require("salesforce/util/logger").logToConsole("onSuccessDevice: received " + contacts.length + " contacts");
    $("#div_device_contact_list").html("")
    var ul = $('<ul data-role="listview" data-inset="true" data-theme="a" data-dividertheme="a"></ul>');
    $("#div_device_contact_list").append(ul);
    
    ul.append($('<li data-role="list-divider">Device Contacts: ' + contacts.length + '</li>'));
    $.each(contacts, function(i, contact) {
           var formattedName = contact.name.formatted;
           if (formattedName) {
           var newLi = $("<li><a href='#'>" + (i+1) + " - " + formattedName + "</a></li>");
           ul.append(newLi);
           }
           });
    
    $("#div_device_contact_list").trigger( "create" );
    

}

function onErrorDevice(error) {
    cordova.require("salesforce/util/logger").logToConsole("onErrorDevice: " + JSON.stringify(error) );
    alert('Error getting device contacts!');
}

function onSuccessSfdcContacts(response) {
    cordova.require("salesforce/util/logger").logToConsole("onSuccessSfdcContacts: received " + response.totalSize + " contacts");
    
    var entries = new Array();
    
    $("#div_sfdc_contact_list").html("")
    var ul = $('<ul data-role="listview" data-inset="true" data-theme="a" data-dividertheme="a"></ul>');
    $("#div_sfdc_contact_list").append(ul);
    
    ul.append($('<li data-role="list-divider">Salesforce Contacts: ' + response.totalSize + '</li>'));
    $.each(response.records, function(i, contact) {
            entries.push(contact);
           var newLi = $("<li><a href='#'>" + (i+1) + " - " + contact.Name + "</a></li>");
           ul.append(newLi);
           });
    
    $("#div_sfdc_contact_list").trigger( "create" );
    
    if (entries.length > 0) {
        cordova.require("salesforce/plugin/smartstore").upsertSoupEntries("myPeopleSoup",entries,onSuccessUpsert,onErrorUpsert);
    }
    
}

function onSuccessSfdcAccounts(response) {
    cordova.require("salesforce/util/logger").logToConsole("onSuccessSfdcAccounts: received " + response.totalSize + " accounts");
    
    $("#div_sfdc_account_list").html("")
    var ul = $('<ul data-role="listview" data-inset="true" data-theme="a" data-dividertheme="a"></ul>');
    $("#div_sfdc_account_list").append(ul);
    
    ul.append($('<li data-role="list-divider">Salesforce Accounts: ' + response.totalSize + '</li>'));
    $.each(response.records, function(i, record) {
           var newLi = $("<li><a href='#'>" + (i+1) + " - " + record.Name + "</a></li>");
           ul.append(newLi);
           });
    
    $("#div_sfdc_account_list").trigger( "create" )
}

function onErrorSfdc(error) {
    cordova.require("salesforce/util/logger").logToConsole("onErrorSfdc: " + JSON.stringify(error));
    alert('Error getting sfdc contacts!');
}