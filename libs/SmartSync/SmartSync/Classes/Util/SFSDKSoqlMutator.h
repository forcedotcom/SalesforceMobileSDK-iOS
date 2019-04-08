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

#import <Foundation/Foundation.h>

#import <SalesforceSDKCore/SFSDKSoqlBuilder.h>

NS_ASSUME_NONNULL_BEGIN

@interface SFSDKSoqlMutator : NSObject

/**
 * Initialize this SOQLMutator with the soql query to manipulate
 * @param soql Original soql query.
 */
+ (SFSDKSoqlMutator *) withSoql:(NSString *) soql;

/**
 * Replace selecg fields
 * @param commaSeparatedFields Comma separated fields to use in top level query's select.
 */
- (SFSDKSoqlMutator*) replaceSelectFields:(NSString*) commaSeparatedFields;

/**
 * Add fields to select
 * @param commaSeparatedFields Comma separated fields to add to top level query's select.
 */
-(SFSDKSoqlMutator*) addSelectFields:(NSString*) commaSeparatedFields;

/**
 * Add predicates to where clause
 * @param commaSeparatedPredicates Comma separated predicates to add to top level query's where.
 */
-(SFSDKSoqlMutator*) addWherePredicates:(NSString*) commaSeparatedPredicates;

/**
 * Replace order by clause (or add one if none)
 * @param commaSeparatedFields Comma separated fields to add to top level query's select.
 */
-(SFSDKSoqlMutator*) replaceOrderBy:(NSString*) commaSeparatedFields;

/**
 * Check if query is ordering by given fields
 * @param commaSeparatedFields Comma separated fields to look for.
 * @return YES if it is the case.
 */
- (BOOL) isOrderingBy:(NSString*) commaSeparatedFields;

/**
 * Check if query has order by clause
 * @return YES if it is the case.
 */
- (BOOL) hasOrderBy;

/**
 * Check if query is selecting by given field
 * @param field Field to look for.
 * @return YES if it is the case.
 */
- (BOOL) isSelectingField:(NSString*) field;

/**
 * @return a SOQL builder with mutations applied
 */
- (SFSDKSoqlBuilder*) asBuilder;

@end

NS_ASSUME_NONNULL_END
