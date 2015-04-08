/*
 Copyright (c) 2014, salesforce.com, inc. All rights reserved.
 
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

@interface SFSmartSyncSoslReturningBuilder : NSObject

/** Returns the object name for this builder
 */
@property (nonatomic, strong, readonly) NSString *objectName;

/** @name */
/** A builder to help create a returning statement.
 *
 * @param name the object to return.
 * @return the builder
 */
+ (SFSmartSyncSoslReturningBuilder *) withObjectName:(NSString *) name;

/** A builder to help create a returning statement.
 *
 * @param fields a list of one or more fields to return for a given object, comma separated
 * @return the builder
 */
- (SFSmartSyncSoslReturningBuilder *) fields:(NSString *) fields;

/** A builder to help create a returning statement.
 *
 * @param whereClause a description of how search results for the given object should be filtered, based on individual field values. If unspecified, the search retrieves all the rows in the object that are visible to the user
 * @return the builder
 */
- (SFSmartSyncSoslReturningBuilder *) whereClause:(NSString *) whereClause;

/** A builder to help create a returning statement.
 *
 * @param networkId The network id to scope this returning statement with, if necessary
 * @return the builder
 */
- (SFSmartSyncSoslReturningBuilder *) withNetwork:(NSString *) networkId;

/** A builder to help create a returning statement.
 *
 * @param orderBy a description of how to order the returned result, including ascending and descending order, and how nulls are ordered
 * @return the builder
 */
- (SFSmartSyncSoslReturningBuilder *) orderBy:(NSString *) orderBy;

/** A builder to help create a returning statement.
 *
 * @param limit the maximum number of records returned for the given object. If unspecified, all matching records are returned, up to the limit set for the query as a whole
 * @return the builder
 */
- (SFSmartSyncSoslReturningBuilder *) limit:(NSInteger) limit;

/** @name Query String Generation */
/** Builds a returning statement from the builder.
 *
 * @return the built returning statement
 */
- (NSString *) build;

@end