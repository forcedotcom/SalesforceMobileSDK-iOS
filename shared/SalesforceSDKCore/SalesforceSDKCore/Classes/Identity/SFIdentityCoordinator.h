/*
 Copyright (c) 2012, salesforce.com, inc. All rights reserved.
 
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

@class SFIdentityCoordinator;
@class SFOAuthCredentials;
@class SFIdentityData;

/**
 * The default timeout period, in seconds, for the identity request.
 */
extern const NSTimeInterval kSFIdentityRequestDefaultTimeoutSeconds;

/**
 * The error domain associated with any errors returned by this object.
 */
extern NSString * const kSFIdentityErrorDomain;

/**
 * @enum Enumeration of error codes associated with any errors in the identity retrieval process.
 */
enum {
    kSFIdentityErrorUnknown = 766,
    kSFIdentityErrorNoData,
    kSFIdentityErrorDataMalformed,
    kSFIdentityErrorBadHttpResponse
};

/**
 * Protocol for being a delegate to the SFIdentityCoordinator process.  Delegates may receive
 * notifications about the success or failure of the identity request process.
 * @see SFIdentityCoordinator
 */
@protocol SFIdentityCoordinatorDelegate <NSObject>

@required

/**
 * Called when the identity coordinator successfully receives identity data from the service.
 * @param coordinator the SFIdentityCoordinator instance associated with the requested data.
 */
- (void)identityCoordinatorRetrievedData:(SFIdentityCoordinator *)coordinator;

/**
 * Called if there was an error while retrieving the identity data from the service.
 * @param coordinator The SFIdentityCoordinator instance associated with the request.
 * @param error The error that occurred during the request.
 */
- (void)identityCoordinator:(SFIdentityCoordinator *)coordinator didFailWithError:(NSError *)error;

// TODO: Consider an @optional canceled event.

@end

/**
 * The SFIdentityCoordinator class is used to retrieve identity data from the ID endpoint of the
 * Salesforce service.  This data will be based on the requesting user, and the OAuth app
 * credentials he/she is using to request this information.
 */
@interface SFIdentityCoordinator : NSObject <NSURLConnectionDataDelegate>

/**
 * The designated initializer of SFIdentityCoordinator.  Creates an instance with the specified
 * OAuth credentials.
 * @param credentials The OAuth credentials used to query the identity service.  At a minimum,
 *        the OAuth credentials must specify a value for accessToken and instanceUrl.
 */
- (id)initWithCredentials:(SFOAuthCredentials *)credentials;

/**
 * Begins the identity request.  This request is asynchronous.  Implement the
 * SFIdentityCoordinatorDelegate protocol to receive events related to the identity response from
 * the service.
 */
- (void)initiateIdentityDataRetrieval;

/**
 * Cancels a request in progress.
 */
- (void)cancelRetrieval;

/**
 * The OAuth credentials associated with this instance.
 */
@property (nonatomic, strong) SFOAuthCredentials *credentials;

/**
 * The SFIdentityData that will be populated with the response data from the service.
 */
@property (nonatomic, strong) SFIdentityData *idData;

/**
 * The SFIdentityCoordinatorDelegate property to set for receiving information about the request.
 * This property must be set prior to initiating an identity request.
 */
@property (nonatomic, weak) id<SFIdentityCoordinatorDelegate> delegate;

/**
 * The amount of time, in seconds, to attempt the request, before it times out.  If not set, the
 * default value is represented by the kSFIdentityRequestDefaultTimeoutSeconds property.
 */
@property (nonatomic, assign) NSTimeInterval timeout;

@end
