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
#import "SFRestRequest.h"
#import "SFSObjectTree.h"
#import "SFUserAccount.h"
#import "SalesforceSDKConstants.h"

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
 * Default API version (currently "v46.0")
 * You can override this by using setApiVersion:
 */
extern NSString* const kSFRestDefaultAPIVersion NS_SWIFT_NAME(SFRestDefaultAPIVersion);

/*
 * Misc keys appearing in requests
 */
extern NSString* const kSFRestIfUnmodifiedSince NS_SWIFT_NAME(SFRestIfUnmodifiedSince);

/**
 Main class used to issue REST requests to the standard Force.com REST API.
 
 See the [Force.com REST API Developer's Guide](http://www.salesforce.com/us/developer/docs/api_rest/index.htm)
 for more information regarding the Force.com REST API.

 ## Initialization
 
 This class is a singleton, and can be accessed by referencing [SFRestAPI sharedInstance].  It relies
 upon the shared credentials managed by SFAccountManager, for forming up and sending authenticated
 REST requests.
 
 ## Sending requests

 Sending a request is done using `send:delegate:`.
 The class sending the request has to conform to the protocol `SFRestDelegate`.
 
 A request can be obtained in two different ways:

 - by calling the appropriate `requestFor[...]` method

 - by building the `SFRestRequest` manually
 
 Note: If you opt to build an SFRestRequest manually, you should be aware that
 send:delegate: expects that if the request.path does not begin with the
 request.endpoint prefix, it will add the request.endpoint prefix 
 (kSFDefaultRestEndpoint by default) to the request path.
  
 For example, this sample code calls the `requestForDescribeWithObjectType:` method to return
 information about the Account object.

    - (void)describeAccount {
        SFRestRequest *request = [[SFRestAPI sharedInstance]
                                  requestForDescribeWithObjectType:@"Account"];
        [[SFRestAPI sharedInstance] send:request delegate:self];
    }
 
    #pragma mark - SFRestDelegate
 
    - (void)request:(SFRestRequest *)request didLoadResponse:(id)dataResponse rawResponse:(NSURLResponse *)rawResponse {
        NSDictionary *dict = (NSDictionary *)dataResponse;
        NSArray *fields = (NSArray *)[dict objectForKey:@"fields"];
        // ...
    }
 
    - (void)request:(SFRestRequest*)request didFailLoadWithError:(NSError *)error rawResponse:(NSURLResponse *)rawResponse {
        // handle error
    }
 
    - (void)requestDidCancelLoad:(SFRestRequest *)request {
        // handle error
    }

    - (void)requestDidTimeout:(SFRestRequest *)request {
        // handle error
    }
 
 ## Error handling
 
 When sending a `SFRestRequest`, you may encounter one of these errors:

 - The request parameters could be invalid (for instance, passing `nil` to the `requestForQuery:`,
 or trying to update a non-existent object).
 In this case, `request:didFailLoadWithError:` is called on the `SFRestDelegate`.
 The error passed will have an error domain of `kSFRestErrorDomain`
 
 - The oauth access token (session ID) managed by SFAccountManager could have expired.
 In this case, the framework tries to acquire another access token and re-issue
 the `SFRestRequest`. This is all done transparently and the appropriate delegate method
 is called once the second `SFRestRequest` returns. 

 - Requesting a new access token (session ID) could fail (if the access token has expired
 and the OAuth refresh token is invalid).
 In this case, `request:didFailLoadWithError:` will be called on the `SFRestDelegate`.
 The error passed will have an error domain of `kSFOAuthErrorDomain`.
 Note that this is a very rare case.

 - The underlying HTTP request could fail (Salesforce server is innaccessible...)
 In this case, `request:didFailLoadWithError:` is called on the `SFRestDelegate`.
 The error passed will be a standard `RestKit` error with an error domain of `RKRestKitErrorDomain`. 

 */
NS_SWIFT_NAME(RestClient)
@interface SFRestAPI : NSObject

/**
 * The REST API version used for all the calls.
 * The default value is `kSFRestDefaultAPIVersion` (currently "v46.0")
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
 * @param request `SFRestRequest` object to be sent.
 * @param delegate Delegate object that handles the server response. 
 * This value overwrites the delegate property of the request.
 */
- (void)send:(SFRestRequest *)request delegate:(nullable id<SFRestDelegate>)delegate;

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
 * @see Rest API link: https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_discoveryresource.htm
 */
- (SFRestRequest *)requestForResources SFSDK_DEPRECATED(7.3, 8.0, "Use requestForResources:apiVersion instead");

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
 * @see https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_describeGlobal.htm
 */
