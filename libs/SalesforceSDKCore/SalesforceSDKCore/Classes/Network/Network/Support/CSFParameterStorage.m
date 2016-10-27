 /*
 Copyright (c) 2015, salesforce.com, inc. All rights reserved.
 
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

#import "CSFParameterStorage_Internal.h"
#import "CSFInternalDefines.h"

#import "CSFMultipartInputStream.h"
#import "NSValueTransformer+SalesforceNetwork.h"
#import "CSFActionInput.h"

@interface CSFParameterStorage ()

@property (nonatomic, assign, readwrite) CSFParameterStyle parameterStyle;
@property (nonatomic, strong) NSMutableDictionary *parameters;
@property (nonatomic, strong) NSMutableDictionary *filenames;
@property (nonatomic, strong) NSMutableDictionary *mimetypes;

@end

@implementation CSFParameterStorage

+ (NSSet*)keyPathsForValuesAffectingParameterStyle {
    return [NSSet setWithObjects:@"HTTPMethod", @"filenames", @"parameters", @"mimetypes", nil];
}

- (BOOL)isEqual:(CSFParameterStorage*)object {
    if (object == self)
        return YES;

    if (![object isMemberOfClass:self.class])
        return NO;
    
    if (!((self.HTTPMethod == nil && object.HTTPMethod == nil) || [object.HTTPMethod isEqualToString:self.HTTPMethod]))
        return NO;

    if (!((self.parameters == nil && object.parameters == nil) || [self.parameters isEqualToDictionary:object.parameters]))
        return NO;
    
    if (!((self.filenames == nil && object.filenames == nil) || [self.filenames isEqualToDictionary:object.filenames]))
        return NO;
    
    if (!((self.mimetypes == nil && object.mimetypes == nil) || [self.mimetypes isEqualToDictionary:object.mimetypes]))
        return NO;

    if (!((self.bodyStreamBlock == nil && object.bodyStreamBlock == nil) || [self.bodyStreamBlock isEqual:object.bodyStreamBlock]))
        return NO;

    return YES;
}

- (NSMutableDictionary*)parameters {
    if (!_parameters) {
        _parameters = [NSMutableDictionary new];
    }
    return _parameters;
}

- (NSMutableDictionary*)filenames {
    if (!_filenames) {
        _filenames = [NSMutableDictionary new];
    }
    return _filenames;
}

- (NSMutableDictionary*)mimetypes {
    if (!_mimetypes) {
        _mimetypes = [NSMutableDictionary new];
    }
    return _mimetypes;
}

- (NSArray*)allKeys {
    return _parameters.allKeys;
}

- (NSSet*)queryStringKeys {
    NSSet *result = nil;
    if (_queryStringKeys) {
        result = _queryStringKeys;
    } else if (self.parameterStyle == CSFParameterStyleQueryString) {
        result = [NSSet setWithArray:_parameters.allKeys];
    }
    return result;
}

- (void)setHTTPMethod:(NSString *)HTTPMethod {
    if (_HTTPMethod != HTTPMethod) {
        _HTTPMethod = HTTPMethod;
        
        [self updateActionStyle];
    }
}

- (CSFParameterStyle)requiredParameterStyleForObject:(id)object forKey:(NSString*)key {
    CSFParameterStyle result = CSFParameterStyleNone;
    if (_filenames && _filenames.count > 0) {
        result = CSFRequiredParameterStyleForHTTPMethod(self.HTTPMethod);
    }

    if ([object isKindOfClass:[NSFileWrapper class]]) {
        result = CSFParameterStyleMultipart;
    } else if (object) {
        result = CSFParameterStyleQueryString;
    }

    // If a key is supplied, check to see if filenames / mimetypes have been added,
    // to determine if we need to immediately switch to a multipart request.
    if (key) {
        if ((_filenames && _filenames[key]) || (_mimetypes && _mimetypes[key])) {
            result = CSFParameterStyleMultipart;
        }
    }

    return result;
}

- (void)updateActionStyle {
    __block CSFParameterStyle style = CSFParameterStyleNone;

    // Directly access the ivar so we don't unnecessarily create a mutable dictionary for our parameters list
    [_parameters enumerateKeysAndObjectsUsingBlock:^(NSString *key, id obj, BOOL *stop) {
        CSFParameterStyle requiredStyle = [self requiredParameterStyleForObject:obj forKey:key];
        if (requiredStyle > style) {
            style = requiredStyle;
        }

        // Stop processing once we bump up against a multipart property, meaning
        // we don't need to continue looking for output styles.
        if (style == CSFParameterStyleMultipart) {
            *stop = YES;
        }
    }];

    self.parameterStyle = style;
}

- (BOOL)bindParametersToRequest:(NSMutableURLRequest*)request error:(NSError *__autoreleasing *)error {
    BOOL result = YES;
    NSError *resultError = nil;

    if (self.bodyStreamBlock) {
        request.HTTPBodyStream = self.bodyStreamBlock();
    } else {
        // Add explicit query string keys here, only if we are posting multipart or URLEncoded
        // bodies.  If we are doing a querystring request already, then simply wait for the
        // switch block down below.
        if (self.parameterStyle > CSFParameterStyleQueryString && _queryStringKeys.count > 0) {
            result = [self bindQueryStringParametersToRequest:request error:&resultError];
        }

        if (result) {
            switch (self.parameterStyle) {
                case CSFParameterStyleMultipart:
                    result = [self bindMultipartParametersToRequest:request error:&resultError];
                    break;

                case CSFParameterStyleURLEncoded:
                    result = [self bindURLEncodedParametersToRequest:request error:&resultError];
                    break;

                case CSFParameterStyleQueryString:
                case CSFParameterStyleNone:
                default:
                    result = [self bindQueryStringParametersToRequest:request error:&resultError];
                    break;
            }
        }
    }
    
    if (resultError) {
        NetworkDebug(@"Error binding parameters to request %@: %@", request.HTTPMethod, error);
        result = NO;
    }
    
    if (error) {
        *error = resultError;
    }
    
    return result;
}

- (BOOL)bindMultipartParametersToRequest:(NSMutableURLRequest*)request error:(NSError *__autoreleasing *)error {
    __weak NSDictionary *weakFilenames = _filenames;
    __weak NSDictionary *weakMimetypes = _mimetypes;

    __block BOOL success = YES;
    CSFMultipartInputStream *stream = [[CSFMultipartInputStream alloc] init];
    [self.parameters enumerateKeysAndObjectsUsingBlock:^(NSString *key, id obj, BOOL *stop) {
        NSString *filename = weakFilenames[key];
        NSString *mimeType = weakMimetypes[key];

        id resultObject = obj;
        if ([obj conformsToProtocol:@protocol(CSFActionInput)]) {
            NSObject<CSFActionInput> *objInput = (NSObject<CSFActionInput>*)obj;
            resultObject = [objInput formatJSONData:error];
            if (!resultObject) {
                success = NO;
            }
        }

        [stream addObject:resultObject forKey:key withMimeType:mimeType filename:filename];
    }];
    
    request.HTTPBodyStream = stream;
    [request setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", stream.boundary] forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)stream.length] forHTTPHeaderField:@"Content-Length"];

    return success;
}

- (BOOL)bindURLEncodedParametersToRequest:(NSMutableURLRequest*)request error:(NSError *__autoreleasing *)error {
    __block BOOL success = YES;

    NSMutableDictionary *formParameters = [NSMutableDictionary dictionaryWithCapacity:self.parameters.count];
    [self.parameters enumerateKeysAndObjectsUsingBlock:^(NSString *key, id obj, BOOL *stop) {
        NSValueTransformer *transformer = [NSValueTransformer networkDataTransformerForObject:obj];
        if (transformer) {
            // TODO: What happens when the value is an NSData or something else?
            id result = [transformer transformedValue:obj];
            if (result) {
                formParameters[key] = result;
            } else {
                success = NO;
            }
        } else if ([obj conformsToProtocol:@protocol(CSFActionInput)]) {
            NSObject<CSFActionInput> *objInput = (NSObject<CSFActionInput>*)obj;
            NSData *data = [objInput formatJSONData:error];
            if (data) {
                formParameters[key] = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            } else {
                success = NO;
            }
        } else {
            formParameters[key] = obj;
        }
    }];
    
    NSString *bodyString = CSFURLFormEncode(formParameters, error);
    if (error && *error != nil) {
        success = NO;
    }
    request.HTTPBody = [bodyString dataUsingEncoding:NSUTF8StringEncoding];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)request.HTTPBody.length] forHTTPHeaderField:@"Content-Length"];

    return success;
}

- (BOOL)bindQueryStringParametersToRequest:(NSMutableURLRequest*)request error:(NSError *__autoreleasing *)error {
    __block NSError *resultError = nil;
    __block BOOL success = YES;

    NSMutableDictionary *formParameters = [NSMutableDictionary dictionaryWithCapacity:self.parameters.count];
    NSSet *keys = self.queryStringKeys;
    [self.parameters enumerateKeysAndObjectsUsingBlock:^(NSString *key, id obj, BOOL *stop) {
        if ([keys containsObject:key]) {
            NSValueTransformer *transformer = [NSValueTransformer networkDataTransformerForObject:obj];
            if ([obj isKindOfClass:[NSString class]]) {
                formParameters[key] = obj;
            } else if (transformer) {
                // TODO: What happens when the value is an NSData or something else?
                id result = [transformer transformedValue:obj];
                if (result) {
                    formParameters[key] = result;
                } else {
                    success = NO;
                }
            } else if ([obj conformsToProtocol:@protocol(CSFActionInput)]) {
                NSObject<CSFActionInput> *objInput = (NSObject<CSFActionInput>*)obj;
                NSData *data = [objInput formatJSONData:error];
                if (data) {
                    formParameters[key] = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                } else {
                    success = NO;
                }
            } else if ([obj respondsToSelector:@selector(stringValue)]) {
                formParameters[key] = [obj stringValue];
            } else {
                resultError = [NSError errorWithDomain:CSFNetworkErrorDomain
                                                  code:CSFNetworkInvalidActionParameterError
                                              userInfo:@{ NSLocalizedDescriptionKey: @"Value supplied to CSFURLFormEncode is not a valid object",
                                                          @"key": key,
                                                          @"value": obj }];
                *stop = YES;
                success = NO;
            }
        }
    }];
    
    if (error) {
        *error = resultError;
    }

    if (success && !resultError && formParameters.count > 0) {
        NSURLComponents *requestUrl = [NSURLComponents componentsWithURL:request.URL resolvingAgainstBaseURL:YES];
        NSString *fullQuery;
        if (requestUrl.percentEncodedQuery.length > 0) {
            fullQuery = [NSString stringWithFormat:@"%@&%@", requestUrl.percentEncodedQuery, CSFURLFormEncode(formParameters, nil)];
        } else {
            fullQuery = CSFURLFormEncode(formParameters, nil);
        }
        requestUrl.percentEncodedQuery = fullQuery;
        request.URL = requestUrl.URL;
    }
    
    return success;
}

- (void)setObject:(id)object forKey:(NSString*)key {
    NSAssert1(object, @"Must supply a valid object to %@", NSStringFromSelector(_cmd));
    NSAssert1([key isKindOfClass:[NSString class]], @"Must invoke %@ with an NSString key", NSStringFromSelector(_cmd));
    
    self.parameters[key] = object;
    [self updateActionStyle];
}

- (void)setObject:(id)object forKey:(NSString*)key filename:(NSString*)filename mimeType:(NSString*)mimeType {
    NSAssert1(object, @"Must supply a valid object to %@", NSStringFromSelector(_cmd));
    NSAssert1([key isKindOfClass:[NSString class]], @"Must invoke %@ with an NSString key", NSStringFromSelector(_cmd));
    NSAssert1(filename == nil || [filename isKindOfClass:[NSString class]], @"Must invoke %@ with an NSString filename, or nil", NSStringFromSelector(_cmd));
    NSAssert1(mimeType == nil || [mimeType isKindOfClass:[NSString class]], @"Must invoke %@ with an NSString mimeType, or nil", NSStringFromSelector(_cmd));
    self.parameters[key] = object;
    if (filename)
        self.filenames[key] = filename;

    if (mimeType)
        self.mimetypes[key] = mimeType;

    [self updateActionStyle];
}

- (id)objectForKey:(NSString*)key {
    NSAssert1([key isKindOfClass:[NSString class]], @"Must invoke %@ with an NSString key", NSStringFromSelector(_cmd));

    return self.parameters[key];
}

- (NSString*)mimeTypeForKey:(NSString*)key {
    NSString *result = nil;

    // Note: Check to see if the ivar exists yet, so we don't unnecessarily create a mutable dictionary
    // for this property.
    if (_mimetypes) {
        result = self.mimetypes[key];
    }

    return result;
}

- (void)setMimeType:(NSString*)mimeType forKey:(NSString*)key {
    NSAssert1([mimeType isKindOfClass:[NSString class]], @"Must invoke %@ with an NSString mimeType", NSStringFromSelector(_cmd));
    NSAssert1([key isKindOfClass:[NSString class]], @"Must invoke %@ with an NSString key", NSStringFromSelector(_cmd));

    self.mimetypes[key] = mimeType;
    [self updateActionStyle];
}

- (NSString*)fileNameForKey:(NSString*)key {
    NSString *result = nil;

    // Note: Check to see if the ivar exists yet, so we don't unnecessarily create a mutable dictionary
    // for this property.
    if (_filenames) {
        result = self.filenames[key];
    }

    return result;
}

- (void)setFileName:(NSString*)fileName forKey:(NSString*)key {
    NSAssert1([fileName isKindOfClass:[NSString class]], @"Must invoke %@ with an NSString fileName", NSStringFromSelector(_cmd));
    NSAssert1([key isKindOfClass:[NSString class]], @"Must invoke %@ with an NSString key", NSStringFromSelector(_cmd));
    
    self.filenames[key] = fileName;
    [self updateActionStyle];
}

@end

@implementation CSFParameterStorage (KeyedSubscript)

- (id)objectForKeyedSubscript:(NSString*)key {
    return [self objectForKey:key];
}

- (void)setObject:(id)obj forKeyedSubscript:(NSString*)key {
    [self setObject:obj forKey:key];
}

@end
