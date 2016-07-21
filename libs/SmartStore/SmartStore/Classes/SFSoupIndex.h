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

extern NSString * const kSoupIndexPath;
extern NSString * const kSoupIndexType;
extern NSString * const kSoupIndexTypeString;
extern NSString * const kSoupIndexTypeInteger;
extern NSString * const kSoupIndexTypeFloating;
extern NSString * const kSoupIndexTypeFullText;
extern NSString * const kSoupIndexTypeJSON1;


/**
 * Index types filter
 */
@class SFSoupIndex;
typedef BOOL (^SFIndexSpecTypeFilterBlock)(SFSoupIndex*);
extern SFIndexSpecTypeFilterBlock const kValueExtractedToColumn;
extern SFIndexSpecTypeFilterBlock const kValueExtractedToFtsColumn;
extern SFIndexSpecTypeFilterBlock const kValueIndexedWithJSONExtract;

/**
 * Definition of an index on a given soup.
 */
@interface SFSoupIndex : NSObject {
    NSString *_path;
    NSString *_indexType;
    NSString *_columnName;
}

/**
 * The simple or compound path to the index value, e.g. "Id" or "Account.Id".
 */
@property (nonatomic, strong) NSString *path;

/**
 * The type of index this is (string or date).
 */
@property (nonatomic, strong) NSString *indexType;

/**
 * The type of data that will be indexed (string or integer).
 */
@property (strong, nonatomic, readonly) NSString *columnType;

/**
 * The name of the column that will store the index.
 */
@property (strong, nonatomic, readonly) NSString *columnName;

/**
 * Designated initializer.
 *
 * @param path The simple or compound path to the index value, e.g. "Id" or "Account.Id".
 * @param type An index type, e.g. kSoupIndexTypeString.
 * @param columnName The SQL column name, or nil.
 */
- (id)initWithPath:(NSString*)path indexType:(NSString*)type columnName:(NSString*)columnName;

/**
 * Creates an SFSoupIndex based on the given NSDictionary index spec.
 * @param dict the dictionary to use
 * @return Initialized SFSoupIndex object.
 */
- (id)initWithDictionary:(NSDictionary*)dict;
    
/**
  * Return dictionary for this SFSoupIndex object without column name
  */
- (NSDictionary*)asDictionary;

/**
  * Returns a dictionary For this SFSoupIndex object with or without column name
  * @param withColumnName If YES, column name is included in returned dictionary
  */
- (NSDictionary*)asDictionary:(BOOL)withColumnName;

/**
  * Returns an array of NSDictionary objects for a given array of soup indexes, using the given column name as the index.
  * @param arrayOfSoupIndexes Array of soup indexes 
  * @param withColumnName If YES, column name is included in returned dictionary
  * @return Array of NSDictionary objects
  */
+ (NSArray*) asArrayOfDictionaries:(NSArray*) arrayOfSoupIndexes withColumnName:(BOOL)withColumnName;

/**
 * Returns an array of SFSoupIndex objects for a given array of soup indexes.
 * @param arrayOfDictionaries Array of dictionaries
 * @return Array of SFSoupIndex objects
 */
+ (NSArray*) asArraySoupIndexes:(NSArray*) arrayOfDictionaries;

/** Returns a map path to SFSoupIndex
 * @param soupIndexes array of SFSoupIndex objects
 * @return Dictionary that maps paths to soup indexes
 */
+ (NSDictionary*) mapForSoupIndexes:(NSArray*)soupIndexes;

/** Returns YES if any of the indexes are full text
 * @param soupIndexes array of SFSoupIndex objects
 * @return YES if any of the indexes are full text
 */
+ (BOOL) hasFts:(NSArray*)soupIndexes;

/** Returns YES if any of the indexes are JSON1
 * @param soupIndexes array of SFSoupIndex objects
 * @return YES if any of the indexes are JSON1
 */
+ (BOOL) hasJSON1:(NSArray*)soupIndexes;

/** Using the path and indexType property values, constructs a string in the format "path--indexType".
 @return String containing the path and indext type, separated by "--".
 */
- (NSString*) getPathType;

@end


