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

#import "SFIdentityCoordinator.h"
#import "SFIdentityCoordinator+Internal.h"
#import "SFOAuthCredentials.h"
#import "SFOAuthSessionRefresher.h"
#import "SFIdentityData.h"
#import "SFJsonUtils.h"
#import "SFUserAccountManager.h"

// Public constants

const NSTimeInterval kSFIdentityRequestDefaultTimeoutSeconds = 120.0;
NSString * const     kSFIdentityErrorDomain                  = @"com.salesforce.Identity.ErrorDomain";

// Private constants

static NSString * const kHttpHeaderAuthorization             = @"Authorization";
static NSString * const kHttpAuthHeaderFormatString          = @"Bearer %@";

static NSString * const kSFIdentityError                      = @"error";
static NSString * const kSFIdentityErrorDescription           = @"error_description";
static NSString * const kSFIdentityErrorTypeNoData            = @"no_data_returned";
static NSString * const kSFIdentityErrorTypeDataMalformed     = @"malformed_response";
static NSString * const kSFIdentityErrorTypeBadHttpResponse   = @"bad_http_response";
static NSString * const kSFIdentityErrorTypeMissingParameters = @"missing_parameters";
static NSString * const kSFIdentityErrorTypeAlreadyRetrieving = @"retrieval_in_progress";
static NSString * const kMissingParametersFormatString        = @"The following required parameters for the identity service were missing: %@";
static NSString * const kSFIdentityDataPropertyKey            = @"com.salesforce.keys.identity.data";

@implementation SFIdentityCoordinator

@synthesize credentials = _credentials;
@synthesize idData = _idData;
@synthesize delegate = _delegate;
@synthesize timeout = _timeout;
@synthesize retrievingData = _retrievingData;
@synthesize session = _session;
@synthesize oauthSessionRefresher = _oauthSessionRefresher;

#pragma mark - init / dealloc

- (id)initWithCredentials:(SFOAuthCredentials *)credentials
{
    self = [super init];
    if (self) {
        self.credentials = credentials;
        self.timeout = kSFIdentityRequestDefaultTimeoutSeconds;
        self.retrievingData = NO;
    }
    
    return self;
}


#pragma mark - Identity data retrieval and processing

- (void)initiateIdentityDataRetrieval
{
    NSString *missingParameters = [self validateParameters];
    if ([missingParameters length] > 0) {
        NSError *missingParamsError = [self errorWithType:kSFIdentityErrorTypeMissingParameters description:missingParameters];
        [self notifyDelegateOfFailure:missingParamsError];
        return;
    }
    if (self.retrievingData) {
        NSString *alreadyRetrievingErrorMessage = @"Identity data retrieval already in progress.  Call cancelRetrieval to stop the transaction in progress.";
        [self log:SFLogLevelDebug msg:alreadyRetrievingErrorMessage];
        NSError *alreadyRetrievingError = [self errorWithType:kSFIdentityErrorTypeAlreadyRetrieving description:alreadyRetrievingErrorMessage];
        [self notifyDelegateOfFailure:alreadyRetrievingError];
        return;
    }
    self.retrievingData = YES;
    
    [self sendRequest];
}

- (void)cancelRetrieval
{
    [self.session invalidateAndCancel];
    [self cleanupData];
}

#pragma mark - Private methods

- (NSString *)validateParameters
{
    NSMutableString *invalidParameters = [NSMutableString string];
    if ([self.credentials.accessToken length] == 0) {
        [invalidParameters appendString:@"access token"];
    }
    if ([[self.credentials.identityUrl absoluteString] length] == 0) {
        if ([invalidParameters length] > 0) [invalidParameters appendString:@", "];
        [invalidParameters appendString:@"identity URL"];
    }
    
    NSString *invalidParametersError = nil;
    if ([invalidParameters length] > 0) {
        invalidParametersError = [NSString stringWithFormat:kMissingParametersFormatString, invalidParameters];
    }
    
    return invalidParametersError;
}

