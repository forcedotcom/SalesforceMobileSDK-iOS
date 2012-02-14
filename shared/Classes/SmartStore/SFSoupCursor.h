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


@class SFSmartStore;
@class SFSoupQuerySpec;

@interface SFSoupCursor : NSObject {
    SFSmartStore *_store;
    NSString *_soupName;
    NSString *_cursorId;
    SFSoupQuerySpec *_querySpec;
    
    NSArray *_currentPageOrderedEntries;
    NSNumber *_currentPageIndex;
    NSNumber *_pageSize;
    NSNumber *_totalPages;
    
}

/** soup name from which this cursor was generated */
@property (nonatomic, readonly, strong) NSString *soupName;

/** a unique ID for this cursor */
@property (nonatomic, readonly, strong) NSString *cursorId;

/** the query spec that generated this cursor */
@property (nonatomic, readonly, strong) SFSoupQuerySpec *querySpec;

/** the list of current page entries, ordered as requested in the querySpec */
@property (nonatomic, readonly, strong) NSArray *currentPageOrderedEntries;


/** the maximum number of entries returned per page */
@property (nonatomic, readonly, strong) NSNumber *pageSize;
/** 
 The total number of pages of results available 
 */
@property (nonatomic, readonly, strong) NSNumber *totalPages;

/** 
 The current page index among totalPages available:
 writing this value causes currentPageOrderedEntries to be refetched
 */
@property (nonatomic, readwrite, strong) NSNumber *currentPageIndex;


/**
 @param entries a sorted list of entries
 */
- (id)initWithSoupName:(NSString*)soupName store:(SFSmartStore*)store querySpec:(SFSoupQuerySpec*)querySpec totalEntries:(NSUInteger)totalEntries;

/**
 @return dictionary representation of this object, for translation to json
 */
- (NSDictionary*)asDictionary;


/**
 Close this cursor when finished operating on it...
 */
- (void)close; 

@end
