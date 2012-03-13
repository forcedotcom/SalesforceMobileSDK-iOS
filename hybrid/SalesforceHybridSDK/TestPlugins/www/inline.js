//Sample code for Hybrid REST Explorer

var lastSoupCursor = null;

function regLinkClickHandlers() {
    SFHybridApp.logToConsole("regLinkClickHandlers");

    
    $('#link_fetch_device_contacts').click(function() {
                                           var options = new ContactFindOptions();
                                           var fields = ["name"];
                                           SFHybridApp.logToConsole("link_fetch_device_contacts clicked");
                                           options.filter = ""; // empty search string returns all contacts
                                           options.multiple = true;
                                           navigator.contacts.find(fields, onSuccessDevice, onErrorDevice, options);
                                           });
    
    $('#link_fetch_sfdc_contacts').click(function() {
                                         SFHybridApp.logToConsole("link_fetch_sfdc_contacts clicked");
                                         forcetkClient.query("SELECT Name,Id FROM Contact", onSuccessSfdcContacts, onErrorSfdc); 
                                         });
    
    $('#link_fetch_sfdc_accounts').click(function() {
         SFHybridApp.logToConsole("link_fetch_sfdc_accounts clicked");
         forcetkClient.query("SELECT Name FROM Account", onSuccessSfdcAccounts, onErrorSfdc); 
     });
    
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
         
    $('#link_logout').click(function() {
             SFHybridApp.logToConsole("link_logout clicked");
             SalesforceOAuthPlugin.logout();
             });
    
    $('#link_reg_soup').click(function() {
      SFHybridApp.logToConsole("link_reg_soup clicked");
      
    if (!PhoneGap.hasResource("smartstore")) {
        SFHybridApp.logToConsole("no resource smartstore ???");
    }

      var indexes = [
                     {path:"Name",type:"string"},
                     {path:"Id",type:"string"}
                     ];
        
      navigator.smartstore.registerSoup("myPeopleSoup",
                                        indexes,                                  
                                        onSuccessRegSoup, 
                                        onErrorRegSoup
        );
      
    });
    
                              
                              
    
    $('#link_stuff_soup').click(function() {
        SFHybridApp.logToConsole("link_stuff_soup clicked");

        var myEntry1 = { Name: "Todd Stellanova", Id: "00300A",  attributes:{type:"Contact"} };
        var myEntry2 = { Name: "Pro Bono Bonobo",  Id: "00300B", attributes:{type:"Contact"}  };
        var myEntry3 = { Name: "Robot", Id: "00300C", attributes:{type:"Contact"}  };

        var entries = [myEntry1,myEntry2,myEntry3];
        navigator.smartstore.upsertSoupEntries("myPeopleSoup",entries,onSuccessUpsert,onErrorUpsert);
        
    });
                            
    


    $('#link_remove_soup').click(function() {
        navigator.smartstore.removeSoup("myPeopleSoup",
                                     onSuccessRemoveSoup, 
                                     onErrorRemoveSoup);
    });
    

    

    $('#link_query_soup').click(function() {
        runQuerySoup();
    });

    
     $('#link_cursor_page_zero').click(function() {
        SFHybridApp.logToConsole("link_cursor_page_zero clicked");
        navigator.smartstore.moveCursorToPageIndex(lastSoupCursor,0, onSuccessQuerySoup,onErrorQuerySoup);
    });
     
     $('#link_cursor_page_prev').click(function() {
        SFHybridApp.logToConsole("link_cursor_page_prev clicked");
        navigator.smartstore.moveCursorToPreviousPage(lastSoupCursor,onSuccessQuerySoup,onErrorQuerySoup);
    });
     
    
    $('#link_cursor_page_next').click(function() {
        SFHybridApp.logToConsole("link_cursor_page_next clicked");
        navigator.smartstore.moveCursorToNextPage(lastSoupCursor,onSuccessQuerySoup,onErrorQuerySoup);
    });
}

/*
Can be used from native side to start the tests
*/
function kickStartTests() {
    navigator.testrunner.setTestSuite('SmartStoreTestSuite');
    navigator.testrunner.testSuite.startTests();
}



function runQuerySoup() {
    var inputStr = $('#input_query_soup').val();
    if (inputStr.length === 0) {
        inputStr = null;
    }
    
    SFHybridApp.logToConsole("testSmartStoreQuerySoup: " + inputStr);

    var querySpec = new SoupQuerySpec("Name",inputStr);
    querySpec.pageSize = 25;
                                
    navigator.smartstore.querySoup("myPeopleSoup",querySpec,
                                       onSuccessQuerySoup, 
                                       onErrorQuerySoup
                                                );
}
    
function onSuccessRegSoup(param) {
    SFHybridApp.logToConsole("onSuccessRegSoup: " + param);
}

function onErrorRegSoup(param) {
    SFHybridApp.logToConsole("onErrorRegSoup: " + param);
}

function onSuccessUpsert(param) {
    SFHybridApp.logToConsole("onSuccessUpsert: " + param);
}


function onErrorUpsert(param) {
    SFHybridApp.logToConsole("onErrorUpsert: " + param);
}


    
function onSuccessQuerySoup(cursor) {

    SFHybridApp.logToConsole("onSuccessQuerySoup totalPages: " + cursor.totalPages);
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
    SFHybridApp.logToConsole("onErrorQuerySoup: " + param);
}


function onSuccessRemoveSoup(param) {
    SFHybridApp.logToConsole("onSuccessRemoveSoup: " + param);
}
function onErrorRemoveSoup(param) {
    SFHybridApp.logToConsole("onErrorRemoveSoup: " + param);
}



function onSuccessDevice(contacts) {
    SFHybridApp.logToConsole("onSuccessDevice: received " + contacts.length + " contacts");
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
    SFHybridApp.logToConsole("onErrorDevice: " + JSON.stringify(error) );
    alert('Error getting device contacts!');
}

function onSuccessSfdcContacts(response) {
    SFHybridApp.logToConsole("onSuccessSfdcContacts: received " + response.totalSize + " contacts");
    
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
        navigator.smartstore.upsertSoupEntries("myPeopleSoup",entries,onSuccessUpsert,onErrorUpsert);
    }
    
}

function onSuccessSfdcAccounts(response) {
    SFHybridApp.logToConsole("onSuccessSfdcAccounts: received " + response.totalSize + " accounts");
    
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
    SFHybridApp.logToConsole("onErrorSfdc: " + JSON.stringify(error));
    alert('Error getting sfdc contacts!');
}