- (SFRestRequest *)requestForDescribeGlobal SFSDK_DEPRECATED(7.3, 8.0, "Use requestForDescribeGlobal:apiVersion instead");

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
 * @see https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_sobject_basic_info.htm
 */
- (SFRestRequest *)requestForMetadataWithObjectType:(NSString *)objectType SFSDK_DEPRECATED(7.3, 8.0, "Use requestForMetadataWithObjectType:objectType:apiVersion instead");

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
 * @see https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_sobject_describe.htm
 */
- (SFRestRequest *)requestForDescribeWithObjectType:(NSString *)objectType SFSDK_DEPRECATED(7.3, 8.0, "Use requestForDescribeWithObjectType:objectType:apiVersion instead");

/**
 * Returns an `SFRestRequest` object that completely describes the metadata
 * at all levels for the specified object.
 * @param objectType Type of a Salesforce object. Example: "Account".
 * @param apiVersion API version.
 * @see https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_sobject_describe.htm
 */
- (SFRestRequest *)requestForDescribeWithObjectType:(NSString *)objectType apiVersion:(nullable NSString *)apiVersion;

/**
 * Returns an `SFRestRequest` object that provides layout data for the specified object and layout type.
 *
 * @param objectType Type of a Salesforce object. Example: "Account".
 * @param layoutType Layout type. Supported types are "Full" and "Compact". Default is "Full".
 * @see https://developer.salesforce.com/docs/atlas.en-us.uiapi.meta/uiapi/ui_api_resources_record_layout.htm
 */
- (SFRestRequest *)requestForLayoutWithObjectType:(nonnull NSString *)objectType layoutType:(nullable NSString *)layoutType SFSDK_DEPRECATED(7.3, 8.0, "Use requestForLayoutWithObjectType:objectType:layoutType:apiVersion instead");

/**
 * Returns an `SFRestRequest` object that provides layout data for the specified object and layout type.
 *
 * @param objectType Type of a Salesforce object. Example: "Account".
 * @param layoutType Layout type. Supported types are "Full" and "Compact". Default is "Full".
 * @param apiVersion API version.
 * @see https://developer.salesforce.com/docs/atlas.en-us.uiapi.meta/uiapi/ui_api_resources_record_layout.htm
 */
- (SFRestRequest *)requestForLayoutWithObjectType:(nonnull NSString *)objectType layoutType:(nullable NSString *)layoutType apiVersion:(nullable NSString *)apiVersion;

/**
 * Returns an `SFRestRequest` object that retrieves field values for the specified record of the given type.
 * @param objectType Type of a Salesforce object. Example: "Account".
 * @param objectId Requested record's object ID.
 * @param fieldList Comma-separated list of fields for which 
 *               to return values. Example: "Name,Industry,TickerSymbol".
 *               Pass nil to retrieve all the fields.
 * @see https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_sobject_retrieve.htm
 */
- (SFRestRequest *)requestForRetrieveWithObjectType:(NSString *)objectType
                                           objectId:(NSString *)objectId 
                                          fieldList:(nullable NSString *)fieldList SFSDK_DEPRECATED(7.3, 8.0, "Use requestForRetrieveWithObjectType:objectType:objectId:fieldList:apiVersion instead");

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
 * @see https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_sobject_retrieve.htm
 */
- (SFRestRequest *)requestForCreateWithObjectType:(NSString *)objectType 
                                           fields:(nullable NSDictionary<NSString *, id> *)fields SFSDK_DEPRECATED(7.3, 8.0, "Use requestForCreateWithObjectType:objectType:fields:apiVersion instead");

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
 * @see https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_sobject_upsert.htm
 */
- (SFRestRequest *)requestForUpsertWithObjectType:(NSString *)objectType
                                  externalIdField:(NSString *)externalIdField
                                       externalId:(nullable NSString *)externalId
                                           fields:(NSDictionary<NSString *, id> *)fields SFSDK_DEPRECATED(7.3, 8.0, "Use requestForUpsertWithObjectType:objectType:externalIdField:externalId:fields:apiVersion instead");

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
 * @see https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_sobject_retrieve.htm
 */
- (SFRestRequest *)requestForUpdateWithObjectType:(NSString *)objectType 
                                         objectId:(NSString *)objectId
                                           fields:(nullable NSDictionary<NSString *, id> *)fields SFSDK_DEPRECATED(7.3, 8.0, "Use requestForUpdateWithObjectType:objectType:objectId:fields:apiVersion instead");

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
 * @see https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_sobject_retrieve.htm
 */
