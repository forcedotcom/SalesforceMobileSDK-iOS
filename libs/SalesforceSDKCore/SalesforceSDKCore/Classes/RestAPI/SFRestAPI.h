/*
 Copyright (c) 2011-present, salesforce.com, inc. All rights reserved.
 
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
#import <SalesforceSDKCore/SFRestRequest.h>
#import <SalesforceSDKCore/SFSObjectTree.h>
#import <SalesforceSDKCore/SFUserAccount.h>
#import <SalesforceSDKCore/SalesforceSDKConstants.h>

NS_ASSUME_NONNULL_BEGIN

/*
 * Domain used for errors reported by the rest API (non HTTP errors)
 * (for example, passing an invalid SOQL string when doing a query)
 */
extern NSString* const kSFRestErrorDomain NS_SWIFT_NAME(SFRestErrorDomain);
/*
 * Error code used for all rest API errors (non HTTP errors)
 * (for example, passing an invalid SOQL string when doing a query)
 */
extern NSInteger const kSFRestErrorCode NS_SWIFT_NAME(SFRestErrorCode);

/*
 * Default API version (currently "v49.0")
 * You can override this by using setApiVersion:
 */
extern NSString* const kSFRestDefaultAPIVersion NS_SWIFT_NAME(SFRestDefaultAPIVersion);

/*
 * Misc keys appearing in requests
 */
extern NSString* const kSFRestIfUnmodifiedSince NS_SWIFT_NAME(SFRestIfUnmodifiedSince);

/**
 * SOQL batch related constants
 */
extern NSInteger const kSFRestSOQLMinBatchSize NS_SWIFT_NAME(SFRestSOQLMinBatchSize);
extern NSInteger const kSFRestSOQLMaxBatchSize NS_SWIFT_NAME(SFRestSOQLMaxBatchSize);
extern NSInteger const kSFRestSOQLDefaultBatchSize NS_SWIFT_NAME(SFRestSOQLDefaultBatchSize);
extern NSString* const kSFRestQueryOptions NS_SWIFT_NAME(SFRestQueryOptions);

/**
 * Main class used to issue REST requests to the standard Force.com REST API.
 * See the [Force.com REST API Developer's Guide](http://www.salesforce.com/us/developer/docs/api_rest/index.htm)
 * for more information regarding the Force.com REST API.
*/
NS_SWIFT_NAME(RestClient)
@interface SFRestAPI : NSObject

/**
 * The REST API version used for all the calls.
* The default value is `kSFRestDefaultAPIVersion` (currently "v49.0")
 */
@property (nonatomic, strong) NSString *apiVersion;

/**
 * The user associated with this instance of SFRestAPI.
 */
@property (nonatomic, strong, readonly) SFUserAccount *user NS_SWIFT_NAME(userAccount);

/**
 * Returns the singleton instance of `SFRestAPI` associated with the current user.
 */
@property (class, nonatomic, readonly) SFRestAPI *sharedInstance NS_SWIFT_NAME(shared);

/**
 * Returns the singleton instance of `SFRestAPI` that's used to make unauthenticated calls.
 */
@property (class, nonatomic, readonly) SFRestAPI *sharedGlobalInstance NS_SWIFT_NAME(sharedGlobal);

/**
 * Returns the singleton instance of `SFRestAPI` associated with the specified user.
 */
+ (nullable SFRestAPI *)sharedInstanceWithUser:(nonnull SFUserAccount *)userAccount NS_SWIFT_NAME(restClient(for:));

/**
 * Specifies whether the current execution is a test run.
 * @param isTestRun YES if this is a test run.
 */
+ (void)setIsTestRun:(BOOL)isTestRun NS_SWIFT_UNAVAILABLE("");

/**
 * Indicates whether the current execution is a test run.
 * @returns True if this execution is a test run.
 */
+ (BOOL)getIsTestRun NS_SWIFT_UNAVAILABLE("");

/**
 * Perform cleanup due to a host change or logout.
 */
- (void)cleanup;

/** 
 * Cancel all requests that are waiting to be executed.
 */
- (void)cancelAllRequests;

