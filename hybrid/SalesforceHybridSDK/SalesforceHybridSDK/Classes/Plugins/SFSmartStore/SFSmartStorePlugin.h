/*
 Copyright (c) 2012, salesforce.com, inc. All rights reserved.
 Author: Todd Stellanova
 
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


#import "CDVPlugin.h"
@class CDVInvokedUrlCommand;

/**
 String used with Cordova to uniquely identify this plugin
 */
extern NSString * const kSmartStorePluginIdentifier;

@class SFStoreCursor;
@class SFSmartStore;

@interface SFSmartStorePlugin : CDVPlugin {
    //the native store used by this plugin
    SFSmartStore *_store;
    
    //cache of cursors by cursorID
    NSMutableDictionary *_cursorCache;
}


@property (nonatomic, strong) SFSmartStore *store;
@property (nonatomic, strong) NSMutableDictionary *cursorCache; 


/**
 Used for unit testing purposes only: allows the shared smart store instance to be reset.
 */
- (void)resetSharedStore;

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




#pragma mark - Object bridging helpers

/**
 * Gets a handle to a cursor, from its ID.
 * @param cursorId The unique ID of the cursor.
 * @return The cached SFStoreCursor isntance with the given ID, or nil.
 */
- (SFStoreCursor*)cursorByCursorId:(NSString*)cursorId;

@end
