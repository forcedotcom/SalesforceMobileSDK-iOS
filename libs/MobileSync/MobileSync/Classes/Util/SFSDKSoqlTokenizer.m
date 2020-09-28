/*
 Copyright (c) 2019-present, salesforce.com, inc. All rights reserved.
 
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

#import "SFSDKSoqlTokenizer.h"

@interface SFSDKSoqlTokenizer ()
@property (nonatomic, strong) NSString* soql;

// Used during tokenization
@property (nonatomic, strong) NSMutableArray<NSString*>* tokens;
@property (nonatomic) BOOL inWhiteSpace;
@property (nonatomic) BOOL inQuotes;
@property (nonatomic) NSUInteger depth;
@property (nonatomic) unichar lastCh;
@property (nonatomic, strong) NSMutableString* currentToken;

@end

@implementation SFSDKSoqlTokenizer

- (instancetype) init:(NSString*)soql {
    self = [super init];
    
    if (self) {
        self.soql = soql;
        self.tokens = [NSMutableArray new];
        self.lastCh = 0;
        self.currentToken = [NSMutableString new];
    }
    return self;
}

- (void) pushToken {
    [self.tokens addObject:_currentToken];
    self.currentToken = [NSMutableString new];
}

- (void) beginWhiteSpace {
    if (self.depth == 0) {
        [self pushToken];
    }
    self.inWhiteSpace = YES;
    [self.currentToken appendString:@" "];
}

- (void) beginWord:(unichar)ch {
    if (self.depth == 0) {
        [self pushToken];
    }
    self.inWhiteSpace = NO;
    [self.currentToken appendFormat:@"%C", ch];
}

- (void) beginParenthesized {
    if (self.depth == 0) {
        [self pushToken];
    }
    self.inWhiteSpace = NO;
    self.depth++;
    [self.currentToken appendString:@"("];
}

- (void) endParenthesized {
    [self.currentToken appendString:@")"];
    self.depth--;
    if (self.depth == 0) {
        [self pushToken];
    }
}

- (void) beginQuoted {
    if (self.depth == 0) {
        [self pushToken];
    }
    self.inQuotes = YES;
    self.inWhiteSpace = NO;
    [self.currentToken appendString:@"'"];
}

- (void) endQuoted {
    [self.currentToken appendString:@"'"];
    if (self.depth == 0) {
        [self pushToken];
    }
    self.inQuotes = NO;
}

// Combining order by, group by into single token
- (NSArray<NSString*>*) processTokens {
    NSMutableArray<NSString*>* processedTokens = [NSMutableArray new];
    for (NSUInteger i=0; i<self.tokens.count; i++) {
        NSString* token = self.tokens[i];
        if (i+2 < self.tokens.count) {
            NSString* nextToken = self.tokens[i+1];
            NSString* afterNextToken = self.tokens[i+2];
            if ([nextToken stringByReplacingOccurrencesOfString:@" " withString:@""].length == 0 && [afterNextToken caseInsensitiveCompare:@"by"] == NSOrderedSame
                && ([token caseInsensitiveCompare:@"order"] == NSOrderedSame || [token caseInsensitiveCompare:@"group"] == NSOrderedSame)) {
                [processedTokens addObject:[NSString stringWithFormat:@"%@ %@", token, afterNextToken]];
                i += 2;
                continue;
            }
        }
        [processedTokens addObject:token];
    }
    
    return processedTokens;
}

- (NSArray<NSString*>*) tokenize {
    for (NSInteger i=0; i<self.soql.length; i++) {
        unichar ch = [self.soql characterAtIndex:i];
        switch (ch) {
            case '\'':
                if (!self.inQuotes) { // starting '' expression
                    [self beginQuoted];
                }
                else if (self.lastCh != '\\') { // ending '' expression
                    [self endQuoted];
                }
                else { // within '' expression but escaped
                    [self.currentToken appendFormat:@"%C", ch];
                }
                break;
                
            case '(':
                if (!self.inQuotes) { // starting () expressions
                    [self beginParenthesized];
                }
                else { // within '' expression
                    [self.currentToken appendFormat:@"%C", ch];
                }
                break;
                
            case ')':
                if (!self.inQuotes) { // starting () expressions
                    [self endParenthesized];
                }
                else { // within '' expression
                    [self.currentToken appendFormat:@"%C", ch];
                }
                break;
                
            case ' ':
                if (!self.inWhiteSpace && !self.inQuotes && self.depth == 0) { // starting top level white space
                    [self  beginWhiteSpace];
                }
                else {
                    [self.currentToken appendFormat:@"%C", ch];
                }
                break;
                
            default:
                if (self.inWhiteSpace) {
                    [self beginWord:ch];
                }
                else {
                    [self.currentToken appendFormat:@"%C", ch];
                }
        }
        self.lastCh = ch;
    }
    // Don't forget last token
    if (self.currentToken.length > 0) {
        [self.tokens addObject:self.currentToken];
    }
    
    // Process tokens
    return [self processTokens];
}

@end
