/*
 Copyright (c) 2011, salesforce.com, inc. All rights reserved.
 
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

@class SFSoupCursor;


@interface SFSoup : NSObject {
    NSString *_name;
    NSString *_soupPath;
    NSString *_indexTablePath;
    NSMutableDictionary *_cursorCache;
}

@property (nonatomic, readonly) NSString *name;

/**
 Create a fresh soup with the given specs and persist it
 */
- (id)initWithName:(NSString *)name indexes:(NSArray*)indexSpecs atPath:(NSString*)path;

/**
 Load an existing soup from the given path
 */
- (id)initWithName:(NSString*)name fromPath:(NSString*)path;



/**
 
 @param querySpec 
 
 @return a cursor to the query results
 */
- (SFSoupCursor*)query:(NSDictionary*)querySpec;

/**
 @param entries array of soup entries to be updated or inserted
 */
- (SFSoupCursor*)upsertEntries:(NSArray*)entries;

- (void)removeEntries:(NSArray*)entryIds;

@end
