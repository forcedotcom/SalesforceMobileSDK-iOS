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

// From PhoneGap.framework
#import "PGPlugin.h"


/**
 String used with PhoneGap to uniquely identify this plugin
 */
extern NSString * const kSmartStorePluginIdentifier;

@class SFContainerAppDelegate;
@class SFSoupCursor;
@class SFSmartStore;

@interface SFSmartStorePlugin : PGPlugin {
    //a convenient ref to the shared app delegate
    SFContainerAppDelegate *_appDelegate;

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
+ (void)resetSharedStore;

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




#pragma mark - Object bridging helpers

/**
 @param cursorId  The unique ID of the cursor
 @return SFSoupCursor the cached cursor with the given ID or nil
 */
- (SFSoupCursor*)cursorByCursorId:(NSString*)cursorId;



@end
