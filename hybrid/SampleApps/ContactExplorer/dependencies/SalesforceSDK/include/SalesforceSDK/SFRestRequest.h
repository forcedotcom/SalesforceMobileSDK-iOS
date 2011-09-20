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

@protocol SFRestDelegate;

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
    id<SFRestDelegate> _delegate;
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


/**
 * The delegate for this request. Notified of request status.
 */
@property (nonatomic, assign) id<SFRestDelegate> delegate;


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
