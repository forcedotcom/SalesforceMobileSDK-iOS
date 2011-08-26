//
//  SFRestRequest.h
//  SalesforceSDK
//
//  Created by Didier Prophete on 7/25/11.
//  Copyright 2011 Salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * HTTP methods for requests
 */
typedef enum SFRestMethod {
    SFRestMethodGET = 0,
    SFRestMethodPOST,
    SFRestMethodPUT,
    SFRestMethodDELETE,
    SFRestMethodHEAD,
    SFRestMethodPATCH,
} SFRestMethod;

/**
 * Request object used to send a REST request to Salesforce.com
 * @see SFRestAPI
 */
@interface SFRestRequest : NSObject {
    SFRestMethod _method;
    NSString *_path;
    NSDictionary *_queryParams;
}


/**
 * The HTTP method of the request
 * @see SFRestMethod
 */
@property (nonatomic, assign) SFRestMethod method;

/**
 * The path of the request.
 * For instance, "" (empty string), "v22.0/recent", "v22.0/query".
 * Note that the path doesn't have to start with a '/'. For instance, passing "v22.0/recent" is the same as passing "/v22.0/recent".
 * @warning Do not pass URL encoded query parameters in the path. Use the `queryParams` property instead.
 */
@property (nonatomic, retain) NSString *path;

/**
 * The query parameters of the request (could be nil).
 * Note that URL encoding of the parameters will automatically happen when the request is sent.
 */
@property (nonatomic, retain) NSDictionary *queryParams;

///---------------------------------------------------------------------------------------
/// @name Initialization
///---------------------------------------------------------------------------------------

/**
 * Creates an `SFRestRequest` object.
 * @param method the HTTP method
 * @param path the request path
 * @param queryParams the parameters of the request (could be nil)
 * @see SFRestMethod
 */
+ (id)requestWithMethod:(SFRestMethod)method path:(NSString *)path queryParams:(NSDictionary *)queryParams;

@end