- (void)sendRequest
{
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:self.credentials.identityUrl
                                                                cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                            timeoutInterval:self.timeout];
    [request setHTTPMethod:@"GET"];
    [request setValue:[NSString stringWithFormat:kHttpAuthHeaderFormatString, self.credentials.accessToken] forHTTPHeaderField:kHttpHeaderAuthorization];
    [request setTimeoutInterval:self.timeout];
    [request setHTTPShouldHandleCookies:NO];
    [self log:SFLogLevelDebug format:@"SFIdentityCoordinator:Starting identity request at %@", self.credentials.identityUrl.absoluteString];
    
    __weak __typeof(self) weakSelf = self;
    
    self.session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];
    [[self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
         __strong __typeof(self) strongSelf = weakSelf;
        if (error) {
            [strongSelf log:SFLogLevelDebug format:@"SFIdentityCoordinator session failed with error: %@", error];
            [strongSelf notifyDelegateOfFailure:error];
            return;
            
        }
        
        // The connection can succeed, but the actual HTTP response is a failure.  Check for that.
        NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
        if (statusCode == 401 || statusCode == 403) {
            // The session timed out.  Identity service tends to send 403s for session timeouts.  Try to refresh.
            [strongSelf log:SFLogLevelInfo format:@"%@: Identity request failed due to expired credentials.  Attempting to refresh credentials.", NSStringFromSelector(_cmd)];
            strongSelf.oauthSessionRefresher = [[SFOAuthSessionRefresher alloc] initWithCredentials:strongSelf.credentials];
            [strongSelf.oauthSessionRefresher refreshSessionWithCompletion:^(SFOAuthCredentials *updatedCredentials) {
                [strongSelf log:SFLogLevelInfo format:@"%@: Credentials refresh successful.  Replaying original identity request.", NSStringFromSelector(_cmd)];
                strongSelf.credentials = updatedCredentials;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [strongSelf sendRequest];
                });
            } error:^(NSError *refreshError) {
                [strongSelf log:SFLogLevelError format:@"SFIdentityCoordinator failed to refresh expired session. Error: %@", refreshError];
                [strongSelf notifyDelegateOfFailure:refreshError];
            }];
        } else if (statusCode != 200) {
            // Some other HTTP error.
            NSError *httpError = [self errorWithType:kSFIdentityErrorTypeBadHttpResponse
                                         description:[NSString stringWithFormat:@"Unexpected HTTP response code from the identity service: %ld", (long)statusCode]];
            [strongSelf notifyDelegateOfFailure:httpError];
        } else {
            // Successful response.  Process the return data.
            [strongSelf processResponse:data];
        }
    }] resume];
}

- (void)notifyDelegateOfSuccess
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(identityCoordinatorRetrievedData:)]) {
            [self.delegate identityCoordinatorRetrievedData:self];
        }
        [self cleanupData];
    });
}

- (void)notifyDelegateOfFailure:(NSError *)error
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(identityCoordinator:didFailWithError:)]) {
            [self.delegate identityCoordinator:self didFailWithError:error];
        }
        [self cleanupData];
    });
}

- (void)dealloc
{
    self.credentials = nil;
    self.idData = nil;
    self.session = nil;
    self.oauthSessionRefresher = nil;
}

- (void)cleanupData
{
    self.session = nil;
    self.oauthSessionRefresher = nil;
    self.retrievingData = NO;
}

- (void)processResponse:(NSData *)data
{
    NSError *error = nil;
    if (data == nil) {
        error = [self errorWithType:kSFIdentityErrorTypeNoData description:@"No identity data returned in response."];
        [self notifyDelegateOfFailure:error];
        return;
    }
    
    
    NSDictionary *idJsonData = (NSDictionary *)[SFJsonUtils objectFromJSONData:data];
    if (idJsonData == nil) {
        error = [self errorWithType:kSFIdentityErrorTypeDataMalformed description:@"Unable to parse identity response data."];
        [self notifyDelegateOfFailure:error];
        return;
    }
    
    SFIdentityData *idData = [[SFIdentityData alloc] initWithJsonDict:idJsonData];
    self.idData = idData;
    
    [self notifyDelegateOfSuccess];
}

- (NSError *)errorWithType:(NSString *)type description:(NSString *)description {
    NSAssert(type, @"error type can't be nil");
    
    NSInteger intCode = kSFIdentityErrorUnknown;
    NSNumber *numCode = (self.typeToCodeDict)[type];
    if (numCode != nil) {
        intCode = [numCode integerValue];
    }
    
    NSDictionary *dict = @{kSFIdentityError: type,
                          kSFIdentityErrorDescription: description,
                          NSLocalizedDescriptionKey: description};
    NSError *error = [NSError errorWithDomain:kSFIdentityErrorDomain code:intCode userInfo:dict];
    return error;
}

#pragma mark - Properties

- (NSDictionary *)typeToCodeDict
{
    static NSDictionary *_typeToCodeDict = nil;
    if (_typeToCodeDict == nil) {
        _typeToCodeDict = @{ kSFIdentityErrorTypeNoData: @(kSFIdentityErrorNoData),
                             kSFIdentityErrorTypeDataMalformed: @(kSFIdentityErrorDataMalformed),
                             kSFIdentityErrorTypeBadHttpResponse: @(kSFIdentityErrorBadHttpResponse),
                             kSFIdentityErrorTypeMissingParameters: @(kSFIdentityErrorMissingParameters),
                             kSFIdentityErrorTypeAlreadyRetrieving: @(kSFIdentityErrorAlreadyRetrieving)
                             };
    }
    
    return _typeToCodeDict;
}

@end
