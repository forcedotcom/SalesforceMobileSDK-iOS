/*
 Copyright (c) 2014-present, salesforce.com, inc. All rights reserved.
 
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

#import "SFSDKSoqlMutator.h"
#import "SFSDKSoqlTokenizer.h"

static NSString * const kSFSDKSoqlMutatorSelect = @"select";
static NSString * const kSFSDKSoqlMutatorFrom = @"from";
static NSString * const kSFSDKSoqlMutatorWhere = @"where";
static NSString * const kSFSDKSoqlMutatorHaving = @"having";
static NSString * const kSFSDKSoqlMutatorOrderBy = @"order by";
static NSString * const kSFSDKSoqlMutatorGroupBy = @"group by";
static NSString * const kSFSDKSoqlMutatorLimit = @"limit";
static NSString * const kSFSDKSoqlMutatorOffset = @"offset";

@interface SFSDKSoqlMutator ()


@property (nonatomic, strong) NSString* originalSoql;
@property (nonatomic, strong) NSMutableDictionary<NSString*, NSString*>* clauses;
@property (nonatomic, strong) NSMutableDictionary<NSString*, NSString*>* clausesWithoutSubqueries;

@end

@implementation SFSDKSoqlMutator

+ (SFSDKSoqlMutator *) withSoql:(NSString *) soql {
    return [[SFSDKSoqlMutator alloc] init:soql];
}

- (instancetype) init:(NSString*)soql {
    self = [super init];
    
    if (self) {
        self.originalSoql = soql;
        self.clauses = [NSMutableDictionary new];
        self.clausesWithoutSubqueries = [NSMutableDictionary new];
        [self parseQuery];
    }
    return self;
}

- (void) parseQuery {
    NSArray* clauseTypeKeywords = @[kSFSDKSoqlMutatorSelect, kSFSDKSoqlMutatorFrom,
                                    kSFSDKSoqlMutatorWhere, kSFSDKSoqlMutatorHaving,
                                    kSFSDKSoqlMutatorOrderBy, kSFSDKSoqlMutatorGroupBy,
                                    kSFSDKSoqlMutatorLimit, kSFSDKSoqlMutatorOffset];
    
    NSString* matchingClauseType;
    NSString* currentClauseType;    // one of the clause types of interest
    SFSDKSoqlTokenizer* tokenizer = [[SFSDKSoqlTokenizer alloc] init:self.originalSoql];
    
    for(NSString* token in [tokenizer tokenize]) {
        for (NSString* clauseType in clauseTypeKeywords) {
            if ([token caseInsensitiveCompare:clauseType] == NSOrderedSame) {
                matchingClauseType = clauseType;
                break;
            }
        }
        
        if (matchingClauseType) {
            // We just matched one of the clauseTypeKeywords in the top level query
            currentClauseType = matchingClauseType;
            self.clauses[currentClauseType] = @"";
            self.clausesWithoutSubqueries[currentClauseType] = @"";
            matchingClauseType = nil;
        } else {
            // We are inside a clause
            if (currentClauseType) {
                self.clauses[currentClauseType] = [self.clauses[currentClauseType] stringByAppendingString:token];
                // We are inside a clause and not in a subquery
                if (![token hasPrefix:@"("]) {
                    self.clausesWithoutSubqueries[currentClauseType] = [self.clausesWithoutSubqueries[currentClauseType] stringByAppendingString:token];
                }
            }
        }
    }
}

- (SFSDKSoqlMutator*) replaceSelectFields:(NSString*) commaSeparatedFields {
    self.clauses[kSFSDKSoqlMutatorSelect] = commaSeparatedFields;
    return self;
}

- (SFSDKSoqlMutator*) addSelectFields:(NSString*) commaSeparatedFields {
    self.clauses[kSFSDKSoqlMutatorSelect] = [NSString stringWithFormat:@"%@,%@", commaSeparatedFields, [self trimmedClause:kSFSDKSoqlMutatorSelect]];
    return self;
}

- (SFSDKSoqlMutator*) addWherePredicates:(NSString*) commaSeparatedPredicates {
    if (self.clauses[kSFSDKSoqlMutatorWhere]) {
        self.clauses[kSFSDKSoqlMutatorWhere] = [NSString stringWithFormat:@"%@ and %@", commaSeparatedPredicates, [self trimmedClause:kSFSDKSoqlMutatorWhere]];
    } else {
        self.clauses[kSFSDKSoqlMutatorWhere] = commaSeparatedPredicates;
    }
    return self;
}

- (SFSDKSoqlMutator*) replaceOrderBy:(NSString*) commaSeparatedFields {
    self.clauses[kSFSDKSoqlMutatorOrderBy] = commaSeparatedFields;
    return self;
}

- (BOOL) isOrderingBy:(NSString*) commaSeparatedFields {
    return self.clauses[kSFSDKSoqlMutatorOrderBy] && [self equalsIgnoringWhiteSpaces:self.clauses[kSFSDKSoqlMutatorOrderBy] s2:commaSeparatedFields];
}

- (BOOL) hasOrderBy {
    return self.clauses[kSFSDKSoqlMutatorOrderBy] != nil;
}

- (BOOL) isSelectingField:(NSString*) field {
    NSArray* selectedFields = [[self removeWhiteSpaces:self.clausesWithoutSubqueries[kSFSDKSoqlMutatorSelect]] componentsSeparatedByString:@","];
    return [selectedFields containsObject:field];
}

- (SFSDKSoqlBuilder*) asBuilder {
    SFSDKSoqlBuilder* builder = [[[[[[SFSDKSoqlBuilder withFields:[self trimmedClause:kSFSDKSoqlMutatorSelect]]
                                     from:[self trimmedClause:kSFSDKSoqlMutatorFrom]]
                                    whereClause:[self trimmedClause:kSFSDKSoqlMutatorWhere]]
                                   having:[self trimmedClause:kSFSDKSoqlMutatorHaving]]
                                  groupBy:[self trimmedClause:kSFSDKSoqlMutatorGroupBy]]
                                 orderBy:[self trimmedClause:kSFSDKSoqlMutatorOrderBy]];
    
    NSNumber* limit = [self clauseAsInteger:kSFSDKSoqlMutatorLimit];
    if (limit) {
        [builder limit:[limit integerValue]];
    }
    NSNumber* offset = [self clauseAsInteger:kSFSDKSoqlMutatorOffset];
    if (offset) {
        [builder offset:[offset integerValue]];
    }
    return builder;
}

# pragma mark - Helper methods

- (NSNumber*) clauseAsInteger:(NSString*)clauseType {
    return [NSNumber numberWithInt:[[self trimmedClause:clauseType] intValue]];
}
    
- (NSString*) trimmedClause:(NSString*)clauseType {
    return self.clauses[clauseType]
        ? [self.clauses[clauseType] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
        : @"";
}

- (BOOL) equalsIgnoringWhiteSpaces:(NSString*)s1 s2:(NSString*)s2 {
    return [[self removeWhiteSpaces:s1] isEqualToString:[self removeWhiteSpaces:s2]];
}

- (NSString*) removeWhiteSpaces:(NSString*) s {
    return [s stringByReplacingOccurrencesOfString:@" " withString:@""];
}

@end
