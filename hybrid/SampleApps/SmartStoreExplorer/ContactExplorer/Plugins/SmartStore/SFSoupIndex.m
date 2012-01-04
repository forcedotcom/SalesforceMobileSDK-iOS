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

#import "SFSoupIndex.h"


NSString * const kSoupIndexTypeString = @"string";
NSString * const kSoupIndexTypeDate = @"date";

static NSString * const kSoupIndexNamePrefix = @"ix_";
static NSString * const kSoupIndexColumnNamePrefix = @"idx_";
static NSString * const kCreatedSoupIndexColumnNamePrefix = @"(idx_";

static NSString * const kIndexCreationPrefix = @"CREATE INDEX ";

@implementation SFSoupIndex

@synthesize keyPath = _keyPath;
@synthesize indexType = _indexType;
@synthesize indexedColumnName = _indexedColumnName;
@synthesize indexName = _indexName;


+ (NSString*)soupIndexNameForKeyPath:(NSString*)path
{
    //TODO ensure that safeKeypath works for compound paths eg parentAccount.owner.name
    NSString *safeKeypath = path; 
    NSString *result = [NSString stringWithFormat:@"%@%@",kSoupIndexNamePrefix,safeKeypath];
    return result;
}

+ (NSString*)indexColumnNameForKeyPath:(NSString*)path
{
    //TODO ensure that safeKeypath works for compound paths eg parentAccount.owner.name
    NSString *safeKeypath = path; 
    NSString *result = [NSString stringWithFormat:@"%@%@",kSoupIndexColumnNamePrefix,safeKeypath];
    return result;
}

- (id)initWithIndexSpec:(NSDictionary*)indexSpec
{
    self = [super init];
    
    if (nil != self) {
        self.keyPath = [indexSpec objectForKey:@"path"];
        
        //TODO check that indexType is valid type?
        self.indexType = [indexSpec objectForKey:@"type"];

        self.indexedColumnName = [[self class] indexColumnNameForKeyPath:self.keyPath];
        self.indexName = [[self class] soupIndexNameForKeyPath:self.keyPath];
    }
    return self;
}

- (id)initWithSql:(NSString *)sql
{
    //eg:
    //CREATE INDEX ix_name on _soupMaster (idx_name)
    
    self = [super init];

    NSString *meatStr = [sql substringFromIndex:[kIndexCreationPrefix length]];
    NSArray *sqlTokens = [meatStr componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSLog(@"tokens: %@",sqlTokens);
    
    for(NSString *tok in sqlTokens) {
        if ([tok hasPrefix:kSoupIndexNamePrefix]) {
            self.indexName = tok;
        }
        else  if ([tok hasPrefix:kCreatedSoupIndexColumnNamePrefix]) {
            NSString *sub = [tok substringWithRange:NSMakeRange(1,[tok length] - 2)];
            self.indexedColumnName = sub;
        }
    }
    
    //TODO glean the index type from the main table's column definition itself?
    self.indexType = kSoupIndexTypeString;
    
    //figure out the keyPath
    NSString *rawKeyPath = [self.indexName substringFromIndex:[kSoupIndexNamePrefix length]];
    self.keyPath = rawKeyPath; //TODO decode flattened path
    
    return self;

}

- (NSString*)createSqlWithTableName:(NSString*)tableName
{
    //eg 
    //CREATE INDEX ix_name on _soupMaster (idx_name)

    NSString *createSql = [NSString stringWithFormat:@"%@ %@ on %@ (%@)",kIndexCreationPrefix,
                       self.indexName,tableName,self.indexedColumnName];
    
    return createSql;
}
@end
