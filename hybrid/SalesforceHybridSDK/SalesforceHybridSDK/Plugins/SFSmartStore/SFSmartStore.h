/*
 Copyright (c) 2011, salesforce.com, inc. All rights reserved.
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

// From PhoneGap.framework
#import "PGPlugin.h"

@class SFContainerAppDelegate;
@class SFSoupCursor;
@class SFSoup;

@interface SFSmartStore : PGPlugin {

    SFContainerAppDelegate *_appDelegate;

    NSString    *_callbackID;  
    
    //cache of soups by name
    NSMutableDictionary *_soupCache;
    
    //cache of cursors by cursorID
    NSMutableDictionary *_cursorCache;
    
}

@property (nonatomic, copy) NSString* callbackID;


+ (NSString *)soupDirectoryFromSoupName:(NSString *)soupName;

#pragma mark - Native Soup manipulation methods


/**
 @return Does a soup with the given name already exist?
 */
- (BOOL)soupExists:(NSString*)soupName;


/**
 Ensure that a soup with the given name exists.
 Either creates a new soup or returns an existing soup.
 
 @param soupName The name of the soup to register
 @param indexSpecs Array of one ore more IndexSpec objects as dictionaries
 @return A new or existing soup with the given name
 */
- (SFSoup*)registerSoup:(NSString*)soupName withIndexSpecs:(NSArray*)indexSpecs;


/*
 Search soup for entries matching the querySpec

 @param soupName The name of the soup to query
 @param querySpec A QuerySpec as a dictionary

 @return A set of entries
 */
- (SFSoupCursor*)querySoup:(NSString*)soupName withQuerySpec:(NSDictionary *)querySpec;

/*
 Search soup for entries exactly matching the soup entry IDs
 
 @param soupName The name of the soup to query
 @param soupEntryIds An array of opaque soup entry IDs
 
 @return An array with zero or more entries matching the input IDs. Order is not guaranteed.
 */
- (NSArray*)retrieveEntries:(NSArray*)soupEntryIds fromSoup:(NSString*)soupName;


/*
 Search soup for entries matching the querySpec
 
 @param soupName The name of the soup to query
 @param entries A set of soup entry dictionaries
 
 @return A set of entries
 */
- (NSArray*)upsertEntries:(NSArray*)entries toSoup:(NSString*)soupName;


/**
 Remove soup completely from the store.
 */
- (void)removeSoup:(NSString*)soupName;


#pragma mark - Object bridging helpers

/**
 @param cursorId  The unique ID of the cursor
 @return SFSoupCursor the cached cursor with the given ID or nil
 */
- (SFSoupCursor*)cursorByCursorId:(NSString*)cursorId;

/**
 @param cursorId  The unique ID of the cursor
 */
- (void)closeCursorWithId:(NSString*)cursorId;


#pragma mark - PhoneGap Plugin methods called from js

/**
 @param arguments Standard phonegap arguments array, containing:
 1: successCB - this is the javascript function that will be called on success
 2: errorCB - optional javascript function to be called in the event of an error 
 
 @param options:  dictionary containing "soupName"   
 
 @see soupExists
 */
- (void)pgSoupExists:(NSArray*)arguments withDict:(NSDictionary*)options;

/**
 @param arguments Standard phonegap arguments array, containing:
 1: successCB - this is the javascript function that will be called on success
 2: errorCB - optional javascript function to be called in the event of an error 
 
 @param options:  dictionary containing "soupName" and "indexSpecs"  
 
 @see registerSoup
 */
- (void)pgRegisterSoup:(NSArray*)arguments withDict:(NSDictionary*)options;


/**
 @param arguments Standard phonegap arguments array, containing:
 1: successCB - this is the javascript function that will be called on success
 2: errorCB - optional javascript function to be called in the event of an error 
 
 @param options:  dictionary containing "soupName" 
 
 @see removeSoup
 */
- (void)pgRemoveSoup:(NSArray*)arguments withDict:(NSDictionary*)options;


/**
 @param arguments Standard phonegap arguments array, containing:
 1: successCB - this is the javascript function that will be called on success
 2: errorCB - optional javascript function to be called in the event of an error with an error code.
 
 @param options:  dictionary containing "soupName" and "querySpec"  
 
 @see querySoup
 */
- (void)pgQuerySoup:(NSArray*)arguments withDict:(NSDictionary*)options;


/**
 @param arguments Standard phonegap arguments array, containing:
 1: successCB - this is the javascript function that will be called on success
 2: errorCB - optional javascript function to be called in the event of an error with an error code.
 
 @param options:  dictionary containing "soupName" and "soupEntryIds"  
 
 @see retrieveSoupEntries:fromSoup:

 */
- (void)pgRetrieveSoupEntries:(NSArray*)arguments withDict:(NSDictionary*)options;


/**   
 @param arguments Standard phonegap arguments array, containing:
 1: successCB - this is the javascript function that will be called on success
 2: errorCB - optional javascript function to be called in the event of an error with an error code.
 
 @param options:  dictionary containing "soupName" and "entries"  
 
 @see upsertSoupEntries
 */
- (void)pgUpsertSoupEntries:(NSArray*)arguments withDict:(NSDictionary*)options;

/**   
 @param arguments Standard phonegap arguments array, containing:
 1: successCB - this is the javascript function that will be called on success
 
 @param options:  dictionary containing "cursorId"
 
 @see closeCursorWithId:
 */
- (void)pgCloseCursor:(NSArray*)arguments withDict:(NSDictionary*)options;


/**   
 @param arguments Standard phonegap arguments array, containing:
 1: successCB - this is the javascript function that will be called on success
 2: errorCB - optional javascript function to be called in the event of an error with an error code.
 
 @param options:  dictionary containing "soupName" and "soupEntryIds"  
 
 @see removeFromSoup
 */
- (void)pgRemoveFromSoup:(NSArray*)arguments withDict:(NSDictionary*)options;


@end
