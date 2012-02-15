//Sample code for SmartStore

// This file assumes that all of the javascript and css files required
// as well as the required DOM objects are specified in the index.html file.

var SAMPLE_SOUP_NAME = "myPeopleSoup";
var lastSoupCursor = null;


function regLinkClickHandlers() {
    SFHybridApp.logToConsole("regLinkClickHandlers");


    
    $('#link_fetch_sfdc_contacts').click(function() {
                                         SFHybridApp.logToConsole("link_fetch_sfdc_contacts clicked");
                                         forcetkClient.query("SELECT Name,Id FROM Contact", onSuccessSfdcContacts, onErrorSfdc); 
                                         });
    

    
    $('#link_reset').click(function() {
                           SFHybridApp.logToConsole("link_reset clicked");
                           $("#div_device_contact_list").html("");
                           $("#div_sfdc_contact_list").html("");
                           $("#div_sfdc_account_list").html("");
                           $("#div_sfdc_soup_entry_list").html("");
                           $("#console").html("");
    });
                  
         
    $('#link_logout').click(function() {
             SFHybridApp.logToConsole("link_logout clicked");
             SalesforceOAuthPlugin.logout();
             });
    
    $('#link_reg_soup').click(function() {
      SFHybridApp.logToConsole("link_reg_soup clicked");
      
    if (!PhoneGap.hasResource("smartstore")) {
        SFHybridApp.logToConsole("no SmartStore plugin loaded ???");
    }

      var indexes = [
                     {path:"Name",type:"string"},
                     {path:"Id",type:"string"}
                     ];
        
      navigator.smartstore.registerSoup(SAMPLE_SOUP_NAME,
                                        indexes,                                  
                                        onSuccessRegSoup, 
                                        onErrorRegSoup
        );
      
    });
                              
                              
    
    $('#link_stuff_soup').click(function() {
        SFHybridApp.logToConsole("link_stuff_soup clicked");
        runStuffSoup();
    });
                            
    

    $('#link_remove_soup').click(function() {
        navigator.smartstore.removeSoup(SAMPLE_SOUP_NAME,
                                     onSuccessRemoveSoup, 
                                     onErrorRemoveSoup);
    });
    
    
    $('#link_soup_exists').click(function() {
                                 navigator.smartstore.soupExists(SAMPLE_SOUP_NAME,
                                                                 onSoupExistsDone,
                                                                 onSoupExistsDone);
                                 });
    
    
    $('#link_query_soup').click(function() {
        runQuerySoup();
    });

    $('#link_retrieve_entries').click(function() {
                                runRetrieveEntries();
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


function addEntriesToTestSoup(entries,cb) {
    
    navigator.smartstore.upsertSoupEntries(SAMPLE_SOUP_NAME,entries,
                                           function(items) {
                                               SFHybridApp.logToConsole("added entries: " + items.length);
                                               $("#div_soup_status_line").html("Soup upsert OK");

                                               if (typeof cb !== "undefined") {
                                                cb(items);
                                               }
                                           },
                                           function(err) {
                                               SFHybridApp.logToConsole("onErrorUpsert: " + err);
                                               $("#div_soup_status_line").html("Soup upsert ERROR");
                                               if (typeof cb !== "undefined") {
                                                cb(null);
                                               }                                           
                                           }
                                           );
}


function addGeneratedEntriesToTestSoup(nEntries, cb) {
	SFHybridApp.logToConsole("addGeneratedEntriesToTestSoup " + nEntries);
    
	var entries = [];
	for (var i = 0; i < nEntries; i++) {
		var myEntry = { Name: "Todd Stellanova" + i, Id: "00300" + i,  attributes:{type:"Contact"} };
		entries.push(myEntry);
	}
	
	addEntriesToTestSoup(entries,cb);
	
}

function runStuffSoup() {
    var inputStr = $('#input_stuff_soup_count').val();
    if (inputStr.length === 0) {
        inputStr = null;
    }
    var inputVal = 1;
    if (inputStr !== null) {
        inputVal = parseInt(inputStr);
    }
    
    addGeneratedEntriesToTestSoup(inputVal);
    
}

function runQuerySoup() {
	
	var indexPath = $('#input_indexPath').val();
    if (indexPath.length === 0) {
        indexPath = null;
    }

    var beginKey = $('#input_querySoup_beginKey').val();
    if (beginKey.length === 0) {
        beginKey = null;
    }
    
    var endKey = $('#input_querySoup_endKey').val();
    if (endKey.length === 0) {
        endKey = null;
    }
    
	var queryType =  $('#select_querySoup_type').val();


    var pageSizeStr = $('#input_querySoup_pageSize').val();
    if (pageSizeStr.length === 0) {
        pageSizeStr = null;
    }
    var pageSizeVal = 25;
    if (pageSizeStr !== null) {
        pageSizeVal = parseInt(pageSizeStr);
    }
    
    
    SFHybridApp.logToConsole("querySoup path: '"+ indexPath + "' begin: '" + beginKey + "' end: '" + endKey + "' [" + pageSizeVal + ']');
    var querySpec;
	if ("range" == queryType) {
		querySpec = navigator.smartstore.buildRangeQuerySpec(indexPath,beginKey,endKey,null,pageSizeVal);
	} else if ("like" == queryType) {
		querySpec = navigator.smartstore.buildLikeQuerySpec(indexPath,beginKey,null,pageSizeVal);		
	} else if ("all" == queryType) {
		querySpec = navigator.smartstore.buildAllQuerySpec(indexPath, null, pageSizeVal) ;
	}
	else { //"exact"
		querySpec = navigator.smartstore.buildExactQuerySpec(indexPath,beginKey,null,pageSizeVal);
	}
	
                                
    navigator.smartstore.querySoup(SAMPLE_SOUP_NAME,querySpec,
                                       onSuccessQuerySoup, 
                                       onErrorQuerySoup
                                                );
}

function runRetrieveEntries() {
    var inputStr = $('#input_retrieve_entries').val();
    if (inputStr.length === 0) {
        inputStr = null;
    }
    
    SFHybridApp.logToConsole("runRetrieveEntries: " + inputStr );
    var entryIds = eval(inputStr);
    
    navigator.smartstore.retrieveSoupEntries(SAMPLE_SOUP_NAME,
                                             entryIds,
                                             onSuccessRetrieveEntries,
                                             onErrorRetrieveEntries
                                             );
}
    
function onSuccessRegSoup(param) {
    SFHybridApp.logToConsole("onSuccessRegSoup: " + param);
    $("#div_soup_status_line").html("Soup registered: " + SAMPLE_SOUP_NAME);
}

function onErrorRegSoup(param) {
    SFHybridApp.logToConsole("onErrorRegSoup: " + param);
    $("#div_soup_status_line").html("registerSoup ERROR");
}

                         

function onSuccessUpsert(param) {
    SFHybridApp.logToConsole("onSuccessUpsert: " + param);
    $("#div_soup_status_line").html("Soup upsert OK");
}

function onErrorUpsert(param) {
    SFHybridApp.logToConsole("onErrorUpsert: " + param);
    $("#div_soup_status_line").html("Soup upsert ERROR");
}


    
function onSuccessQuerySoup(cursor) {

    SFHybridApp.logToConsole("onSuccessQuerySoup totalPages: " + cursor.totalPages);
    lastSoupCursor = cursor;

    $("#div_sfdc_soup_entry_list").html("");
    var ul = $('<ul data-role="listview" data-inset="true" data-theme="a" data-dividertheme="a">Page ' + 
               (cursor.currentPageIndex+1) + '/' + cursor.totalPages + 
               ' Entries: ' + cursor.currentPageOrderedEntries.length + 
               ' </ul>');
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


function onSuccessRetrieveEntries(entries ) {
    SFHybridApp.logToConsole("onSuccessRetrieveEntries : " + entries.length);
    
    $("#div_sfdc_soup_entry_list").html("");
    var ul = $('<ul data-role="listview" data-inset="true" data-theme="a" data-dividertheme="a"> ' + 
               ' Entries: ' + entries.length + 
               ' </ul>');
    $("#div_sfdc_soup_entry_list").append(ul);

    $.each(entries, function(i,entry) {
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

function onErrorRetrieveEntries(param) {
    SFHybridApp.logToConsole("onErrorRetrieveEntries: " + param);
}



function onSuccessRemoveSoup(param) {
    SFHybridApp.logToConsole("onSuccessRemoveSoup: " + param);
    $("#div_soup_status_line").html("Soup removed: " + SAMPLE_SOUP_NAME);
}
function onErrorRemoveSoup(param) {
    SFHybridApp.logToConsole("onErrorRemoveSoup: " + param);
    $("#div_soup_status_line").html("removeSoup ERROR");
}



function onSoupExistsDone(param) {
    SFHybridApp.logToConsole("onSoupExistsDone: " + param);
    $("#div_soup_status_line").html("Soup exists: " + param);
}





function onSuccessSfdcContacts(response) {
    SFHybridApp.logToConsole("onSuccessSfdcContacts: received " + response.totalSize + " contacts");
    
	var entries = [];
    
    $("#div_sfdc_contact_list").html("");
    var ul = $('<ul data-role="listview" data-inset="true" data-theme="a" data-dividertheme="a"></ul>');
    $("#div_sfdc_contact_list").append(ul);
    
    ul.append($('<li data-role="list-divider">Salesforce Contacts: ' + response.totalSize + '</li>'));
    $.each(response.records, function(i, contact) {
           entries.push(contact);
           SFHybridApp.logToConsole("name: " + contact.Name);
           var newLi = $("<li><a href='#'>" + (i+1) + " - " + contact.Name + "</a></li>");
           ul.append(newLi);
           });
    
    if (entries.length > 0) {
        navigator.smartstore.upsertSoupEntries(SAMPLE_SOUP_NAME,
                                               entries,
                                               
                                               function(items) {
                                                   var statusTxt = "upserted: " + items.length + " contacts";
                                                   SFHybridApp.logToConsole(statusTxt);
                                                   $("#div_soup_status_line").html(statusTxt);
                                                    $("#div_sfdc_contact_list").trigger( "create" );
                                               },
                                               
                                               onErrorUpsert);
    }
    
    

    
}


function onErrorSfdc(error) {
    SFHybridApp.logToConsole("onErrorSfdc: " + JSON.stringify(error));
    alert('Error getting sfdc contacts!');
}