/**
 * Sends a REST request to the Salesforce server and invokes the appropriate delegate method.
 *
 * @param request `SFRestRequest` object to be sent.
 * @param requestDelegate Delegate object that handles the server response.
 */
- (void)send:(SFRestRequest *)request requestDelegate:(nullable id<SFRestRequestDelegate>)requestDelegate;

///---------------------------------------------------------------------------------------
/// @name SFRestRequest factory methods
///---------------------------------------------------------------------------------------

/**
 * Returns an `SFRestRequest` object that contains information associated with the current user.
 * @see https://help.salesforce.com/articleView?id=remoteaccess_using_userinfo_endpoint.htm
 */
- (SFRestRequest *)requestForUserInfo;

/**
 * Returns an `SFRestRequest` object that lists summary information about each
 * Salesforce.com version currently available. Summaries include the version, 
 * label, and a link to each version's root.
 * @see https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_versions.htm
 */
- (SFRestRequest *)requestForVersions;

/**
 * Returns an `SFRestRequest` object that lists available resources for the
 * client's API version, including resource name and URI.
 * @param apiVersion API version.
 * @see Rest API link: https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_discoveryresource.htm
 */
- (SFRestRequest *)requestForResources:(nullable NSString *)apiVersion;

/**
 * Returns an `SFRestRequest` object that lists available objects in your org and their
 * metadata.
 * @param apiVersion API version.
 * @see https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_describeGlobal.htm
 */
- (SFRestRequest *)requestForDescribeGlobal:(nullable NSString *)apiVersion;

/**
 * Returns an `SFRestRequest` object that describes the individual metadata for the
 * specified object.
 * @param objectType Type of a Salesforce object. Example: "Account".
 * @param apiVersion API version.
 * @see https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_sobject_basic_info.htm
 */
- (SFRestRequest *)requestForMetadataWithObjectType:(NSString *)objectType apiVersion:(nullable NSString *)apiVersion;

/**
 * Returns an `SFRestRequest` object that completely describes the metadata
 * at all levels for the specified object.
 * @param objectType Type of a Salesforce object. Example: "Account".
 * @param apiVersion API version.
 * @see https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_sobject_describe.htm
 */
- (SFRestRequest *)requestForDescribeWithObjectType:(NSString *)objectType apiVersion:(nullable NSString *)apiVersion;

/**
 * Returns an `SFRestRequest` object that provides layout data for the specified parameters.
 * @param objectAPIName Object API name.
 * @param formFactor Form factor. Could be "Large", "Medium" or "Small". Default value is "Large".
 * @param layoutType Layout type. Could be "Compact" or "Full". Default value is "Full".
 * @param mode Mode. Could be "Create", "Edit" or "View". Default value is "View".
 * @param recordTypeId Record type ID. Default will be used if not supplied.
 * @param apiVersion API version.
 * @see https://developer.salesforce.com/docs/atlas.en-us.uiapi.meta/uiapi/ui_api_resources_record_layout.htm
 */
- (SFRestRequest *)requestForLayoutWithObjectAPIName:(nonnull NSString *)objectAPIName formFactor:(nullable NSString *)formFactor layoutType:(nullable NSString *)layoutType mode:(nullable NSString *)mode recordTypeId:(nullable NSString *)recordTypeId apiVersion:(nullable NSString *)apiVersion;

/**
 * Returns an `SFRestRequest` object that retrieves field values for the specified record of the given type.
 * @param objectType Type of a Salesforce object. Example: "Account".
 * @param objectId Requested record's object ID.
 * @param fieldList Comma-separated list of fields for which
 *               to return values. Example: "Name,Industry,TickerSymbol".
 *               Pass nil to retrieve all the fields.
 * @param apiVersion API version.
 * @see https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_sobject_retrieve.htm
 */
- (SFRestRequest *)requestForRetrieveWithObjectType:(NSString *)objectType
                                           objectId:(NSString *)objectId
                                          fieldList:(nullable NSString *)fieldList
                                         apiVersion:(nullable NSString *)apiVersion;

