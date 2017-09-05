/*
 Copyright (c) 2012-present, salesforce.com, inc. All rights reserved.
 
 Redistribution and use of this software in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright notice, this list of conditions
 and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of
 conditions and the following disclaimer in the documentation and/or other materials provided
 with the distribution.
 * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
 endorse or promote products derived from this software without specific prior written
 permission of salesforce.com, inc.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
 FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
 WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <Foundation/Foundation.h>
#import "SFForcePlugin.h"
#import <SmartStore/SFStoreCursor.h>

/**
 String used with Cordova to uniquely identify this plugin
 */
extern NSString * const kSmartStorePluginIdentifier;

@interface SFSmartStorePlugin : SFForcePlugin

/**
 Used for unit testing purposes only: resets the cursor caches.
 */
- (void)resetCursorCaches;

#pragma mark - Cordova Plugin methods called from js

/**
 * Does the given soup exist in the store?  See see [SFSmartStore soupExists:].
 * @param command Cordova arguments object containing "soupName".
 *
 */
- (void)pgSoupExists:(CDVInvokedUrlCommand *)command;

/**
 * Registers a new soup in the store.  See [SFSmartStore registerSoup:withIndexSpecs:].
 * @param command Cordova arguments object containing "soupName" and "indexSpecs".
 *
 */
- (void)pgRegisterSoup:(CDVInvokedUrlCommand *)command;


/**
 * Removes a soup from the store.  See [SFSmartStore removeSoup:].
 * @param command Cordova arguments object containing "soupName".
 *
 */
- (void)pgRemoveSoup:(CDVInvokedUrlCommand *)command;


/**
 * Queries a soup for data. See [SFSmartStore querySoup:withQuerySpec:].
 * @param command Cordova arguments object containing "soupName" and "querySpec".
 *
 */
- (void)pgQuerySoup:(CDVInvokedUrlCommand *)command;

/**
 * Queries soups using smart sql. See [SFSmartStore querySoup:withQuerySpec:].
 * @param command Cordova arguments object containing "querySpec".
 *
 */
- (void)pgRunSmartQuery:(CDVInvokedUrlCommand *)command;

/**
 * Retrieves a set of soup entries from a soup. See [SFSmartStore retrieveEntries:fromSoup:].
 * @param command Cordova arguments object containing "soupName" and "soupEntryIds".
 *
 */
- (void)pgRetrieveSoupEntries:(CDVInvokedUrlCommand *)command;


/**
 * Inserts/updates a group of entries in a soup. See [SFSmartStore upsertEntries:toSoup:].
 * @param command Cordova arguments object containing "soupName" and "entries".
 *
 */
- (void)pgUpsertSoupEntries:(CDVInvokedUrlCommand *)command;

/**
 * Closes a cursor associated with soup data.
 * @param command Cordova arguments object containing "cursorId".
 */
- (void)pgCloseCursor:(CDVInvokedUrlCommand *)command;


/**
 * Removes a set of soup entries from a soup. See [SFSmartStore removeEntries:fromSoup:].
 * @param command Cordova arguments object containing "soupName" and "soupEntryIds".
 *
 */
- (void)pgRemoveFromSoup:(CDVInvokedUrlCommand *)command;

/**
 * Removes soup entries from a soup. See [SFSmartStore clearSoup:].
 * @param command Cordova arguments object containing "soupName".
 *
 */
- (void)pgClearSoup:(CDVInvokedUrlCommand *)command;

/**
 * Removes soup entries from a soup. See [SFSmartStore getDatabaseSize:].
 * @param command Cordova arguments object.
 *
 */
- (void)pgGetDatabaseSize:(CDVInvokedUrlCommand *)command;

/**
 * Alter soup indexes. See [SFSmartStore alterSoup:withIndexSpecs:withReIndexData].
 * @param command Cordova arguments object containing "soupName" and "indexSpecs" and "reIndexData".
 *
 */
- (void)pgAlterSoup:(CDVInvokedUrlCommand *)command;

/**
 * Re-index soup. See [SFSmartStore reIndexSoup:withIndexPaths:].
 * @param command Cordova arguments object containing "soupName" and "indexPaths" and "reIndexData".
 *
 */
- (void)pgReIndexSoup:(CDVInvokedUrlCommand *)command;

/**
 * Show SmartStore inspector See [SFSmartStore showInspector:].
 * @param command Cordova arguments object.
 *
 */
- (void)pgShowInspector:(CDVInvokedUrlCommand *)command;

/**
 * Get soup index specs. See [SFSmartStore indicesForSoup:].
 * @param command Cordova arguments object containing "soupName".
 *
 */
- (void)pgGetSoupIndexSpecs:(CDVInvokedUrlCommand *)command;

/**
 * Get soup spec details for the given soup name.
 * @param command Cordova arguments object containing "soupName".
 *
 */
- (void)pgGetSoupSpec:(CDVInvokedUrlCommand *)command;

/**
 * Get All Global Store names.
 *
 */
-(void)pgGetAllGlobalStores:(CDVInvokedUrlCommand *)command;

/**
 * Get Get All User specific Store names.
 *
 */
-(void)pgGetAllStores:(CDVInvokedUrlCommand *)command;

/**
 * Remove the Store given a store name.
 * @param command Cordova arguments object containing "storeName" and "isGlobalStore".
 */
-(void)pgRemoveStore:(CDVInvokedUrlCommand *)command;

/**
 * Remove All Global Stores.
 *
 */
-(void)pgRemoveAllGlobalStores:(CDVInvokedUrlCommand *)command;

/**
 * Remove All User Stores.
 *
 */
-(void)pgRemoveAllStores:(CDVInvokedUrlCommand *)command;
    
@end
