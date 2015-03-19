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
#import <SalesforceOAuth/SFOAuthCredentials.h>
#import "SFIdentityData.h"
#import "SFJsonUtils.h"

// Public constants

const NSTimeInterval kSFIdentityRequestDefaultTimeoutSeconds = 120.0;
NSString * const     kSFIdentityErrorDomain                  = @"com.salesforce.Identity.ErrorDomain";

// Private constants

static NSUInteger kSFIdentityReponseBufferLengthBytes        = 512;
static NSString * const kHttpHeaderAuthorization             = @"Authorization";
static NSString * const kHttpAuthHeaderFormatString          = @"Bearer %@";

static NSString * const kSFIdentityError                      = @"error";
static NSString * const kSFIdentityErrorDescription           = @"error_description";
static NSString * const kSFIdentityErrorTypeNoData            = @"no_data_returned";
static NSString * const kSFIdentityErrorTypeDataMalformed     = @"malformed_response";
static NSString * const kSFIdentityErrorTypeBadHttpResponse   = @"bad_http_response";
static NSString * const kSFIdentityErrorTypeMissingParameters = @"missing_parameters";
static NSString * const kMissingParametersFormatString        = @"The following required parameters for the identity service were missing: %@";
static NSString * const kSFIdentityDataPropertyKey            = @"com.salesforce.keys.identity.data";

@implementation SFIdentityCoordinator

@synthesize credentials = _credentials;
@synthesize idData = _idData;
@synthesize responseData = _responseData;
@synthesize delegate = _delegate;
@synthesize timeout = _timeout;
@synthesize retrievingData = _retrievingData;
@synthesize connection = _connection;
@synthesize httpError = _httpError;

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
        dispatch_async(dispatch_get_main_queue(), ^{
            [self notifyDelegateOfFailure:missingParamsError];
        });
        return;
    }
    if (self.retrievingData) {
        [self log:SFLogLevelDebug msg:@"Identity data retrieval already in progress.  Call cancelRetrieval to stop the transaction in progress."];
    }
    self.retrievingData = YES;
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:self.credentials.identityUrl
                                                                cachePolicy:NSURLRequestReloadIgnoringCacheData 
                                                            timeoutInterval:self.timeout];
	[request setHTTPMethod:@"GET"];
    [request setValue:[NSString stringWithFormat:kHttpAuthHeaderFormatString, self.credentials.accessToken] forHTTPHeaderField:kHttpHeaderAuthorization];
	[request setTimeoutInterval:self.timeout];
    [request setHTTPShouldHandleCookies:NO];
    [self log:SFLogLevelDebug format:@"SFIdentityCoordinator:Starting identity request at %@", self.credentials.identityUrl.absoluteString];
    NSURLConnection *urlConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    self.connection = urlConnection;
}

- (void)cancelRetrieval
{
    [self.connection cancel];
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

- (void)notifyDelegateOfSuccess
{
    if ([self.delegate respondsToSelector:@selector(identityCoordinatorRetrievedData:)]) {
        [self.delegate identityCoordinatorRetrievedData:self];
    }
    [self cleanupData];
}

- (void)notifyDelegateOfFailure:(NSError *)error
{
    if ([self.delegate respondsToSelector:@selector(identityCoordinator:didFailWithError:)]) {
        [self.delegate identityCoordinator:self didFailWithError:error];
    }
    [self cleanupData];
}

- (void)dealloc
{
    SFRelease(_credentials);
    SFRelease(_idData);
    SFRelease(_responseData);
    SFRelease(_connection);
    SFRelease(_httpError);
}

- (void)cleanupData
{
    SFRelease(_connection);
    SFRelease(_responseData);
    SFRelease(_httpError);
    self.retrievingData = NO;
}

- (void)processResponse
{
    // If there was an invalid HTTP response, the request failed.
    if (nil != self.httpError) {
        [self notifyDelegateOfFailure:self.httpError];
        return;
    }
    
    NSError *error;
    if (self.responseData == nil) {
        error = [self errorWithType:kSFIdentityErrorTypeNoData description:@"No identity data returned in response."];
        [self notifyDelegateOfFailure:error];
        return;
    }
    
    
    NSDictionary *idJsonData = (NSDictionary *)[SFJsonUtils objectFromJSONData:self.responseData];
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
                             kSFIdentityErrorTypeMissingParameters: @(kSFIdentityErrorMissingParameters) };
    }
    
    return _typeToCodeDict;
}

#pragma mark - NSURLConnectionDataDelegate methods

// TODO: Add retry for auth failure.

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [self log:SFLogLevelDebug format:@"SFIdentityCoordinator:connection:didFailWithError: %@", error];
    [self notifyDelegateOfFailure:error];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    // The connection can succeed, but the actual HTTP response is a failure.  Check for that.
    NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
    if (statusCode != 200) {
        self.httpError = [self errorWithType:kSFIdentityErrorTypeBadHttpResponse
                                 description:[NSString stringWithFormat:@"Unexpected HTTP response code from the identity service: %ld", (long)statusCode]];
    }
    
	// reset the response data for a new refresh response
    self.responseData = [NSMutableData dataWithCapacity:kSFIdentityReponseBufferLengthBytes];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	[self.responseData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	[self processResponse];
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse {
    return nil;
}

@end