/**
 * Returns an `SFRestRequest` object that creates a new record of the given type.
 * @param objectType Type of a Salesforce object. Example: "Account".
 * @param fields `NSDictionary` object containing initial field names and values for
 *               the record. Example: {Name: "salesforce.com", TickerSymbol:
 *               "CRM"}
 * @param apiVersion API version.
 * @see https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_sobject_retrieve.htm
 */
- (SFRestRequest *)requestForCreateWithObjectType:(NSString *)objectType
                                           fields:(nullable NSDictionary<NSString *, id> *)fields
                                       apiVersion:(nullable NSString *)apiVersion;

/**
 * Returns an `SFRestRequest` object that creates or updates record of the given type, based on the
 * given external ID.
 * @param objectType Type of a Salesforce object. Example: "Account".
 * @param externalIdField External ID field name. Example: "accountMaster__c".
 * @param externalId Requested record's external ID value.
 * @param fields `NSDictionary` object containing field names and values for
 *               the record. Example: {Name: "salesforce.com", TickerSymbol
 *               "CRM"}
 * @param apiVersion API version.
 * @see https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_sobject_upsert.htm
 */
- (SFRestRequest *)requestForUpsertWithObjectType:(NSString *)objectType
                                  externalIdField:(NSString *)externalIdField
                                       externalId:(nullable NSString *)externalId
                                           fields:(NSDictionary<NSString *, id> *)fields
                                       apiVersion:(nullable NSString *)apiVersion;

/**
 * Returns an `SFRestRequest` object that updates field values on a record of the given type.
 * @param objectType Type of a Salesforce object. Example: "Account".
 * @param objectId Requested record's object ID.
 * @param fields `NSDictionary` object containing initial field names and values for
 *               the record. Example: {Name: "salesforce.com", TickerSymbol
 *               "CRM"}.
 * @param apiVersion API version.
 * @see https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_sobject_retrieve.htm
 */
- (SFRestRequest *)requestForUpdateWithObjectType:(NSString *)objectType
                                         objectId:(NSString *)objectId
                                           fields:(nullable NSDictionary<NSString *, id> *)fields
                                       apiVersion:(nullable NSString *)apiVersion;

/**
 * Same as requestForUpdateWithObjectType:objectId:fields but only executing update
 * if the server record was not modified since `ifModifiedSinceDate`.
 *
 * @param objectType Type of a Salesforce object. Example: "Account".
 * @param objectId Requested record's object ID.
 * @param fields `NSDictionary` object containing initial field names and values for the specified record.
 * @param ifUnmodifiedSinceDate Update occurs only if the current last modified date of the specified record is
 *                              older than `ifUnmodifiedSinceDate`.
 *                              Otherwise, this method returns a 412 (precondition failed) error.
 * @param apiVersion API version.
 * @see https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_sobject_retrieve.htm
 */
- (SFRestRequest *)requestForUpdateWithObjectType:(NSString *)objectType
                                         objectId:(NSString *)objectId
                                           fields:(nullable NSDictionary<NSString*, id> *)fields
                            ifUnmodifiedSinceDate:(nullable NSDate *) ifUnmodifiedSinceDate
                                       apiVersion:(nullable NSString *)apiVersion;

/**
 * Returns an `SFRestRequest` object that deletes a record of the given type.
 * @param objectType Type of a Salesforce object. Example: "Account".
 * @param objectId Requested record's object ID.
 * @param apiVersion API version.
 * @see https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_sobject_retrieve.htm
 */
- (SFRestRequest *)requestForDeleteWithObjectType:(NSString *)objectType
                                         objectId:(NSString *)objectId
                                       apiVersion:(nullable NSString *)apiVersion;

/**
 * Returns an `SFRestRequest` object that executes the specified SOQL query.
 * @param soql String containing the query to execute. Example: "SELECT Id,
 *             Name from Account ORDER BY Name LIMIT 20".
 * @param apiVersion API version.
 * @see https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_query.htm
 */
- (SFRestRequest *)requestForQuery:(NSString *)soql apiVersion:(nullable NSString *)apiVersion;

