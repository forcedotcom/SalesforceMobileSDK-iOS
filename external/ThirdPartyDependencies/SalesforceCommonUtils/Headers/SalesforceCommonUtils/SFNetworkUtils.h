//
//  SFNetworkUtils.h
//  NetworkSDK
//
//  Created by Qingqing Liu on 9/25/12.
//  Copyright (c) 2012 salesforce.com. All rights reserved.
//

#import <Foundation/Foundation.h>


/** Various error type that a SFNetworkOperation could fail upon
 
- SFNetworkOperationErrorTypeNetworkError: Network related error, including error code of kCFURLErrorNotConnectedToInternet, kCFURLErrorCannotFindHost, kCFURLErrorCannotConnectToHost, kCFURLErrorNetworkConnectionLost, kCFURLErrorDNSLookupFailed, kCFURLErrorResourceUnavailable and kCFURLErrorTimedOut
 
- SFNetworkOperationErrorTypeInvalidRequest: Invalid request error code 400
- SFNetworkOperationErrorTypeSessionTimeOut: Session time out error, error code 401
- SFNetworkOperationErrorTypeOAuthError: OAuth related error. including error code of kSFOAuthErrorAccessDenied, kSFOAuthErrorInvalidClientId, kSFOAuthErrorInvalidGrant, kSFOAuthErrorInactiveUser and kSFOAuthErrorInactiveOrg
- SFNetworkOperationErrorTypeAccessDenied: Access denied error, error code 403 
- SFNetworkOperationErrorTypeAPILimitReached: Server side API limited reached error, error code 503
- SFNetworkOperationErrorTypeURLNoLongerExists: URL no longer exists error, error code 404. Typical error when trying to get to a resource that is already deleted on the server
- SFNetworkOperationErrorTypeInternalServerError: Remote server internal error, error code 500. Typical error when remote server is temporarialy down
- SFNetworkOperationErrorTypeUnknown: For other errors that has error code not matching one of the above
 */
typedef NS_ENUM(NSUInteger, SFNetworkOperationErrorType) {
    SFNetworkOperationErrorTypeNetworkError = 0,
    SFNetworkOperationErrorTypeSessionTimeOut,
    SFNetworkOperationErrorTypeOAuthError,
    SFNetworkOperationErrorTypeAccessDenied,
    SFNetworkOperationErrorTypeInvalidRequest,
    SFNetworkOperationErrorTypeAPILimitReached,
    SFNetworkOperationErrorTypeURLNoLongerExists,
    SFNetworkOperationErrorTypeInternalServerError,
    SFNetworkOperationErrorTypeUnknown
};

extern NSString * const kErrorCodeKeyInResponse;
extern NSString * const kErrorMessageKeyInResponse;

extern NSString * const kSFNetworkEngineThrottleConnectionsEnabledNotification;
extern NSString * const kSFNetworkEngineThrottleConnectionsDisabledNotification;
/** Helper class for SFNetworkSDK 
 
 This class provides
 - Utility methods to detect error type
 - Identify proper display message for various errors
 */
@interface SFNetworkUtils : NSObject

/** Get error type for the specified error
 
 @param error NSError object to get error type for
 */
+ (SFNetworkOperationErrorType)typeOfError:(NSError *)error;

/** Return YES if error is related to network connectivity error
 
 @param error NSError object used to check whether the error is related to network connectivity error
 */
+ (BOOL)isNetworkError:(NSError *)error;

@end
