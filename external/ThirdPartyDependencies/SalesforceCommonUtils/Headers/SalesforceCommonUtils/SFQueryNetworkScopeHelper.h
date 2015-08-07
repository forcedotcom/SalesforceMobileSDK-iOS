//
//  SFQueryNetworkScopeHelper.h
//  SalesforceCommonUtils
//
//  Created by Jean Bovet on 3/2/14.
//  Copyright (c) 2014 Salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>

/** This class encapsulate the logic that deals
 with scoping queries with network (aka community).
 */
@interface SFQueryNetworkScopeHelper : NSObject

/** Configure the network fields mapping. This mapping
 comes from the server and consists of <objectType> ==> <networkFieldName>.
 where networkFieldName is the field of the objectType that
 is used to scope it with a particular network ID.
 
 @param networkFields The mapping of network fields
 */
+ (void)configureNetworkFields:(NSDictionary*)networkFields;

/** Use this method to set a globally-available networkId that
 will be used in all query builders (and will override any
 locally defined networkId for any of these builders).
 */
+ (void)setNetworkIdOverride:(NSString*)networkId;

/** Returns the globally-available networkId override
 */
+ (NSString*)networkIdOverride;

/** Returns YES if the SOSL query can be scoped for the specified
 object type: that means the SOSL query will use the "with network = '<networkId>'"
 clause in the query.
 
 @param objectType The object type
 @return YES if SOSL can be scoped by network
 */
+ (BOOL)canScopeSoslWithNetworkForObjectType:(NSString*)objectType;

/** Returns YES if the SOSL query can be scoped for the
 specified array of SFSoslReturningBuilder object.

 @param returning An array of SFSoslReturningBuilder objects
 @return YES if SOSL can be scoped by network
 */
+ (BOOL)canScopeSoslWithNetworkForReturning:(NSArray*)returning;

/** Returns the SOSL scoping clause for the given networkId and array of SFSoslReturningBuilder objects
 @param returning An array of SFSoslReturningBuilder objects
 @param networkId The network id. Note that it can be override by the `networkIdOverride` global value
 @return the SOSL scoping clause
 */
+ (NSString*)soslNetworkClauseForReturning:(NSArray*)returning networkId:(NSString*)networkId;

/** Returns a where clause scoped by the specified networkId.
 @param where The existing where clause (or nil if none exist)
 @param networkId The network ID (or nil if no network). Note that it can be override by the `networkIdOverride` global value
 @param objectType The objectType
 @param inSosl YES if the where clause is embedded in a SOSL query, NO if not. This parameter
 determines if the where clause contains the network scoping because some objects can be
 scoped directly at the SOSL level which means the where clause don't need to be scoped.
 @return A scoped where clause
 */
+ (NSString*)scopedWhere:(NSString*)where networkId:(NSString*)networkId objectType:(NSString*)objectType inSosl:(BOOL)inSosl;

@end