/**
 * Returns an `SFRestRequest` object that executes the specified SOQL query.
 * @param soql String containing the query to execute. Example: "SELECT Id,
 *             Name from Account ORDER BY Name LIMIT 20".
 * @param apiVersion API version.
 * @param batchSize Batch size: number between 200 and 2000 (default).
 * @see https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_query.htm
 */
- (SFRestRequest *)requestForQuery:(NSString *)soql apiVersion:(nullable NSString *)apiVersion batchSize:(NSInteger)batchSize;

/**
 * Returns an `SFRestRequest` object that executes the specified SOQL query.
 * The result includes deleted objects.
 * @param soql String containing the query to execute. Example: "SELECT Id,
 *             Name from Account ORDER BY Name LIMIT 20".
 * @param apiVersion API version.
 * @see https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_queryall.htm
 */
- (SFRestRequest *)requestForQueryAll:(NSString *)soql apiVersion:(nullable NSString *)apiVersion;

/**
 * Returns an `SFRestRequest` object that executes the specified SOSL search.
 * @param sosl String containing the search to execute. Example: "FIND {needle}".
 * @param apiVersion API version.
 * @see https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_search.htm
 */
- (SFRestRequest *)requestForSearch:(NSString *)sosl apiVersion:(nullable NSString *)apiVersion;

/**
 * Returns an `SFRestRequest` object that returns an ordered list of objects in the default global search scope of a logged-in user.
 * @param apiVersion API version.
 * @see https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_search_scope_order.htm
 */
- (SFRestRequest *)requestForSearchScopeAndOrder:(nullable NSString *)apiVersion;

/**
 * Returns an `SFRestRequest` object that contains search result layout information for the objects in the query string.
 * @param objectList Comma-separated list of objects for which
 *               to return values. Example: "Account,Contact".
 * @param apiVersion API version.
 * @see https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_search_layouts.htm
 */
- (SFRestRequest *)requestForSearchResultLayout:(NSString *)objectList apiVersion:(nullable NSString *)apiVersion;

/**
 * Returns an `SFRestRequest` object that executes a batch of requests.
 * @param requests Array of subrequests to execute.
 * @param haltOnError Controls whether Salesforce stops processing subrequests if a subrequest fails.
 * @param apiVersion API version.
 * @see https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_composite_batch.htm
 */
- (SFRestRequest *) batchRequest:(NSArray<SFRestRequest *> *)requests haltOnError:(BOOL)haltOnError apiVersion:(nullable NSString *)apiVersion;

/**
 * Returns an `SFRestRequest` object that executes a composite request.
 * @param requests Array of subrequests to execute.
 * @param refIds Array of reference IDs for the requests. The number of elements should match the number of requests.
 * @param allOrNone Specifies whether to return partial results when an error occurs while processing a subrequest.
 * @param apiVersion API version.
 * @see https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_composite_composite.htm
 */
- (SFRestRequest *)compositeRequest:(NSArray<SFRestRequest *> *) requests refIds:(NSArray<NSString *> *)refIds allOrNone:(BOOL)allOrNone apiVersion:(nullable NSString *)apiVersion;

/**
 * Returns an `SFRestRequest` object that executes an sObject tree request.
 * @param objectType Type of a Salesforce object. Example: "Account".
 * @param objectTrees Array of sobject trees.
 * @param apiVersion API version.
 * @see https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_composite_sobject_tree.htm
 */
- (SFRestRequest*) requestForSObjectTree:(NSString *)objectType objectTrees:(NSArray<SFSObjectTree *> *)objectTrees apiVersion:(nullable NSString *)apiVersion;

///---------------------------------------------------------------------------------------
/// @name Other utility methods
///---------------------------------------------------------------------------------------

+ (BOOL)isStatusCodeSuccess:(NSUInteger)statusCode;

+ (BOOL)isStatusCodeNotFound:(NSUInteger)statusCode;

/**
 * Provides the User-Agent string used by Mobile SDK.
 */
+ (NSString *)userAgentString;

/**
 * Returns the User-Agent string used by Mobile SDK, adding the qualifier after the app type.
 @param qualifier Optional subtype of native or hybrid Mobile SDK app.
 */
+ (NSString *)userAgentString:(NSString *)qualifier;

@end

NS_ASSUME_NONNULL_END
