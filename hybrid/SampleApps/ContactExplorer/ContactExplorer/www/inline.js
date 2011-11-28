//Sample code for Hybrid REST Explorer

function regLinkClickHandlers() {
    $('#link_fetch_device_contacts').click(function() {
                                           logToConsole("link_fetch_device_contacts clicked");
                                           var options = new ContactFindOptions();
                                           options.filter = ""; // empty search string returns all contacts
                                           options.multiple = true;
                                           var fields = ["name"];
                                           navigator.contacts.find(fields, onSuccessDevice, onErrorDevice, options);
                                           });
    
    $('#link_fetch_sfdc_contacts').click(function() {
                                         logToConsole("link_fetch_sfdc_contacts clicked");
                                         forcetkClient.query("SELECT Name FROM Contact", onSuccessSfdcContacts, onErrorSfdc); 
                                         });
    
    $('#link_fetch_sfdc_accounts').click(function() {
                                         logToConsole("link_fetch_sfdc_accounts clicked");
                                         forcetkClient.query("SELECT Name FROM Account", onSuccessSfdcAccounts, onErrorSfdc); 
                                         });
    
    $('#link_reset').click(function() {
                           logToConsole("link_reset clicked");
                           $("#div_device_contact_list").html("")
                           $("#div_sfdc_contact_list").html("")
                           $("#div_sfdc_account_list").html("")
                           $("#console").html("")
                           });
                           
    $('#link_logout').click(function() {
             logToConsole("link_logout clicked");
             SalesforceOAuthPlugin.logout();
             });
}

function onSuccessDevice(contacts) {
    logToConsole("onSuccessDevice: received " + contacts.length + " contacts");
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
    
    $("#div_device_contact_list").trigger( "create" )
}

function onErrorDevice(error) {
    logToConsole("onErrorDevice: " + JSON.stringify(error) );
    alert('Error getting device contacts!');
}

function onSuccessSfdcContacts(response) {
    logToConsole("onSuccessSfdcContacts: received " + response.totalSize + " contacts");
    
    $("#div_sfdc_contact_list").html("")
    var ul = $('<ul data-role="listview" data-inset="true" data-theme="a" data-dividertheme="a"></ul>');
    $("#div_sfdc_contact_list").append(ul);
    
    ul.append($('<li data-role="list-divider">Salesforce Contacts: ' + response.totalSize + '</li>'));
    $.each(response.records, function(i, contact) {
           var newLi = $("<li><a href='#'>" + (i+1) + " - " + contact.Name + "</a></li>");
           ul.append(newLi);
           });
    
    $("#div_sfdc_contact_list").trigger( "create" )
}

function onSuccessSfdcAccounts(response) {
    logToConsole("onSuccessSfdcAccounts: received " + response.totalSize + " accounts");
    
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
    logToConsole("onErrorSfdc: " + JSON.stringify(error));
    alert('Error getting sfdc contacts!');
}