- (SFRestRequest *)requestForUpdateWithObjectType:(NSString *)objectType
                                         objectId:(NSString *)objectId
                                            fields:(nullable NSDictionary<NSString*, id> *)fields
                            ifUnmodifiedSinceDate:(nullable NSDate *)ifUnmodifiedSinceDate SFSDK_DEPRECATED(7.3, 8.0, "Use requestForUpdateWithObjectType:objectType:objectId:fields:ifUnmodifiedSinceDate:apiVersion instead");

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
 * @see https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_sobject_retrieve.htm
 */
- (SFRestRequest *)requestForDeleteWithObjectType:(NSString *)objectType 
                                         objectId:(NSString *)objectId SFSDK_DEPRECATED(7.3, 8.0, "Use requestForDeleteWithObjectType:objectType:objectId:apiVersion instead");

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
 * @see https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_query.htm
 */
- (SFRestRequest *)requestForQuery:(NSString *)soql SFSDK_DEPRECATED(7.3, 8.0, "Use requestForQuery:soql:apiVersion instead");

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
 * The result includes deleted objects.
 * @param soql String containing the query to execute. Example: "SELECT Id,
 *             Name from Account ORDER BY Name LIMIT 20".
 * @see https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_queryall.htm
 */
- (SFRestRequest *)requestForQueryAll:(NSString *)soql SFSDK_DEPRECATED(7.3, 8.0, "Use requestForQueryAll:soql:apiVersion instead");

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
 * @see https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_search.htm
 */
- (SFRestRequest *)requestForSearch:(NSString *)sosl SFSDK_DEPRECATED(7.3, 8.0, "Use requestForSearch:sosl:apiVersion instead");

/**
 * Returns an `SFRestRequest` object that executes the specified SOSL search.
 * @param sosl String containing the search to execute. Example: "FIND {needle}".
 * @param apiVersion API version.
 * @see https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_search.htm
 */
- (SFRestRequest *)requestForSearch:(NSString *)sosl apiVersion:(nullable NSString *)apiVersion;

/**
 * Returns an `SFRestRequest` object that returns an ordered list of objects in the default global search scope of a logged-in user.
 * @see https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_search_scope_order.htm
 */
- (SFRestRequest *)requestForSearchScopeAndOrder SFSDK_DEPRECATED(7.3, 8.0, "Use requestForSearchScopeAndOrder:apiVersion instead");

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
 * @see https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_search_layouts.htm
 */
- (SFRestRequest *)requestForSearchResultLayout:(NSString *)objectList SFSDK_DEPRECATED(7.3, 8.0, "Use requestForSearchResultLayout:objectList:apiVersion instead");

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
 * @see https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_composite_batch.htm
 */
- (SFRestRequest *) batchRequest:(NSArray<SFRestRequest *> *)requests haltOnError:(BOOL)haltOnError SFSDK_DEPRECATED(7.3, 8.0, "Use batchRequest:requests:apiVersion instead");

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
 * @see https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_composite_composite.htm
 */
- (SFRestRequest *) compositeRequest:(NSArray<SFRestRequest *> *)requests refIds:(NSArray<NSString *> *)refIds allOrNone:(BOOL)allOrNone SFSDK_DEPRECATED(7.3, 8.0, "Use compositeRequest:requests:refIds:allOrNone:apiVersion instead");

/**
 * Returns an `SFRestRequest` object that executes a composite request.
 * @param requests Array of subrequests to execute.
 * @param refIds Array of reference IDs for the requests. The number of elements should match the number of requests.
 * @param allOrNone Specifies whether to return partial results when an error occurs while processing a subrequest.
 * @param apiVersion API version.
 * @see https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_composite_composite.htm
 */
- (SFRestRequest *) compositeRequest:(NSArray<SFRestRequest *> *) requests refIds:(NSArray<NSString *> *)refIds allOrNone:(BOOL)allOrNone apiVersion:(nullable NSString *)apiVersion;

/**
 * Returns an `SFRestRequest` object that executes an sObject tree request.
 * @param objectType Type of a Salesforce object. Example: "Account".
 * @param objectTrees Array of sobject trees.
 * @see https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_composite_sobject_tree.htm
 */
- (SFRestRequest*) requestForSObjectTree:(NSString *)objectType objectTrees:(NSArray<SFSObjectTree *> *)objectTrees SFSDK_DEPRECATED(7.3, 8.0, "Use requestForSObjectTree:objectType:objectTrees:apiVersion instead");

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
